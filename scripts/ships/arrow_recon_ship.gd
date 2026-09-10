class_name ArrowReconShip
extends HeroShip

## Evidence-bounded Arrow-class Recon Ship candidate.
##
## Creator-authored material (A3, page archived 2009-11-12) supports only the
## Arrow-class name, reconnaissance role, and a written description of two
## escape pods. No registered source shows a craft identified as Arrow: B3
## records the label string alone, with no ledger frame anchor and no tied
## craft, so the Arrow name-to-model mapping is `unknown`. This slender
## procedural airframe, all proportions, pod appearance/placement/release
## treatment, cockpit, entry, sensors, engines, weapons, materials, and handling
## are a modern provisional interpretation. The common HeroShip controller
## supplies already-tested flight, cameras, boarding, landing, damage,
## destruction, and reuse behavior.

const StaticShadowBatch = preload("res://scripts/world/static_shadow_batch.gd")

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_role_pod_count_only"
const NAME_TO_MODEL_STATUS: StringName = &"unknown"
const SUPPORTED_ESCAPE_POD_COUNT := 2
const PROVISIONAL_NOTE := (
	"Creator-supported facts (A3 page text): Arrow-class Recon Ship; "
	+ "reconnaissance role; two escape pods. No registered source ties any "
	+ "visible craft to the Arrow name, so the name-to-model mapping is "
	+ "unknown. The displayed geometry, materials, entry, pod appearance and "
	+ "locations, release concept, systems, handling, and weapons are a modern "
	+ "provisional interpretation with no authenticated historical silhouette "
	+ "mapping."
)

# Fleet readability palette. The Arrow's name-to-model mapping is unknown and
# its palette is listed among its unknowns in docs/research/ship_evidence_matrix.json,
# so these are freely chosen modern hull tints picked to separate the recon craft
# from the rest of the fleet under normal and dichromatic vision. See
# tests/fleet_role_differentiation_test.gd for the frozen separation floors.
const HULL_SLATE := Color("7891ab")
const HULL_SLATE_SHADE := Color("66798d")
const TITANIUM := Color("59686c")
const GRAPHITE := Color("15282e")
const SENSOR_CYAN := Color("65e4e8")
const POD_ORANGE := Color("e59a43")
const ENGINE_CYAN := Color("7cf5ef")
const ARROW_NAV_RED := Color("ff6460")
const ARROW_NAV_GREEN := Color("7cf0a3")

# Phase 9 allocation freeze. These two mirrored ribs were the first repeated
# Arrow family with identical mesh/material state and no gameplay, evidence,
# collision, lifecycle, or stable-node identity. The five later dorsal seams keep
# every ordinary renderer, including the checked-in `FuselagePanelBand` capture
# path, while sharing only their identical BoxMesh resource. The other audited
# families are narrower still: only the identical, childless CurveJoint sphere
# resources under the paired lateral arrays, sensor-wing leading edges and
# three-point dorsal data conduit are shared within their exact family. All
# retained nodes, paths, transforms, materials, shadows, copies and submissions
# remain ordinary independent renderers. The later boarding-step batch preserves
# the family's sole stable path and three exact visual copies while removing two
# fallback-name renderers and two submissions. The sensor-sweep receiver batch
# likewise preserves its sole stable path and two exact visual copies while
# removing one fallback-name renderer and one submission.
# Phase 10 additionally retains both ordinary engine-collar renderers and their
# exact authored transforms while sharing the pair's immutable TorusMesh. The
# visually separate main-gear-foot family follows the same narrow rule: both
# ordinary feet and their parked silhouette remain, while their identical,
# authority-free titanium TorusMesh becomes one immutable resource.
# The two escape-pod separation collars now follow that same allocation-only
# rule: both independently named pod renderers, parent modules, transforms and
# visible submissions remain, while the identical graphite TorusMesh is shared.
const WING_ROOT_RIB_SIZE := Vector3(1.25, 0.34, 4.8)
const WING_ROOT_RIB_VISIBLE_COPIES := 2
const LATERAL_ARRAY_CURVE_JOINT_RADIUS := 0.07
const LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS := 28
const LATERAL_ARRAY_CURVE_JOINT_RINGS := 14
const LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES := 6
const LATERAL_ARRAY_CURVE_JOINT_PATHS := [
	"PortLateralArray/CurveJoint",
	"PortLateralArray/@MeshInstance3D@14",
	"PortLateralArray/@MeshInstance3D@15",
	"StarboardLateralArray/CurveJoint",
	"StarboardLateralArray/@MeshInstance3D@16",
	"StarboardLateralArray/@MeshInstance3D@17",
]
const SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS := 0.035
const SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS := 28
const SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS := 14
const SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES := 6
const SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS := [
	"SensorLeadingEdge/CurveJoint",
	"SensorLeadingEdge/@MeshInstance3D@2",
	"SensorLeadingEdge/@MeshInstance3D@3",
	"@Node3D@4/CurveJoint",
	"@Node3D@4/@MeshInstance3D@5",
	"@Node3D@4/@MeshInstance3D@6",
]
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS := 0.075
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS := 28
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS := 14
const DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES := 3
const DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS := [
	"DorsalDataConduit/CurveJoint",
	"DorsalDataConduit/@MeshInstance3D@8",
	"DorsalDataConduit/@MeshInstance3D@9",
]
## Five shallow dorsal seams break the Arrow fuselage into manufactured bays
## without wrapping the silhouette in wheel-like full-circumference tori.
const FUSELAGE_PANEL_BAND_SIZE := Vector3(0.74, 0.024, 0.07)
const FUSELAGE_PANEL_BAND_HEIGHT := 1.67
const FUSELAGE_PANEL_BAND_VISIBLE_COPIES := 5
const FUSELAGE_PANEL_BAND_STABLE_PATH := "FuselagePanelBand"
const ARRAY_RECEIVER_RADIUS := 0.15
const ARRAY_RECEIVER_VISIBLE_COPIES := 2
const ARRAY_RECEIVER_BATCH_NAME := "ArrayReceiver"
# The rotating crossbar is easier to read against the long dorsal silhouette
# when the visual-only survey head also traces a restrained vertical arc.
const SENSOR_SWEEP_YAW_RATE := 0.42
const SENSOR_SWEEP_PITCH_RATE := 0.75
const SENSOR_SWEEP_PITCH_AMPLITUDE := deg_to_rad(6.0)
## A presentation-only dual-axis passive aperture gives the provisional Arrow
## a readable reconnaissance crown at normal chase and berth distances. The
## existing azimuth ring grows into the primary aperture while one orthogonal
## ring makes the sensor role legible from the flank; neither surface owns a
## light, collision shape, sensor query, timer, or gameplay authority.
const RECON_CROWN_PRIMARY_INNER_RADIUS := 0.72
const RECON_CROWN_PRIMARY_OUTER_RADIUS := 0.86
const RECON_CROWN_SECONDARY_INNER_RADIUS := 0.54
const RECON_CROWN_SECONDARY_OUTER_RADIUS := 0.66
const RECON_CROWN_SECONDARY_ROTATION_DEGREES := Vector3(0.0, 0.0, 90.0)
const RECON_CROWN_HUB_RADIUS := 0.14
const RECON_CROWN_MAX_CHASE_PROJECTED_DIAMETER_PX := 30.0
const BOARDING_STEP_SIZE := Vector3(0.58, 0.1, 0.62)
const BOARDING_STEP_VISIBLE_COPIES := 3
# Retain the only stable renderer path from the former three-node family; the
# two duplicate siblings had engine-generated fallback names and no authority.
const BOARDING_STEP_BATCH_NAME := "BoardingStep"
const ENGINE_COLLAR_INNER_RADIUS := 0.55
const ENGINE_COLLAR_OUTER_RADIUS := 0.7
const ENGINE_COLLAR_VISIBLE_COPIES := 2
const ENGINE_COLLAR_AUTHORED_TESSELLATION := Vector2i(64, 18)
const ENGINE_COLLAR_BUDGETED_TESSELLATION := Vector2i(40, 18)
## Static presentation of the existing engine-bay ledger. The starboard collar
## stays centred over its engine nozzle but pulls outboard into an asymmetric
## chase-view silhouette when that component is impaired or failed. No new
## geometry, collision, light, timing, or damage authority is introduced.
const ENGINE_DAMAGE_CUE_COMPONENT_ID: StringName = &"engine_bay"
const ENGINE_DAMAGE_CUE_COLLAR_INDEX := 1
const ENGINE_DAMAGE_COLLAR_COLOR := Color("ff6a36")
const ENGINE_DAMAGE_COLLAR_POSITION := Vector3(1.10, 0.94, 6.48)
const ENGINE_DAMAGE_COLLAR_SCALE := Vector3(1.35, 1.0, 1.0)
## A failed core-systems ledger locks the already-retained recon head into an
## asymmetric mechanical cant. The crossbar and orthogonal aperture then read
## as a local, non-colour-only silhouette break in the normal chase view. This
## changes neither sensor authority nor the sweep's renderer roster.
const CORE_SYSTEMS_DAMAGE_CUE_COMPONENT_ID: StringName = &"core_systems"
const CORE_SYSTEMS_FAILED_SENSOR_SWEEP_ROTATION := Vector3(
	deg_to_rad(-24.0), deg_to_rad(31.0), deg_to_rad(26.0)
)
const MAIN_GEAR_FOOT_INNER_RADIUS := 0.22
const MAIN_GEAR_FOOT_OUTER_RADIUS := 0.34
const MAIN_GEAR_FOOT_SCALE := Vector3(1.4, 0.55, 1.0)
const MAIN_GEAR_FOOT_VISIBLE_COPIES := 2
const POD_SEPARATION_COLLAR_INNER_RADIUS := 0.57
const POD_SEPARATION_COLLAR_OUTER_RADIUS := 0.65
const POD_SEPARATION_COLLAR_SCALE := Vector3(1.0, 0.82, 1.0)
const POD_SEPARATION_COLLAR_VISIBLE_COPIES := 2
const POD_SEPARATION_COLLAR_AUTHORED_TESSELLATION := Vector2i(64, 18)
const POD_SEPARATION_COLLAR_BUDGETED_TESSELLATION := Vector2i(40, 13)
const ESCAPE_POD_STATUS_LIGHT_RADIUS := 0.085
const COCKPIT_CONSOLE_KEY_SHARED_MESH_ROSTER := [
	"PortConsoleKey00",
	"PortConsoleKey02",
	"StarboardConsoleKey00",
	"StarboardConsoleKey02",
]
const COCKPIT_CONSOLE_KEY_SIZE := Vector3(0.12, 0.035, 0.12)
const RECON_PULSE_EMITTER_NAMES := [
	"PortReconPulseEmitter",
	"StarboardReconPulseEmitter",
]
const RECON_PULSE_EMITTER_POSITIONS := [
	Vector3(-1.05, 0.72, -5.7),
	Vector3(1.05, 0.72, -5.7),
]
const RECON_PULSE_EMITTER_COMPONENT_ROSTER := [
	"RecessedGraphiteMount",
	"CompactGraphiteShroud",
	"LightPulseBarrel",
	"CyanMuzzleLens",
]
const RECON_PULSE_MOUNT_SIZE := Vector3(0.38, 0.22, 0.62)
const RECON_PULSE_BARREL_RADIUS := 0.09
const RECON_PULSE_BARREL_LENGTH := 0.4
const RECON_PULSE_SHROUD_INNER_RADIUS := 0.105
const RECON_PULSE_SHROUD_OUTER_RADIUS := 0.155
const RECON_PULSE_MUZZLE_LENS_RADIUS := 0.075
const RECON_PULSE_MUZZLE_LENS_DEPTH := 0.02
const ENTRY_HEAT_TARGET_SCENE: PackedScene = preload(
	"res://scenes/effects/planetary_entry_heat_target.tscn"
)
const ENTRY_HEAT_TARGET_NODE_NAME: StringName = &"PlanetaryEntryHeatTarget"
# Modern ship-local fit for the generic target's immutable ellipsoid. The
# transform covers the full provisional Arrow visual envelope without changing
# the target scene, hull resources, collision, cameras, or presentation logic.
const ENTRY_HEAT_TARGET_POSITION := Vector3(0.0, 1.4, -0.15)
const ENTRY_HEAT_TARGET_ROTATION := Vector3.ZERO
const ENTRY_HEAT_TARGET_SCALE := Vector3(1.45, 1.4, 1.08)
const ENTRY_HEAT_TARGET_AUTHORED_LOCAL_BOUNDS := AABB(
	Vector3(-5.8, -1.4, -7.71), Vector3(11.6, 5.6, 15.12)
)
const ENTRY_HEAT_TARGET_EXPANDED_LOCAL_BOUNDS := AABB(
	Vector3(-6.1625, -1.75, -7.98), Vector3(12.325, 6.3, 15.66)
)
const LEGACY_ARROW_VISUAL_CENSUS := {
	"nodes": 177,
	"mesh_instance_nodes": 159,
	"multi_mesh_instance_nodes": 0,
	"geometry_submissions": 159,
	"visible_geometry_copies": 159,
	"unique_mesh_resource_allocations": 142,
	"auto_fallback_names": 24,
}
const PHASE9_ARROW_VISUAL_CENSUS := {
	"nodes": 176,
	"mesh_instance_nodes": 157,
	"multi_mesh_instance_nodes": 1,
	"geometry_submissions": 158,
	"visible_geometry_copies": 159,
	"unique_mesh_resource_allocations": 119,
	"auto_fallback_names": 23,
}
const EXPECTED_ARROW_VISUAL_CENSUS := {
	"nodes": 284,
	"mesh_instance_nodes": 249,
	"multi_mesh_instance_nodes": 3,
	# Includes fitted seating/controls and one rigid airframe shadow renderer.
	"geometry_submissions": 253,
	"visible_geometry_copies": 255,
	"unique_mesh_resource_allocations": 205,
	"auto_fallback_names": 20,
}
const RECON_PULSE_EMITTER_VISUAL_DELTA := {
	"assembly_nodes": 2,
	"renderer_nodes": 8,
	"geometry_submissions": 8,
	"visible_geometry_copies": 8,
	"unique_mesh_resource_allocations": 4,
}
const ENTRY_HEAT_TARGET_VISUAL_DELTA := {
	"target_subtree_nodes": 4,
	"renderer_nodes": 2,
	"surface_count": 2,
	"geometry_submissions": 2,
	"visible_geometry_copies": 2,
	"unique_mesh_resource_allocations": 2,
	"exclusive_material_allocations": 1,
}

static var _shared_engine_damage_collar_material: StandardMaterial3D

var _arrow_built := false
var _arrow_visual: Node3D
var _entry_heat_target: PlanetaryEntryHeatTarget
var _arrow_materials: Dictionary = {}
var _escape_pods: Array[Node3D] = []
# Explicit construction roster; all sources remain under the banked visual root.
# Nested panels, separable pods and animated/damage-responsive parts stay outside.
var _airframe_shadow_sources: Array[MeshInstance3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _arrow_engine_lights: Array[OmniLight3D] = []
var _sensor_sweep: Node3D
var _recon_primary_aperture: MeshInstance3D
var _recon_secondary_aperture: MeshInstance3D
var _recon_crown_hub: MeshInstance3D
var _core_systems_failure_pose_active := false
var _elapsed_arrow := 0.0
var _wing_root_rib_authored_transforms: Array[Transform3D] = []
var _lateral_array_curve_joint_mesh: SphereMesh
var _sensor_leading_edge_curve_joint_mesh: SphereMesh
var _dorsal_data_conduit_curve_joint_mesh: SphereMesh
var _fuselage_panel_band_mesh: BoxMesh
var _array_receiver_mesh: SphereMesh
var _boarding_step_mesh: ArrayMesh
var _cockpit_console_key_mesh: BoxMesh
var _engine_collar_mesh: TorusMesh
var _refractory_nozzle_mesh: ArrayMesh
var _engine_collars: Array[MeshInstance3D] = []
var _main_gear_foot_mesh: TorusMesh
var _main_gear_feet: Array[MeshInstance3D] = []
var _pod_separation_collar_mesh: TorusMesh
var _pod_separation_collars: Array[MeshInstance3D] = []
var _escape_pod_status_light_mesh: SphereMesh


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	super._ready()
	if not _arrow_built:
		_arrow_built = rebuild_variant_presentation(_build_arrow_variant)
	if _arrow_built:
		_arrow_built = _reconfigure_component_damage_from_final_root_collision()
	if _arrow_built:
		_arrow_built = _install_entry_heat_target()
	if not component_damage_changed.is_connected(_on_arrow_component_damage_changed):
		component_damage_changed.connect(_on_arrow_component_damage_changed)
	_apply_arrow_metadata()
	_sync_engine_damage_collar()
	_sync_core_systems_damage_silhouette()
	_sync_arrow_engine_presentation_immediately()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_elapsed_arrow += delta
	_update_arrow_presentation(delta)


func get_escape_pod_count() -> int:
	return _escape_pods.size()


func get_escape_pods() -> Array[Node3D]:
	return _escape_pods.duplicate()


func get_escape_pod(side_id: StringName) -> Node3D:
	for pod in _escape_pods:
		if StringName(pod.get_meta("pod_side", &"")) == side_id:
			return pod
	return null


func get_sensor_mast() -> Node3D:
	return _sensor_sweep


## Detached presentation snapshot for the Arrow's modern provisional sensor
## crown. It intentionally exposes renderer geometry only, so focused visual
## checks do not promote the assembly into sensing or flight authority.
func get_recon_crown_snapshot() -> Dictionary:
	var primary_mesh := (
		_recon_primary_aperture.mesh as TorusMesh
		if is_instance_valid(_recon_primary_aperture) else null
	)
	var secondary_mesh := (
		_recon_secondary_aperture.mesh as TorusMesh
		if is_instance_valid(_recon_secondary_aperture) else null
	)
	var hub_mesh := (
		_recon_crown_hub.mesh as SphereMesh
		if is_instance_valid(_recon_crown_hub) else null
	)
	return {
		"presentation_status": &"modern_provisional",
		"evidence_status": EVIDENCE_STATUS,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"visual_only": true,
		"gameplay_authority": false,
		"primary_path": _recon_primary_aperture.get_path() \
			if is_instance_valid(_recon_primary_aperture) else NodePath(),
		"secondary_path": _recon_secondary_aperture.get_path() \
			if is_instance_valid(_recon_secondary_aperture) else NodePath(),
		"hub_path": _recon_crown_hub.get_path() \
			if is_instance_valid(_recon_crown_hub) else NodePath(),
		"primary_inner_radius": primary_mesh.inner_radius if primary_mesh != null else 0.0,
		"primary_outer_radius": primary_mesh.outer_radius if primary_mesh != null else 0.0,
		"secondary_inner_radius": secondary_mesh.inner_radius if secondary_mesh != null else 0.0,
		"secondary_outer_radius": secondary_mesh.outer_radius if secondary_mesh != null else 0.0,
		"secondary_rotation": _recon_secondary_aperture.rotation \
			if is_instance_valid(_recon_secondary_aperture) else Vector3.ZERO,
		"hub_radius": hub_mesh.radius if hub_mesh != null else 0.0,
		"renderer_nodes": 3,
		"geometry_submissions": 3,
		"collision_shapes": 0,
		"lights": 0,
		"timers": 0,
		"sensor_queries": 0,
	}.duplicate(true)


func get_arrow_visual_root() -> Node3D:
	return _arrow_visual


func get_entry_heat_target() -> PlanetaryEntryHeatTarget:
	return _entry_heat_target


## Detached presentation snapshot for the retained engine-collar cue. The
## component ledger remains the only mutable damage state; this method exposes
## only renderer state for focused runtime checks and UI-independent diagnosis.
func get_engine_damage_collar_snapshot() -> Dictionary:
	var model := get_component_damage()
	var state := ShipComponentDamage.ComponentState.NOMINAL
	if model != null and model.is_configured():
		state = model.get_component_state(ENGINE_DAMAGE_CUE_COMPONENT_ID)
	var port := _engine_collars[0] if _engine_collars.size() > 0 else null
	var starboard := _engine_collars[ENGINE_DAMAGE_CUE_COLLAR_INDEX] \
			if _engine_collars.size() > ENGINE_DAMAGE_CUE_COLLAR_INDEX else null
	var mesh := starboard.mesh as TorusMesh if starboard != null else null
	var bounds := AABB()
	if starboard != null and mesh != null:
		bounds = (starboard.transform * mesh.get_aabb()).abs()
	return {
		"component_id": ENGINE_DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamage.state_id_for(state),
		"active": state != ShipComponentDamage.ComponentState.NOMINAL,
		"port_transform": port.transform if port != null else Transform3D(),
		"starboard_transform": starboard.transform if starboard != null else Transform3D(),
		"local_bounds": bounds,
		"mesh_resource_id": mesh.get_instance_id() if mesh != null else 0,
		"material_resource_id": (
			_shared_engine_damage_collar_material.get_instance_id()
			if _shared_engine_damage_collar_material != null else 0
		),
		"renderer_nodes_added": 0,
		"geometry_submissions_added": 0,
		"collision_shapes_added": 0,
		"lights_added": 0,
		"timers_added": 0,
		"processes_added": 0,
		"flashes": false,
		"damage_authority": false,
		"repair_authority": false,
	}.duplicate(true)


## Presentation-only snapshot for the existing core-systems failed silhouette.
## The retained sensor sweep remains the sole changed node; component state and
## repair continue to belong entirely to the inherited damage ledger.
func get_core_systems_damage_silhouette_snapshot() -> Dictionary:
	var model := get_component_damage()
	var state := ShipComponentDamage.ComponentState.NOMINAL
	if model != null and model.is_configured():
		state = model.get_component_state(CORE_SYSTEMS_DAMAGE_CUE_COMPONENT_ID)
	return {
		"component_id": CORE_SYSTEMS_DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamage.state_id_for(state),
		"active": _core_systems_failure_pose_active,
		"sensor_sweep_transform": (
			_sensor_sweep.transform if is_instance_valid(_sensor_sweep) else Transform3D()
		),
		"failed_rotation": CORE_SYSTEMS_FAILED_SENSOR_SWEEP_ROTATION,
		"renderer_nodes_added": 0,
		"geometry_submissions_added": 0,
		"collision_shapes_added": 0,
		"lights_added": 0,
		"timers_added": 0,
		"processes_added": 0,
		"damage_authority": false,
		"repair_authority": false,
	}.duplicate(true)


func get_arrow_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Arrow-class Recon Ship name (A3 page text)",
			"reconnaissance role (A3 page text)",
			"two escape pods described in A3 page text, never observed",
		]),
		"modern_provisional": PackedStringArray([
			"slender silhouette and every dimension",
			"cockpit, canopy, seat, entry side, and cameras",
			"escape-pod shape, position, markings, and release concept",
			"sensor mast and lateral arrays",
			"twin engines, light weapons, materials, and handling values",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


func get_arrow_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Arrow definition must remain provisional")
	if get_escape_pod_count() != SUPPORTED_ESCAPE_POD_COUNT:
		errors.append("Arrow must visibly expose exactly two escape pods")
	if _arrow_visual == null:
		errors.append("Arrow variant visual root is missing")
	if _sensor_sweep == null:
		errors.append("provisional recon sensor mast is missing")
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if left_muzzle == null or right_muzzle == null:
		errors.append("light weapon muzzle markers are missing")
	var performance := get_arrow_visual_performance_report()
	if not bool(performance.valid):
		errors.append("Arrow visual allocation/submission census is invalid")
	var entry_heat_attachment := _inspect_entry_heat_attachment()
	if not bool(entry_heat_attachment.valid):
		errors.append_array(entry_heat_attachment.errors as PackedStringArray)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"escape_pod_count": get_escape_pod_count(),
		"sensor_mast_present": _sensor_sweep != null,
		"weapon_class": &"light_recon_pulse",
		"engine_count": _engine_plumes.size(),
		"entry_heat_attachment": entry_heat_attachment,
		"evidence": get_arrow_evidence_report(),
		"performance": performance,
	}


## Detached whole-visual and local-batch evidence. Geometry submissions sum
## mesh surfaces once per ordinary instance or batch; visible copies count every
## ordinary mesh plus every authored MultiMesh transform.
func get_arrow_visual_performance_report() -> Dictionary:
	var errors := PackedStringArray()
	if not is_instance_valid(_arrow_visual):
		return {
			"valid": false,
			"errors": PackedStringArray(["Arrow visual root is missing"]),
			"legacy": LEGACY_ARROW_VISUAL_CENSUS.duplicate(true),
			"current": {},
			"entry_heat_target": {},
			"wing_root_rib_batch": {},
			"lateral_array_curve_joint_sharing": {},
			"sensor_leading_edge_curve_joint_sharing": {},
			"dorsal_data_conduit_curve_joint_sharing": {},
			"fuselage_panel_band_mesh_sharing": {},
			"array_receiver_mesh_sharing": {},
			"cockpit_console_key_mesh_sharing": {},
			"engine_collar_mesh_sharing": {},
			"main_gear_foot_mesh_sharing": {},
			"pod_separation_collar_mesh_sharing": {},
			"recon_pulse_emitters": {},
		}.duplicate(true)

	var current := _collect_arrow_visual_census()
	for key: String in EXPECTED_ARROW_VISUAL_CENSUS:
		if int(current.get(key, -1)) != int(EXPECTED_ARROW_VISUAL_CENSUS[key]):
			errors.append("whole visual census drift: %s" % key)
	var batch := _inspect_wing_root_rib_batch()
	if not bool(batch.valid):
		errors.append_array(batch.errors as PackedStringArray)
	var lateral_joints := _inspect_lateral_array_curve_joint_sharing()
	if not bool(lateral_joints.valid):
		errors.append_array(lateral_joints.errors as PackedStringArray)
	var leading_edge_joints := _inspect_sensor_leading_edge_curve_joint_sharing()
	if not bool(leading_edge_joints.valid):
		errors.append_array(leading_edge_joints.errors as PackedStringArray)
	var dorsal_conduit_joints := _inspect_dorsal_data_conduit_curve_joint_sharing()
	if not bool(dorsal_conduit_joints.valid):
		errors.append_array(dorsal_conduit_joints.errors as PackedStringArray)
	var panel_bands := _inspect_fuselage_panel_band_mesh_sharing()
	if not bool(panel_bands.valid):
		errors.append_array(panel_bands.errors as PackedStringArray)
	var receivers := _inspect_array_receiver_mesh_sharing()
	if not bool(receivers.valid):
		errors.append_array(receivers.errors as PackedStringArray)
	var console_keys := _inspect_cockpit_console_key_mesh_sharing()
	if not bool(console_keys.valid):
		errors.append_array(console_keys.errors as PackedStringArray)
	var engine_collars := _inspect_engine_collar_mesh_sharing()
	if not bool(engine_collars.valid):
		errors.append_array(engine_collars.errors as PackedStringArray)
	var main_gear_feet := _inspect_main_gear_foot_mesh_sharing()
	if not bool(main_gear_feet.valid):
		errors.append_array(main_gear_feet.errors as PackedStringArray)
	var pod_separation_collars := _inspect_pod_separation_collar_mesh_sharing()
	if not bool(pod_separation_collars.valid):
		errors.append_array(pod_separation_collars.errors as PackedStringArray)
	var pulse_emitters := _inspect_recon_pulse_emitters()
	if not bool(pulse_emitters.valid):
		errors.append_array(pulse_emitters.errors as PackedStringArray)
	var entry_heat_target := _inspect_entry_heat_attachment()
	if not bool(entry_heat_target.valid):
		errors.append_array(entry_heat_target.errors as PackedStringArray)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": LEGACY_ARROW_VISUAL_CENSUS.duplicate(true),
		"phase9_before_entry_heat": PHASE9_ARROW_VISUAL_CENSUS.duplicate(true),
		"expected": EXPECTED_ARROW_VISUAL_CENSUS.duplicate(true),
		"recon_pulse_emitter_delta": RECON_PULSE_EMITTER_VISUAL_DELTA.duplicate(true),
		"current": current,
		"entry_heat_target_delta": ENTRY_HEAT_TARGET_VISUAL_DELTA.duplicate(true),
		"reductions": {
			"nodes": -12,
			"geometry_submissions": -8,
			"unique_mesh_resource_allocations": 19,
			"auto_fallback_names": 4,
			"visible_geometry_copies": -12,
		},
		"phase9_reductions_before_entry_heat": {
			"nodes": 1,
			"geometry_submissions": 1,
			"unique_mesh_resource_allocations": 23,
			"auto_fallback_names": 1,
			"visible_geometry_copies": 0,
		},
		"wing_root_rib_batch": batch,
		"lateral_array_curve_joint_sharing": lateral_joints,
		"sensor_leading_edge_curve_joint_sharing": leading_edge_joints,
		"dorsal_data_conduit_curve_joint_sharing": dorsal_conduit_joints,
		"fuselage_panel_band_mesh_sharing": panel_bands,
		"array_receiver_mesh_sharing": receivers,
		"cockpit_console_key_mesh_sharing": console_keys,
		"engine_collar_mesh_sharing": engine_collars,
		"main_gear_foot_mesh_sharing": main_gear_feet,
		"pod_separation_collar_mesh_sharing": pod_separation_collars,
		"recon_pulse_emitters": pulse_emitters,
		"entry_heat_target": entry_heat_target,
	}.duplicate(true)


func _install_entry_heat_target() -> bool:
	if not is_instance_valid(_arrow_visual) \
			or get_variant_visual_root() != _arrow_visual:
		return false
	if is_instance_valid(_entry_heat_target):
		return _entry_heat_target.get_parent() == _arrow_visual
	if _arrow_visual.get_node_or_null(NodePath(String(ENTRY_HEAT_TARGET_NODE_NAME))) \
			!= null:
		return false
	var candidate := ENTRY_HEAT_TARGET_SCENE.instantiate() \
		as PlanetaryEntryHeatTarget
	if candidate == null:
		return false
	candidate.name = ENTRY_HEAT_TARGET_NODE_NAME
	candidate.top_level = false
	candidate.position = ENTRY_HEAT_TARGET_POSITION
	candidate.rotation = ENTRY_HEAT_TARGET_ROTATION
	candidate.scale = ENTRY_HEAT_TARGET_SCALE
	_arrow_visual.add_child(candidate)
	_entry_heat_target = candidate
	return candidate.is_contract_valid()


func _build_arrow_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Preserve the inherited cockpit/canopy nodes because the common controller
	# owns their private animation and camera references. Every Torrent exterior
	# node is removed; only those functional cockpit nodes are reparented.
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

	_arrow_visual = Node3D.new()
	_arrow_visual.name = "ArrowReconVisual"
	_arrow_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_arrow_visual.set_meta("authenticated_historical_silhouette", false)
	_arrow_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_arrow_visual)
	if cockpit != null:
		cockpit.reparent(_arrow_visual, true)
	if canopy != null:
		canopy.reparent(_arrow_visual, true)
	if hinge_bar != null:
		hinge_bar.reparent(_arrow_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_arrow_visual, true)

	_airframe_shadow_sources.clear()
	_create_arrow_materials()
	_build_slender_airframe()
	_build_manufactured_fairings()
	_build_recon_systems()
	_build_recon_pulse_emitters()
	_build_escape_pods()
	_build_engines_and_landing_gear()
	_restyle_inherited_cockpit(cockpit, canopy)
	_fit_airframe_markings()
	_share_inherited_console_key_meshes(cockpit)
	_fit_nose_survey_service_bay()
	_cut_pressure_panel(_arrow_visual.get_node("ReconFuselage"), "ReplaceableSurveyRadome", 0, 4, 1, 15, _arrow_materials.ceramic)
	_cut_pressure_panel(_arrow_visual.get_node("ReconFuselage"), "PortAvionicsAccess", 5, 10, 11, 15, _arrow_materials.ceramic)
	_cut_pressure_panel(_arrow_visual.get_node("ReconFuselage"), "StarboardAvionicsAccess", 5, 10, 1, 5, _arrow_materials.ceramic)
	_cut_pressure_panel(_arrow_visual.get_node("PortShoulderFairing"), "PortShoulderAccess", 10, 16, 5, 11, _arrow_materials.graphite)
	_cut_pressure_panel(_arrow_visual.get_node("StarboardShoulderFairing"), "StarboardShoulderAccess", 10, 16, 5, 11, _arrow_materials.graphite)
	# Freeze only after tail openings, access-panel cuts and final styling. The
	# original colour meshes and nested panel/marking renderers remain intact.
	StaticShadowBatch.build(_arrow_visual, _airframe_shadow_sources)
	_replace_collision_and_markers()
	if not replace_variant_visual_root(_arrow_visual):
		return false
	return true


func _create_arrow_materials() -> void:
	# The `pearl`/`ceramic` material-family keys are the craft's stable public
	# material API and are left alone; only the tints they carry changed.
	_arrow_materials.pearl = _material(HULL_SLATE, 0.32, 0.43)
	_arrow_materials.ceramic = _material(HULL_SLATE_SHADE, 0.30, 0.49)
	# Bare machined alloy has tighter highlights than the matte composite
	# struts, keel and interior trim. Keep their palette colours unchanged;
	# the finish distinction must survive when both parts sit in the same light.
	_arrow_materials.titanium = _material(TITANIUM, 0.85, 0.28)
	_arrow_materials.graphite = _material(GRAPHITE, 0.06, 0.76)
	_arrow_materials.sensor = _material(Color("285057"), 0.40, 0.32, SENSOR_CYAN, 0.18)
	_arrow_materials.pod = _material(POD_ORANGE, 0.08, 0.58)
	_arrow_materials.engine = _material(ENGINE_CYAN, 0.1, 0.16, ENGINE_CYAN, 3.0)
	_arrow_materials.nav_red = _material(ARROW_NAV_RED, 0.1, 0.2, ARROW_NAV_RED, 2.2)
	_arrow_materials.nav_green = _material(ARROW_NAV_GREEN, 0.1, 0.2, ARROW_NAV_GREEN, 2.2)
	_arrow_materials.glass = _transparent_material(Color(0.24, 0.38, 0.44, 0.30), 0.0, 0.09)
	var hull_albedo := load("res://assets/materials/arrow-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/arrow-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/arrow-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_arrow_materials.pearl, _arrow_materials.ceramic]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.16
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# Triplanar projection keeps the generated aerospace panel treatment stable
		# across the procedural loft and avoids stretched seams at its ring caps.
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.0
		hull_material.uv1_scale = Vector3(0.34, 0.34, 0.34)
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.22
		hull_material.clearcoat_roughness = 0.2
	# Shared micrograin supplies seam-free relief. Projection scale and colour
	# remain local to each role; the shared helper adds no roughness texture,
	# so these authored finish values are also the rendered roughness values.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.titanium, hull_normal, 3.5, 1.20)
	# Struts, keel, mast stem and pod collars are painted composite, not bare
	# metal, so they take the matte end of the craft's roughness range while
	# titanium takes the glossy end.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.graphite, hull_normal, 3.0, 1.10)
	# Survival hardware uses satin amber for release handles and end shields;
	# the pressure cases share the ceramic airframe finish.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.pod, hull_normal, 1.6, 1.30)
	for painted_shell: StandardMaterial3D in [_arrow_materials.pearl, _arrow_materials.ceramic]:
		ShipSurfaceDetail.bind_manufactured_paint(painted_shell)
		painted_shell.metallic = 0.10
		# The hull needs a satin coating, not the deep glossy patches of the
		# high-contrast scuff tile. Retain paint grain and authored panel seams.
		painted_shell.roughness_texture = load("res://assets/materials/manufactured-paint-roughness.png")
		painted_shell.roughness = 0.72
		painted_shell.clearcoat_enabled = false


func get_variant_materials() -> Dictionary:
	return _arrow_materials


func _build_slender_airframe() -> void:
	_sensor_leading_edge_curve_joint_mesh = SphereMesh.new()
	_sensor_leading_edge_curve_joint_mesh.radius = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS
	_sensor_leading_edge_curve_joint_mesh.height = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS * 2.0
	_sensor_leading_edge_curve_joint_mesh.radial_segments = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS
	_sensor_leading_edge_curve_joint_mesh.rings = SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS
	_sensor_leading_edge_curve_joint_mesh.material = _arrow_materials.sensor
	_dorsal_data_conduit_curve_joint_mesh = SphereMesh.new()
	_dorsal_data_conduit_curve_joint_mesh.radius = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS
	_dorsal_data_conduit_curve_joint_mesh.height = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS * 2.0
	_dorsal_data_conduit_curve_joint_mesh.radial_segments = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS
	_dorsal_data_conduit_curve_joint_mesh.rings = DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS
	_dorsal_data_conduit_curve_joint_mesh.material = _arrow_materials.sensor
	_fuselage_panel_band_mesh = BoxMesh.new()
	_fuselage_panel_band_mesh.size = FUSELAGE_PANEL_BAND_SIZE
	_fuselage_panel_band_mesh.material = _arrow_materials.titanium
	# Formed pressure stations carry a slender reconnaissance airframe.
	_airframe_shadow_sources.append(_loft_hull(
		_arrow_visual,
		"ReconFuselage",
		Vector3(0, 1.22, -0.45),
		PackedVector3Array([
			Vector3(0.18, 0.12, -7.2),
			Vector3(0.58, 0.30, -6.15),
			Vector3(1.18, 0.56, -3.7),
			Vector3(1.38, 0.72, -0.7),
			Vector3(1.48, 0.64, 2.6),
			Vector3(1.25, 0.7, 5.2),
			Vector3(0.84, 0.55, 6.3),
		]),
		_arrow_materials.pearl
	))
	_airframe_shadow_sources.append(_loft_hull(
		_arrow_visual,
		"GraphiteKeel",
		Vector3(0, 0.5, -0.1),
		PackedVector3Array([
			Vector3(0.12, 0.08, -5.6),
			Vector3(0.82, 0.34, -3.8),
			Vector3(1.05, 0.38, 1.8),
			Vector3(0.68, 0.3, 5.3),
		]),
		_arrow_materials.graphite
	))

	# Swept sensor wings use cambered skins and inset titanium roots.
	var wing_root_rib_transforms: Array[Transform3D] = []
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var wing := _build_planform_surface(
			"PortSensorWing" if side_index == 0 else "StarboardSensorWing",
			PackedVector3Array([
				Vector3(side * 0.9, 1.05, -2.8),
				Vector3(side * 5.25, 0.92, 1.4),
				Vector3(side * 5.75, 0.86, 3.65),
				Vector3(side * 1.15, 0.98, 2.8),
			]),
			0.18,
			_arrow_materials.ceramic
		)
		_arrow_visual.add_child(wing)
		_airframe_shadow_sources.append(wing)
		wing_root_rib_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0, side * -0.08, 0)),
			Vector3(side * 1.45, 1.03, 1.0)
		))
		_curve_tube(
			_arrow_visual,
			"SensorLeadingEdge",
			PackedVector3Array([
				Vector3(side * 1.0, 1.12, -2.65),
				Vector3(side * 3.4, 1.03, -0.40),
				Vector3(side * 5.25, 0.96, 1.4),
			]),
			SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS,
			_arrow_materials.sensor,
			_sensor_leading_edge_curve_joint_mesh
		)
		var sensor_pod := _loft_hull(
			_arrow_visual,
			"WingtipSensorPod",
			Vector3(side * 5.55, 1.0, 2.45),
			PackedVector3Array([
				Vector3(0.23, 0.17, -1.85),
				Vector3(0.40, 0.23, -1.45),
				Vector3(0.40, 0.23, 1.25),
				Vector3(0.23, 0.17, 1.75),
			]),
			_arrow_materials.ceramic
		)
		_airframe_shadow_sources.append(sensor_pod)
		_cut_pressure_panel(sensor_pod, "FlushPassiveAperture", 5, 10, 5, 11, _arrow_materials.graphite)
		_box(sensor_pod, "ForwardOpticalWindow", Vector3(0, 0, -1.86), Vector3(0.32, 0.17, 0.035), _arrow_materials.sensor)
		_sphere(_arrow_visual, "PortNavigationLight" if side_index == 0 else "StarboardNavigationLight", Vector3(side * 5.64, 1.04, 3.35), 0.115, _arrow_materials.nav_red if side < 0 else _arrow_materials.nav_green)
	_multi_mesh_box(
		_arrow_visual,
		"WingRootRibBatch",
		WING_ROOT_RIB_SIZE,
		_arrow_materials.titanium,
		wing_root_rib_transforms
	)
	_wing_root_rib_authored_transforms = wing_root_rib_transforms.duplicate()

	# Layered dorsal shell follows the long recon fuselage rather than adding a
	# blocky superstructure. Panel seams are slim and restrained.
	_airframe_shadow_sources.append(_loft_hull(
		_arrow_visual,
		"DorsalSurveySpine",
		Vector3(0, 2.08, 1.55),
		PackedVector3Array([
			Vector3(0.22, 0.1, -2.4),
			Vector3(0.67, 0.38, -1.35),
			Vector3(0.76, 0.42, 1.65),
			Vector3(0.44, 0.22, 3.0),
		]),
		_arrow_materials.ceramic
	))
	_curve_tube(
		_arrow_visual,
		"DorsalDataConduit",
		PackedVector3Array([
			Vector3(0, 2.52, 0.94),
			Vector3(0, 2.65, 1.45),
			Vector3(0, 2.42, 3.8),
		]),
		DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS,
		_arrow_materials.sensor,
		_dorsal_data_conduit_curve_joint_mesh
	)
	for seam_z in [-4.4, -2.6, 0.4, 2.2, 4.3]:
		var panel_band := MeshInstance3D.new()
		panel_band.name = "FuselagePanelBand"
		panel_band.position = Vector3(0, FUSELAGE_PANEL_BAND_HEIGHT, seam_z)
		panel_band.mesh = _fuselage_panel_band_mesh
		_arrow_visual.add_child(panel_band)


## Broad shoulder fairings join the cockpit sill and sensor wings into one
## manufactured airframe. All shells are presentation-only and leave the
## controller's boarding route, canopy hinge and escape-pod modules intact.
func _build_manufactured_fairings() -> void:
	# The sill is a formed upper fuselage, with deep side returns seated in
	# the nose and shoulders. Its forward crown rises from the service-bay
	# roof; the cockpit land stays below the previous 2.19 m sill crown.
	var sill := _loft_hull(_arrow_visual, "CockpitSillFairing", Vector3(0, 1.60, 0), PackedVector3Array([
		Vector3(0.75, 0.23, -3.10), Vector3(1.00, 0.37, -2.65),
		Vector3(1.23, 0.57, -1.80), Vector3(1.28, 0.57, 0.60),
		Vector3(0.70, 0.51, 1.20),
	]), _arrow_materials.ceramic)
	_recess_cockpit_fairing(sill)
	_close_dorsal_cabin_overlap(_arrow_visual.get_node("DorsalSurveySpine"))
	_airframe_shadow_sources.append(sill)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_airframe_shadow_sources.append(_loft_hull(_arrow_visual, side_name + "ShoulderFairing", Vector3(side * 1.24, 1.40, 0.0), PackedVector3Array([
			Vector3(0.08, 0.10, -4.2), Vector3(0.32, 0.26, -3.1),
			Vector3(0.53, 0.39, -1.8), Vector3(0.53, 0.39, 0.6),
			Vector3(0.44, 0.28, 2.0), Vector3(0.30, 0.20, 3.0),
		]), _arrow_materials.pearl))
		_airframe_shadow_sources.append(_loft_hull(_arrow_visual, side_name + "EngineIntakeFairing", Vector3(side * 0.96, 1.10, 0.0), PackedVector3Array([
			Vector3(0.54, 0.44, 3.65), Vector3(0.70, 0.56, 4.10),
			Vector3(0.70, 0.56, 5.65), Vector3(0.58, 0.49, 6.40),
		]), _arrow_materials.ceramic))
		_build_survey_intake(side_name, Vector3(side * 1.24, 1.78, -1.82))
		# Three individually fitted access skins and split trailing elevons sit
		# against a darker structural substrate, separated by physical joins.
		var inlay := _build_planform_surface(side_name + "WingInset", PackedVector3Array([
			Vector3(side * 2.10, 1.10, -1.36), Vector3(side * 5.06, 1.00, 1.48),
			Vector3(side * 5.49, 0.95, 3.40), Vector3(side * 2.36, 1.06, 2.74),
		]), 0.035, _arrow_materials.graphite)
		_arrow_visual.add_child(inlay)
		_airframe_shadow_sources.append(inlay)
		for bay in 3:
			var t0 := float(bay) / 3.0 + 0.009
			var t1 := float(bay + 1) / 3.0 - 0.009
			var inner_front := Vector3(side * 2.16, 1.13, -1.25)
			var outer_front := Vector3(side * 4.98, 1.03, 1.47)
			var inner_rear := Vector3(side * 2.37, 1.10, 2.02)
			var outer_rear := Vector3(side * 5.30, 1.01, 2.80)
			var skin := _build_planform_surface(side_name + "SensorWingSkin" + str(bay), PackedVector3Array([
				inner_front.lerp(outer_front, t0), inner_front.lerp(outer_front, t1),
				inner_rear.lerp(outer_rear, t1), inner_rear.lerp(outer_rear, t0),
			]), 0.05, _arrow_materials.ceramic if bay == 1 else _arrow_materials.pearl)
			_arrow_visual.add_child(skin)
			_airframe_shadow_sources.append(skin)
		var elevon := _build_planform_surface(side_name + "SurveyRecognitionMark", PackedVector3Array([
			Vector3(side * 2.40, 1.10, 2.09), Vector3(side * 5.30, 1.00, 2.87),
			Vector3(side * 5.42, 0.98, 3.32), Vector3(side * 2.42, 1.08, 2.67),
		]), 0.055, _arrow_materials.ceramic)
		_arrow_visual.add_child(elevon)
		_airframe_shadow_sources.append(elevon)


## Cut the actual crown around the retained cabin, then close the cut with
## inner returns and a recessed bottom. The floor overlaps that bottom by
## 6 cm; the original side returns, nose cap and canopy sill remain intact.
## Keeping this in the original mesh also keeps the static shadow batch honest.
func _recess_cockpit_fairing(sill: MeshInstance3D) -> void:
	var floor_y := 1.93 - sill.position.y
	var planes: Array[Plane] = [
		Plane(Vector3.RIGHT, 0.99), Plane(Vector3.LEFT, 0.99),
		Plane(Vector3.FORWARD, 1.97 + sill.position.z), Plane(Vector3.BACK, 0.84 - sill.position.z),
		Plane(Vector3.DOWN, -floor_y),
	]
	var arrays := sill.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_arrow_materials.ceramic)
	var rim: Array[PackedVector3Array] = []
	for triangle in range(0, indices.size(), 3):
		var remaining: Array[Dictionary] = []
		for corner in 3:
			var index := indices[triangle + corner]
			remaining.append({"point": vertices[index], "normal": normals[index]})
		# Successive half-space cuts retain each outside fragment exactly once.
		for plane in planes:
			if remaining.is_empty():
				break
			var outside := _clip_cabin_polygon(remaining, plane, false)
			_emit_cabin_polygon(tool, outside)
			remaining = _clip_cabin_polygon(remaining, plane, true)
		# A triangle outside the opening can clip down to a line exactly on
		# an authored loft station. It has no removed area and no cavity rim.
		var removed_area := Vector3.ZERO
		for corner in range(1, remaining.size() - 1):
			removed_area += ((remaining[corner].point as Vector3) - (remaining[0].point as Vector3)).cross((remaining[corner + 1].point as Vector3) - (remaining[0].point as Vector3))
		if removed_area.length_squared() < 0.000000000001:
			continue
		for edge in remaining.size():
			var a: Vector3 = remaining[edge].point
			var b: Vector3 = remaining[(edge + 1) % remaining.size()].point
			if a.distance_squared_to(b) < 0.0000000001:
				continue
			for plane_index in 4:
				if absf(planes[plane_index].distance_to(a)) < 0.000001 and absf(planes[plane_index].distance_to(b)) < 0.000001:
					rim.append(PackedVector3Array([a, b]))
					break
	for edge in rim:
		var a := edge[0]
		var b := edge[1]
		var lower_a := Vector3(a.x, floor_y, a.z)
		var lower_b := Vector3(b.x, floor_y, b.z)
		_emit_cabin_face(tool, PackedVector3Array([a, b, lower_b]))
		_emit_cabin_face(tool, PackedVector3Array([a, lower_b, lower_a]))
		_emit_cabin_face(tool, PackedVector3Array([Vector3(0, floor_y, -0.55), lower_a, lower_b]))
	tool.generate_tangents()
	tool.index()
	sill.mesh = tool.commit()
	# A recessed well is closed but no longer a loft surrounding its AABB
	# centre. The cabin checks validate its inward-facing returns directly.
	sill.remove_meta("closed_loft_hull")
	sill.remove_meta("loft_section_count")


## The narrow spine originally continued forward through the lower seat back.
## Terminate that hidden end at the cabin rear bulkhead with a sealed cap; all
## aft surface triangles stay on their original contour and shading normals.
func _close_dorsal_cabin_overlap(spine: MeshInstance3D) -> void:
	var plane := Plane(Vector3.BACK, 0.84 - spine.position.z)
	var arrays := spine.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_arrow_materials.ceramic)
	for triangle in range(0, indices.size(), 3):
		var polygon: Array[Dictionary] = []
		for corner in 3:
			var index := indices[triangle + corner]
			polygon.append({"point": vertices[index], "normal": normals[index]})
		var retained := _clip_cabin_polygon(polygon, plane, false)
		_emit_cabin_polygon(tool, retained)
		for edge in retained.size():
			var a: Vector3 = retained[edge].point
			var b: Vector3 = retained[(edge + 1) % retained.size()].point
			if absf(plane.distance_to(a)) < 0.000001 and absf(plane.distance_to(b)) < 0.000001:
				_emit_cabin_face(tool, PackedVector3Array([Vector3(0, 0, plane.d), b, a]))
	tool.generate_tangents()
	tool.index()
	spine.mesh = tool.commit()


func _clip_cabin_polygon(polygon: Array[Dictionary], plane: Plane, inside: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge in polygon.size():
		var a := polygon[edge]
		var b := polygon[(edge + 1) % polygon.size()]
		var da := plane.distance_to(a.point)
		var db := plane.distance_to(b.point)
		var keep_a := da <= 0.0 if inside else da >= 0.0
		var keep_b := db <= 0.0 if inside else db >= 0.0
		if keep_a:
			result.append(a)
		if keep_a != keep_b:
			var t := da / (da - db)
			result.append({"point": (a.point as Vector3).lerp(b.point, t), "normal": (a.normal as Vector3).lerp(b.normal, t).normalized()})
	return result


func _emit_cabin_polygon(tool: SurfaceTool, polygon: Array[Dictionary]) -> void:
	for corner in range(1, polygon.size() - 1):
		var points := PackedVector3Array([polygon[0].point, polygon[corner].point, polygon[corner + 1].point])
		var normals := PackedVector3Array([polygon[0].normal, polygon[corner].normal, polygon[corner + 1].normal])
		_emit_cabin_face(tool, points, normals)


func _emit_cabin_face(tool: SurfaceTool, points: PackedVector3Array, normals := PackedVector3Array()) -> void:
	var face_normal := (points[2] - points[0]).cross(points[1] - points[0])
	if face_normal.length_squared() < 0.000000000001:
		return
	face_normal = face_normal.normalized()
	var uv_axis := face_normal.abs().max_axis_index()
	for corner in 3:
		var point := points[corner]
		tool.set_normal(face_normal if normals.is_empty() else normals[corner])
		# Project onto the face's dominant plane, including vertical returns.
		tool.set_uv(Vector2(point.y, point.z) if uv_axis == 0 else (Vector2(point.x, point.z) if uv_axis == 1 else Vector2(point.x, point.y)))
		tool.add_vertex(point)



## Recessed rectangular cooling ducts with a rolled metal lip and a dark back
## wall. These mouths meet the shoulder roof rather than floating over it.
func _build_survey_intake(prefix: String, origin: Vector3) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_arrow_materials.titanium)
	var outer := [Vector2(-0.39, -0.10), Vector2(-0.39, 0.12), Vector2(-0.30, 0.20), Vector2(0.30, 0.20), Vector2(0.39, 0.12), Vector2(0.39, -0.10)]
	for edge in outer.size():
		var a: Vector2 = outer[edge]
		var b: Vector2 = outer[(edge + 1) % outer.size()]
		var pa := Vector3(a.x, a.y, 0)
		var pb := Vector3(b.x, b.y, 0)
		var qa := Vector3(a.x * 0.79, a.y * 0.65, 0.065)
		var qb := Vector3(b.x * 0.79, b.y * 0.65, 0.065)
		for point in [pa, qa, qb, pa, qb, pb, qa, qa + Vector3.BACK * 0.32, qb + Vector3.BACK * 0.32, qa, qb + Vector3.BACK * 0.32, qb]:
			tool.set_uv(Vector2(point.x, point.z))
			tool.add_vertex(point)
	tool.generate_normals()
	var duct := MeshInstance3D.new()
	duct.name = prefix + "SurveyCoolingDuct"
	duct.position = origin
	duct.mesh = tool.commit()
	_arrow_visual.add_child(duct)
	_airframe_shadow_sources.append(duct)
	_box(duct, "RecessedIntake", Vector3(0, 0.035, 0.36), Vector3(0.64, 0.25, 0.035), _arrow_materials.graphite)


## Registration follows the sweep of the actual wing skin. Emergency and
## servicing stencils sit on the shoulder and drive-bay side plates.
func _fit_airframe_markings() -> void:
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0.0 else "Starboard"
		var wing := _arrow_visual.get_node(prefix + "SensorWing") as Node3D
		ShipSurfaceDetail.mark_surface(wing, prefix + "RegistrationPaint", "arrow",
			Vector3(side * 3.7, 1.075 + _sensor_wing_camber(Vector3(side * 3.7, 0, 1.5)), 1.5), Vector2(2.3, 1.15),
			Vector3(side * 0.032, 1.0, 0.02), Vector3(-side * 0.69, 0, 0.72))
	ShipSurfaceDetail.mark_surface(_arrow_visual.get_node("PortShoulderFairing"),
		"CanopyRescuePaint", "rescue", Vector3(-0.53, 0.03, -0.75),
		Vector2(1.15, 0.575), Vector3.LEFT, Vector3.UP)
	ShipSurfaceDetail.mark_surface(_arrow_visual.get_node("PortEngineIntakeFairing"),
		"DriveServicePaint", "service", Vector3(-0.70, 0.0, 5.2),
		Vector2(1.05, 0.525), Vector3.LEFT, Vector3.UP)


func _build_recon_systems() -> void:
	var mast := Node3D.new()
	mast.name = "ReconSensorMast"
	mast.position = Vector3(0, 1.85, 3.55)
	mast.set_meta("provisional_sensor_system", true)
	_arrow_visual.add_child(mast)
	_cylinder(mast, "MastPedestal", Vector3(0, 0.45, 0), 0.16, 0.9, _arrow_materials.titanium)
	_cylinder(mast, "MastStem", Vector3(0, 1.15, 0), 0.08, 0.72, _arrow_materials.graphite)
	_sensor_sweep = Node3D.new()
	_sensor_sweep.name = "SensorSweep"
	_sensor_sweep.position = Vector3(0, 0.95, 0)
	_sensor_sweep.set_meta("visual_only", true)
	_sensor_sweep.set_meta("gameplay_authority", false)
	mast.add_child(_sensor_sweep)
	_recon_primary_aperture = _torus(
		_sensor_sweep,
		"PassiveArrayRing",
		Vector3.ZERO,
		RECON_CROWN_PRIMARY_INNER_RADIUS,
		RECON_CROWN_PRIMARY_OUTER_RADIUS,
		_arrow_materials.sensor,
		Vector3(90, 0, 0)
	)
	_recon_secondary_aperture = _torus(
		_sensor_sweep,
		"OrthogonalPassiveAperture",
		Vector3.ZERO,
		RECON_CROWN_SECONDARY_INNER_RADIUS,
		RECON_CROWN_SECONDARY_OUTER_RADIUS,
		_arrow_materials.sensor,
		RECON_CROWN_SECONDARY_ROTATION_DEGREES
	)
	_recon_crown_hub = _sphere(
		_sensor_sweep,
		"PassiveApertureHub",
		Vector3.ZERO,
		RECON_CROWN_HUB_RADIUS,
		_arrow_materials.graphite
	)
	for crown_renderer in [
		_recon_primary_aperture,
		_recon_secondary_aperture,
		_recon_crown_hub,
	]:
		crown_renderer.set_meta("presentation_status", &"modern_provisional")
		crown_renderer.set_meta("geometry_status", EVIDENCE_STATUS)
		crown_renderer.set_meta("authenticated_historical_silhouette", false)
		crown_renderer.set_meta("visual_only", true)
		crown_renderer.set_meta("gameplay_authority", false)
	_cylinder(_sensor_sweep, "ArrayCrossbar", Vector3.ZERO, 0.055, 1.45, _arrow_materials.titanium, Vector3(0, 0, 90))
	_array_receiver_mesh = _make_array_receiver_mesh()
	_multi_mesh_from_mesh(
		_sensor_sweep,
		ARRAY_RECEIVER_BATCH_NAME,
		_array_receiver_mesh,
		_array_receiver_transforms()
	)

	# Ventral camera/spectral turret is a smooth gimbal, not a weapon hardpoint.
	_sphere(_arrow_visual, "VentralSensorGimbal", Vector3(0, -0.06, -1.8), 0.42, _arrow_materials.titanium)
	_sphere(_arrow_visual, "VentralSensorLens", Vector3(0, -0.33, -2.08), 0.2, _arrow_materials.sensor)
	_lateral_array_curve_joint_mesh = SphereMesh.new()
	_lateral_array_curve_joint_mesh.radius = LATERAL_ARRAY_CURVE_JOINT_RADIUS
	_lateral_array_curve_joint_mesh.height = LATERAL_ARRAY_CURVE_JOINT_RADIUS * 2.0
	_lateral_array_curve_joint_mesh.radial_segments = LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS
	_lateral_array_curve_joint_mesh.rings = LATERAL_ARRAY_CURVE_JOINT_RINGS
	_lateral_array_curve_joint_mesh.material = _arrow_materials.sensor
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_curve_tube(
			_arrow_visual,
			"PortLateralArray" if side_index == 0 else "StarboardLateralArray",
			PackedVector3Array([
				Vector3(side * 1.35, 1.36, -2.0),
				Vector3(side * 2.25, 1.38, -1.2),
				Vector3(side * 3.45, 1.25, -0.25),
			]),
			LATERAL_ARRAY_CURVE_JOINT_RADIUS,
			_arrow_materials.sensor,
			_lateral_array_curve_joint_mesh
		)

	# The retained sensor pivot still owns the sweep and failed-state cant.
	# A low survey head replaces the toy gyroscope silhouette around that pivot.
	_recon_primary_aperture.visible = false
	_recon_secondary_aperture.visible = false
	for part_name in ["MastPedestal", "MastStem"]:
		(mast.get_node(part_name) as Node3D).visible = false
	(_sensor_sweep.get_node("ArrayCrossbar") as Node3D).visible = false
	var survey_head := _loft_hull(_sensor_sweep, "ConformalSurveyHead", Vector3(0, -0.08, 0), PackedVector3Array([
		Vector3(0.68, 0.17, -0.52), Vector3(0.88, 0.22, -0.30),
		Vector3(0.88, 0.22, 0.28), Vector3(0.68, 0.17, 0.54),
	]), _arrow_materials.ceramic)
	_cut_pressure_panel(survey_head, "SurveyReceiverCover", 5, 10, 5, 11, _arrow_materials.graphite)
	_box(survey_head, "SurveyFrontAperture", Vector3(0, 0, -0.53), Vector3(1.12, 0.18, 0.035), _arrow_materials.sensor)
	(mast.get_node("MastPedestal") as Node3D).visible = true
	_box(survey_head, "OpticalRecess", Vector3(0, 0, -0.535), Vector3(1.34, 0.30, 0.06), _arrow_materials.graphite)
	(survey_head.get_node("SurveyFrontAperture") as Node3D).position.z = -0.571
	for wing_sensor in _arrow_visual.get_children():
		if wing_sensor is MeshInstance3D and wing_sensor.has_node("ForwardOpticalWindow"):
			_box(wing_sensor, "OpticalRecess", Vector3(0, 0, -1.87), Vector3(0.40, 0.25, 0.06), _arrow_materials.graphite)
			(wing_sensor.get_node("ForwardOpticalWindow") as Node3D).position.z = -1.907
	# Armored cable raceways follow the retained conduit route exactly. The
	# small exposed termini remain diagnostic cyan; broad spans are protected.
	for route in _arrow_visual.get_children():
		if route.has_node("CurveJoint") and (route.get_node("CurveJoint") as MeshInstance3D).mesh in [_sensor_leading_edge_curve_joint_mesh, _dorsal_data_conduit_curve_joint_mesh, _lateral_array_curve_joint_mesh]:
			var points: Array[Vector3] = []
			for part in route.get_children():
				if part is MeshInstance3D and part.mesh is SphereMesh:
					points.append(part.position)
			for segment in points.size() - 1:
				var start := points[segment]
				var finish := points[segment + 1]
				var raceway := _box(route, "CableRaceway%d" % segment, (start + finish) * 0.5, Vector3(0.15, 0.15, start.distance_to(finish) - 0.10), _arrow_materials.graphite)
				raceway.look_at_from_position(raceway.position, finish, Vector3.UP)



func _build_recon_pulse_emitters() -> void:
	# These small, recessed emitters are a modern provisional presentation of
	# the inherited light-pulse gameplay markers. They are deliberately separate
	# from the ventral optical/spectral gimbal and own no collision or firing
	# authority. At 0.09 m radius the barrels remain visibly lighter than the
	# Torrent's 0.13 m and Jovian's 0.19 m pulse barrels.
	var port_emitter := Node3D.new()
	port_emitter.name = RECON_PULSE_EMITTER_NAMES[0]
	port_emitter.position = RECON_PULSE_EMITTER_POSITIONS[0]
	_configure_recon_pulse_emitter_metadata(port_emitter, &"port")
	_arrow_visual.add_child(port_emitter)
	_box(
		port_emitter,
		"RecessedGraphiteMount",
		Vector3(0.0, 0.09, 0.31),
		RECON_PULSE_MOUNT_SIZE,
		_arrow_materials.graphite
	)
	_torus(
		port_emitter,
		"CompactGraphiteShroud",
		Vector3(0.0, 0.0, 0.08),
		RECON_PULSE_SHROUD_INNER_RADIUS,
		RECON_PULSE_SHROUD_OUTER_RADIUS,
		_arrow_materials.graphite,
		Vector3(90.0, 0.0, 0.0)
	)
	_cylinder(
		port_emitter,
		"LightPulseBarrel",
		Vector3(0.0, 0.0, RECON_PULSE_BARREL_LENGTH * 0.5),
		RECON_PULSE_BARREL_RADIUS,
		RECON_PULSE_BARREL_LENGTH,
		_arrow_materials.graphite,
		Vector3(90.0, 0.0, 0.0)
	)
	_cylinder(
		port_emitter,
		"CyanMuzzleLens",
		Vector3.ZERO,
		RECON_PULSE_MUZZLE_LENS_RADIUS,
		RECON_PULSE_MUZZLE_LENS_DEPTH,
		_arrow_materials.sensor,
		Vector3(90.0, 0.0, 0.0)
	)

	# The mirrored assembly shares the exact four immutable mesh resources while
	# retaining its own named nodes, side tag, and authored muzzle alignment.
	var starboard_emitter := port_emitter.duplicate() as Node3D
	starboard_emitter.name = RECON_PULSE_EMITTER_NAMES[1]
	starboard_emitter.position = RECON_PULSE_EMITTER_POSITIONS[1]
	starboard_emitter.set_meta("weapon_side", &"starboard")
	_arrow_visual.add_child(starboard_emitter)


func _configure_recon_pulse_emitter_metadata(
	emitter: Node3D, side: StringName
	) -> void:
	emitter.set_meta("presentation_status", &"modern_provisional")
	emitter.set_meta("geometry_status", EVIDENCE_STATUS)
	emitter.set_meta("authenticated_historical_weapon", false)
	emitter.set_meta("weapon_class", &"light_recon_pulse")
	emitter.set_meta("weapon_side", side)
	emitter.set_meta("visual_only", true)
	emitter.set_meta("gameplay_authority", false)


func _build_escape_pods() -> void:
	_escape_pods.clear()
	_pod_separation_collars.clear()
	_pod_separation_collar_mesh = null
	_escape_pod_status_light_mesh = SphereMesh.new()
	_escape_pod_status_light_mesh.radius = ESCAPE_POD_STATUS_LIGHT_RADIUS
	_escape_pod_status_light_mesh.height = ESCAPE_POD_STATUS_LIGHT_RADIUS * 2.0
	_escape_pod_status_light_mesh.radial_segments = 28
	_escape_pod_status_light_mesh.rings = 14
	_escape_pod_status_light_mesh.material = _arrow_materials.sensor
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var pod := Node3D.new()
		pod.name = "PortEscapePod" if side_index == 0 else "StarboardEscapePod"
		pod.position = Vector3(side * 1.62, 1.18, 3.25)
		pod.set_meta("escape_pod", true)
		pod.set_meta("pod_side", &"port" if side < 0 else &"starboard")
		pod.set_meta("pod_index", 0 if side < 0 else 1)
		pod.set_meta("creator_roster_claim", &"two_escape_pods_total")
		pod.set_meta("creator_roster_source", &"A3")
		pod.set_meta("geometry_status", EVIDENCE_STATUS)
		pod.set_meta("separable_visual_module", true)
		pod.set_meta("release_mechanism_implemented", false)
		_arrow_visual.add_child(pod)
		_escape_pods.append(pod)
		var pressure_case := _loft_hull(
			pod,
			"PodPressureShell",
			Vector3.ZERO,
			PackedVector3Array([
				Vector3(0.37, 0.28, -1.30),
				Vector3(0.53, 0.40, -1.02),
				Vector3(0.53, 0.40, 0.94),
				Vector3(0.37, 0.28, 1.24),
			]),
			_arrow_materials.ceramic
		)
		# A removable pressure hatch is cut into the case skin. The amber
		# release handle and end shields identify survival hardware without
		# painting the entire pressure vessel like a flotation capsule.
		_cut_pressure_panel(pressure_case, "PressureHatch", 5, 10, 5, 11, _arrow_materials.graphite)
		_box(pod, "HatchRelease", Vector3(0, 0.405, 0.56), Vector3(0.30, 0.025, 0.10), _arrow_materials.pod)
		for end_z in [-1.30, 1.24]:
			_box(pod, "ForwardEmergencyEndShield" if end_z < 0 else "AftEmergencyEndShield", Vector3(0, 0, end_z), Vector3(0.61, 0.40, 0.025), _arrow_materials.pod)
		# Twin saddles belong to the separable module so release/reset retain
		# the existing complete pod identity and attachment transform.
		for mount_z in [-0.78, 0.70]:
			_box(pod, "ForwardPressureCaseSaddle" if mount_z < 0 else "AftPressureCaseSaddle", Vector3(0, -0.36, mount_z), Vector3(1.18, 0.18, 0.18), _arrow_materials.graphite)
			_box(pod, "ForwardReleaseLatch" if mount_z < 0 else "AftReleaseLatch", Vector3(side * 0.55, -0.18, mount_z), Vector3(0.08, 0.24, 0.16), _arrow_materials.titanium)
		_loft_hull(pod, "SeparationClampBed", Vector3.ZERO, PackedVector3Array([
			Vector3(0.53, 0.40, -0.14), Vector3(0.55, 0.56, -0.065),
			Vector3(0.55, 0.56, 0.065), Vector3(0.53, 0.40, 0.14),
		]), _arrow_materials.graphite)
		var separation_collar := _torus(
			pod,
			"PodSeparationCollar",
			Vector3.ZERO,
			POD_SEPARATION_COLLAR_INNER_RADIUS,
			POD_SEPARATION_COLLAR_OUTER_RADIUS,
			_arrow_materials.graphite,
			Vector3(90, 0, 0),
			POD_SEPARATION_COLLAR_SCALE,
			_pod_separation_collar_mesh
		)
		if _pod_separation_collar_mesh == null:
			_pod_separation_collar_mesh = separation_collar.mesh as TorusMesh
		_pod_separation_collars.append(separation_collar)
		_box(pod, "PodIdentityStripe", Vector3(side * 0.537, 0.02, -0.05), Vector3(0.025, 0.14, 0.64), _arrow_materials.pod)
		_sphere(
			pod,
			"PodStatusLight",
			Vector3(side * 0.53, 0.14, -0.72),
			ESCAPE_POD_STATUS_LIGHT_RADIUS,
			_arrow_materials.sensor,
			_escape_pod_status_light_mesh
		)


func _build_engines_and_landing_gear() -> void:
	_engine_plumes.clear()
	_arrow_engine_lights.clear()
	_engine_collars.clear()
	_engine_collar_mesh = null
	_refractory_nozzle_mesh = null
	if _shared_engine_damage_collar_material == null:
		_shared_engine_damage_collar_material = _material(
			ENGINE_DAMAGE_COLLAR_COLOR,
			0.22,
			0.34,
			ENGINE_DAMAGE_COLLAR_COLOR,
			1.25
		)
		_shared_engine_damage_collar_material.resource_local_to_scene = false
	_main_gear_feet.clear()
	_main_gear_foot_mesh = null
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_airframe_shadow_sources.append(_loft_hull(
			_arrow_visual,
			"EfficientEngineHousing",
			Vector3(side * 0.92, 0.94, 5.0),
			PackedVector3Array([
				Vector3(0.32, 0.28, -1.5),
				Vector3(0.64, 0.55, -0.85),
				Vector3(0.68, 0.58, 1.1),
				Vector3(0.54, 0.44, 1.6),
			]),
			_arrow_materials.titanium
		))
		var engine_collar := _torus(
			_arrow_visual,
			"EngineCollar",
			Vector3(side * 0.92, 0.94, 6.48),
			ENGINE_COLLAR_INNER_RADIUS,
			ENGINE_COLLAR_OUTER_RADIUS,
			_arrow_materials.ceramic,
			Vector3(90, 0, 0),
			Vector3.ONE,
			_engine_collar_mesh
		)
		if _engine_collar_mesh == null:
			_engine_collar_mesh = engine_collar.mesh as TorusMesh
		_engine_collars.append(engine_collar)
		var plume := _cylinder(_arrow_visual, "PortEnginePlume" if side_index == 0 else "StarboardEnginePlume", Vector3(side * 0.92, 0.94, 6.92), 0.37, 0.78, _arrow_materials.engine, Vector3(90, 0, 0))
		EngineExhaustPresentation.install(plume, Vector3.UP, true)
		_engine_plumes.append(plume)
		var light := OmniLight3D.new()
		light.name = "PortEngineLight" if side_index == 0 else "StarboardEngineLight"
		light.position = Vector3(side * 0.92, 0.94, 6.7)
		light.light_color = ENGINE_CYAN
		light.light_energy = 0.0
		light.omni_range = 6.2
		light.shadow_enabled = false
		_arrow_visual.add_child(light)
		_arrow_engine_lights.append(light)

	# Open both overlapping engine shells before fitting refractory nozzle
	# petals. The retained functional collars still own the damage response.
	for shell in _arrow_visual.get_children():
		if shell is MeshInstance3D and (String(shell.name).begins_with("EfficientEngineHousing") or "EngineIntakeFairing" in String(shell.name) or (shell.mesh is ArrayMesh and shell.position.z == 5.0)):
			_open_engine_tail(shell)
	for side in [-1.0, 1.0]:
		var prefix := "Port" if side < 0 else "Starboard"
		var fairing := _arrow_visual.get_node(prefix + "EngineIntakeFairing") as MeshInstance3D
		_cut_pressure_panel(fairing, prefix + "DriveServiceDoor", 4, 9, 3, 12, _arrow_materials.pearl)
		_build_refractory_nozzle(prefix, Vector3(side * 0.92, 0.94, 6.05))

	# Narrow tricycle gear suits the slender hull and keeps a stable parked pose.
	for side in [-1.0, 1.0]:
		_cylinder(_arrow_visual, "MainGearStrut", Vector3(side * 1.55, -0.05, 2.25), 0.07, 1.25, _arrow_materials.graphite, Vector3(0, 0, side * -8.0))
		var main_gear_foot := _torus(
			_arrow_visual,
			"MainGearFoot",
			Vector3(side * 1.7, -0.64, 2.25),
			MAIN_GEAR_FOOT_INNER_RADIUS,
			MAIN_GEAR_FOOT_OUTER_RADIUS,
			_arrow_materials.titanium,
			Vector3(90, 0, 0),
			MAIN_GEAR_FOOT_SCALE,
			_main_gear_foot_mesh
		)
		if _main_gear_foot_mesh == null:
			_main_gear_foot_mesh = main_gear_foot.mesh as TorusMesh
		_main_gear_feet.append(main_gear_foot)
	_cylinder(_arrow_visual, "NoseGearStrut", Vector3(0, -0.02, -4.2), 0.065, 1.12, _arrow_materials.graphite)
	_torus(_arrow_visual, "NoseGearFoot", Vector3(0, -0.56, -4.2), 0.18, 0.29, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.4, 0.55, 1.0))
	_boarding_step_mesh = _rounded_box_mesh(BOARDING_STEP_SIZE, _arrow_materials.pod)
	var boarding_step_transforms: Array[Transform3D] = []
	for step_index in BOARDING_STEP_VISIBLE_COPIES:
		boarding_step_transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(
				-1.65 - float(step_index) * 0.32,
				-0.12 + float(step_index) * 0.28,
				0.05
			)
		))
	_multi_mesh_from_mesh(
		_arrow_visual,
		BOARDING_STEP_BATCH_NAME,
		_boarding_step_mesh,
		boarding_step_transforms
	)


func _open_engine_tail(shell: MeshInstance3D) -> void:
	var arrays := shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var end_z := shell.mesh.get_aabb().end.z
	var retained := PackedInt32Array()
	for triangle in range(0, indices.size(), 3):
		var cap := true
		for corner in 3:
			cap = cap and is_equal_approx(vertices[indices[triangle + corner]].z, end_z)
		if not cap:
			for corner in 3: retained.append(indices[triangle + corner])
	arrays[Mesh.ARRAY_INDEX] = retained
	var replacement := ArrayMesh.new()
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	replacement.surface_set_material(0, shell.mesh.surface_get_material(0))
	shell.mesh = replacement


func _build_refractory_nozzle(prefix: String, origin: Vector3) -> void:
	if _refractory_nozzle_mesh == null:
		_refractory_nozzle_mesh = _formed_refractory_nozzle_mesh()
	var nozzle := MeshInstance3D.new()
	nozzle.name = prefix + "RefractoryNozzle"
	nozzle.position = origin
	nozzle.mesh = _refractory_nozzle_mesh
	_arrow_visual.add_child(nozzle)
	_airframe_shadow_sources.append(nozzle)


## Six curved slices per petal preserve the sixteen expansion joints without
## flat fan blades. Closed side returns give each petal real wall thickness;
## a recessed dark backplate prevents the open engine shell showing through.
func _formed_refractory_nozzle_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_arrow_materials.graphite)
	var profile := PackedVector2Array([
		Vector2(0.56, 0.0), Vector2(0.57, 0.24),
		Vector2(0.47, 0.83), Vector2(0.46, 0.88),
		Vector2(0.37, 0.88), Vector2(0.35, 0.82),
		Vector2(0.32, 0.08),
	])
	var caps := Geometry2D.triangulate_polygon(profile)
	for petal in 16:
		var a0 := TAU * (float(petal) + 0.01) / 16.0
		var a1 := TAU * (float(petal + 1) - 0.01) / 16.0
		var distance := 0.0
		for section in profile.size():
			var p := profile[section]
			var q := profile[(section + 1) % profile.size()]
			var slope := q - p
			for slice in 6:
				var a := lerpf(a0, a1, float(slice) / 6.0)
				var b := lerpf(a0, a1, float(slice + 1) / 6.0)
				var points := PackedVector3Array([
					Vector3(cos(a) * p.x, sin(a) * p.x, p.y),
					Vector3(cos(b) * p.x, sin(b) * p.x, p.y),
					Vector3(cos(b) * q.x, sin(b) * q.x, q.y),
					Vector3(cos(a) * q.x, sin(a) * q.x, q.y),
				])
				for index in [0, 2, 1, 0, 3, 2]:
					var point := points[index]
					var radial := Vector2(point.x, point.y).normalized()
					tool.set_normal(Vector3(slope.y * radial.x, slope.y * radial.y, -slope.x).normalized())
					tool.set_uv(Vector2(float(petal) + float(slice + (1 if index in [1, 2] else 0)) / 6.0,
						distance + (slope.length() if index in [2, 3] else 0.0)))
					tool.add_vertex(point)
			distance += slope.length()
		for angle in [a0, a1]:
			var normal := Vector3(-sin(angle), cos(angle), 0.0) * (-1.0 if angle == a0 else 1.0)
			for triangle in range(0, caps.size(), 3):
				var points := PackedVector3Array()
				for corner in 3:
					var point := profile[caps[triangle + corner]]
					points.append(Vector3(cos(angle) * point.x, sin(angle) * point.x, point.y))
				if (points[2] - points[0]).cross(points[1] - points[0]).dot(normal) < 0.0:
					points.reverse()
				for point in points:
					tool.set_normal(normal)
					tool.set_uv(Vector2(Vector2(point.x, point.y).length(), point.z))
					tool.add_vertex(point)
	# The backing is ahead of the nozzle mouth, behind the retained live plume.
	for segment in 96:
		var a := TAU * float(segment) / 96.0
		var b := TAU * float(segment + 1) / 96.0
		for point in [Vector3(0, 0, 0.055), Vector3(cos(b) * 0.325, sin(b) * 0.325, 0.055), Vector3(cos(a) * 0.325, sin(a) * 0.325, 0.055)]:
			tool.set_normal(Vector3.BACK)
			tool.set_uv(Vector2(point.x, point.y))
			tool.add_vertex(point)
	tool.generate_tangents()
	var mesh := tool.commit()
	mesh.resource_local_to_scene = false
	return mesh


func _restyle_inherited_cockpit(cockpit: Node3D, canopy: Node3D) -> void:
	# Former square sill walls and floating rails are retained controller-local
	# nodes, dressed by the continuous pressure fairing and laminated canopy.
	for obsolete_name in ["ForwardPressureWall", "RearPressureWall", "PortSill", "StarboardSill"]:
		(cockpit.get_node(obsolete_name) as Node3D).visible = false
	for obsolete_name in ["PortCanopyTopRail", "StarboardCanopyTopRail", "PortCanopyLowerRail", "StarboardCanopyLowerRail", "PortCanopyLowerPressureSeal", "StarboardCanopyLowerPressureSeal", "PortCanopyLaminateEdge", "StarboardCanopyLaminateEdge", "CanopyNosePressureSeal", "PortCanopyNoseFrame", "StarboardCanopyNoseFrame", "PortCanopyRearUpright", "StarboardCanopyRearUpright"]:
		(canopy.get_node(obsolete_name) as Node3D).visible = false
	if cockpit != null:
		_fit_arrow_instrument_binnacle(cockpit)
		# Darker interior preserves high contrast behind the unusually clear canopy.
		for node in cockpit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if "ConsoleKey" in mesh_instance.name:
				mesh_instance.material_override = _arrow_materials.sensor
	if canopy != null:
		var glass := canopy.get_node_or_null("CanopyGlass") as MeshInstance3D
		if glass != null:
			# Transparent dielectric glazing reveals the physical recon cockpit.
			# The pilot camera omits this exterior-only layer, preserving its
			# unobstructed physical eye point through the same animated canopy.
			glass.material_override = _arrow_materials.glass
			glass.layers = 1 << 18
			var pilot_camera := cockpit.find_child("CockpitCamera", true, false) as Camera3D
			if pilot_camera != null:
				pilot_camera.set_cull_mask_value(19, false)
			# Replace the inherited inward-wound wedge with the outward pressure
			# shell; preserve the exact renderer and controller-owned hinge.
			var shell := _loft_hull(canopy, "CanopyShellConstruction", Vector3.ZERO, PackedVector3Array([
				Vector3(0.06, 0.06, -1.79), Vector3(0.61, 0.40, -1.20),
				Vector3(1.04, 0.67, -0.30), Vector3(1.24, 0.775, 0.90),
				Vector3(1.15, 0.66, 1.79),
			]), _arrow_materials.glass)
			glass.mesh = shell.mesh
			# This replacement loft is centred on its own body; the shared
			# pressure canopy now emits hinge-local vertices instead. Own the
			# offset explicitly so the glass still covers the pilot and console.
			glass.position = Vector3(0.0, 0.46, -1.82)
			glass.set_meta("loft_section_count", shell.get_meta("loft_section_count"))
			_fit_canopy_frame(glass, 7, _arrow_materials.graphite)
			_fit_canopy_frame(glass, 16, _arrow_materials.graphite)
			canopy.remove_child(shell)
			shell.free()
			# Retain the inherited physical canopy envelope. Enlarging the shell
			# independently of its private camera/hinge geometry creates a cyan first-
			# person wash and overstates the high-visibility canopy from outside.
			glass.scale = Vector3.ONE
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _arrow_materials.graphite
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _arrow_materials.ceramic


## The existing live faces sit inside machined wells, beneath a shallow brow.
## Keep the authored eye point, control identities and readout tree: this is
## replacement construction on the inherited renderers, not another HUD.
func _fit_arrow_instrument_binnacle(cockpit: Node3D) -> void:
	var cluster := cockpit.get_node("InstrumentCluster") as Node3D
	var hood := cluster.get_node("InstrumentHood") as MeshInstance3D
	hood.mesh = _cockpit_formed_enclosure_mesh([
		Vector4(1.20, -0.53, 0.06, -0.53),
		Vector4(1.56, -0.32, 0.285, -0.08),
		Vector4(1.56, -0.30, 0.285, 0.07),
	], _arrow_materials.graphite, _arrow_materials.titanium)
	# A projecting perimeter makes the unchanged flight display a recessed
	# removable module. Its top remains below the original hood crown.
	for bezel_name in ["DisplayBezelTop", "DisplayBezelBottom", "PortDisplayBezelSide", "StarboardDisplayBezelSide"]:
		var bezel := cluster.get_node(bezel_name) as MeshInstance3D
		bezel.position.z = 0.15
		var size := bezel.mesh.get_aabb().size
		size.z = 0.12
		bezel.mesh = _cockpit_formed_enclosure_mesh([
			Vector4(size.x, -size.y * 0.5, size.y * 0.5, -size.z * 0.5),
			Vector4(size.x, -size.y * 0.5, size.y * 0.5, size.z * 0.5),
		], _arrow_materials.titanium)
	# Both round sockets share one turned profile; their lit dial/text stays
	# at its original depth, behind the outer lip and ahead of the backing.
	var socket_mesh := _arrow_instrument_socket_mesh()
	for side_name in ["Port", "Starboard"]:
		var socket := cluster.get_node(side_name + "StatusRepeater") as MeshInstance3D
		socket.mesh = socket_mesh
		socket.rotation = Vector3.ZERO
		socket.material_override = null
	# The old broad glowing strip becomes an inset caution lens below
	# the display, supported by the lower sill instead of spanning both dials.
	var caution := cluster.get_node("WarningStrip") as MeshInstance3D
	caution.scale.x = 0.48
	caution.position.z = 0.115
	for side_name in ["Port", "Starboard"]:
		var console := cockpit.get_node(side_name + "SideConsole") as MeshInstance3D
		console.material_override = _arrow_materials.graphite


func _arrow_instrument_socket_mesh() -> ArrayMesh:
	# Radius/depth stations: backing, recessed bore, chamfer, lip, outer case.
	# Closed ends and explicit per-face UVs keep this valid for lit materials.
	var profile := [Vector2(0.0, 0.022), Vector2(0.128, 0.022),
		Vector2(0.130, 0.055), Vector2(0.134, 0.077),
		Vector2(0.141, 0.077), Vector2(0.146, 0.060),
		Vector2(0.146, -0.045), Vector2(0.0, -0.045)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var finish := (_arrow_materials.titanium as StandardMaterial3D).duplicate() as StandardMaterial3D
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.72
	finish.metallic = 0.25
	tool.set_material(finish)
	for station in profile.size() - 1:
		for segment in 48:
			var a := TAU * float(segment) / 48.0
			var b := TAU * float(segment + 1) / 48.0
			var start: Vector2 = profile[station]
			var end: Vector2 = profile[station + 1]
			var points := [Vector3(cos(a) * start.x, sin(a) * start.x, start.y),
				Vector3(cos(b) * start.x, sin(b) * start.x, start.y),
				Vector3(cos(b) * end.x, sin(b) * end.x, end.y),
				Vector3(cos(a) * end.x, sin(a) * end.x, end.y)]
			for triangle in [[0, 1, 2], [0, 2, 3]]:
				var normal: Vector3 = (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]])
				if normal.length_squared() < 0.0000000001:
					continue
				for index in triangle:
					var point: Vector3 = points[index]
					# Analytic turned normals stay smooth around the axis while
					# each profile station retains its machined edge.
					var radial := Vector2(point.x, point.y).normalized()
					if radial == Vector2.ZERO:
						radial = Vector2(cos(a), sin(a))
					var slope := end - start
					tool.set_normal(Vector3(-slope.y * radial.x, -slope.y * radial.y, slope.x).normalized())
					tool.set_color(Color(0.84, 0.84, 0.84) if station in [3, 4] else Color(0.30, 0.34, 0.36))
					# Each annular strip unwraps around the axis, including the
					# cylindrical bore where planar UVs would collapse.
					tool.set_uv(Vector2(float(segment + (1 if index in [1, 2] else 0)) / 48.0, float(station + (1 if index in [2, 3] else 0)) / 7.0))
					tool.add_vertex(point)
	tool.generate_tangents()
	return tool.commit()


func _share_inherited_console_key_meshes(cockpit: Node3D) -> void:
	if cockpit == null:
		return
	var shared_mesh: BoxMesh
	for key_name: String in COCKPIT_CONSOLE_KEY_SHARED_MESH_ROSTER:
		var key := cockpit.get_node_or_null(NodePath(key_name)) as MeshInstance3D
		if key == null or key.mesh is not BoxMesh \
				or key.material_override != _arrow_materials.sensor:
			return
		if shared_mesh == null:
			shared_mesh = key.mesh as BoxMesh
		elif key.mesh.surface_get_material(0) != shared_mesh.surface_get_material(0) \
				or not key.mesh.get_aabb().is_equal_approx(shared_mesh.get_aabb()):
			return
	if shared_mesh == null:
		return
	_cockpit_console_key_mesh = shared_mesh
	for key_name: String in COCKPIT_CONSOLE_KEY_SHARED_MESH_ROSTER:
		(cockpit.get_node(NodePath(key_name)) as MeshInstance3D).mesh = shared_mesh


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	_add_box_collision("ArrowHullCollision", Vector3(0, 0.85, -0.35), Vector3(3.1, 1.65, 12.2))
	_add_box_collision("ArrowWingCollision", Vector3(0, 0.88, 1.25), Vector3(11.1, 0.48, 4.9))

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-2.45, -0.02, 0.15)
	if exit != null:
		exit.position = Vector3(-6.6, -0.9, 0.25)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-1.05, 0.72, -5.7)
	if right_muzzle != null:
		right_muzzle.position = Vector3(1.05, 0.72, -5.7)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-2.45, 0.48, 0.15)
		_add_flank_approach_range(boarding_area)


## PORT-BOARDING-001. The fleet-wide boarding volume is a single 4.5 m sphere on
## the ship's own boarding marker. On this craft that marker sits at local
## (-2.45, -0.02, 0.15) — *underneath the sensor wing*, whose collision spans
## local x = -5.55 … 5.55 by z = -1.2 … 3.7 at y = 0.64 … 1.12. A standing capsule
## cannot occupy the sphere's centre at all, so the prompt only appeared where the
## sphere happened to poke out past the wing: measured on the live berth deck, of
## the 0.5 m grid cells a player can actually stand on, the whole starboard flank
## from z = 7.0 to z = 10.5 offered no prompt, and the nearest cell that did was
## inside the port engine housing. That is the reported "only when you are
## standing inside of the engine".
##
## The sphere is deliberately left exactly as inherited — it is a published
## fleet-wide contract — and a craft-shaped approach volume is added beside it.
## It is sized to the craft plus a walk-up margin, not to the deck: half extents
## 6.9 m laterally and 7.6 m along the hull against a hull of 5.55 / 6.10. With
## the production player's own 2.35 m interaction sphere that reaches 9.25 / 9.95,
## which covers every standable metre of the 16.8 x 17.0 m berth deck (half
## extents 8.4 / 8.5) on both flanks and around nose and tail. It stops 2.55 m
## short of a point 7.0 m off the boarding marker along the lateral axis, so the
## bare-sphere 7.0 m fallback boundary that
## `tests/boarding_accessibility_test.gd` pins is still exercised, not widened.
func _add_flank_approach_range(boarding_area: Area3D) -> void:
	var existing := boarding_area.get_node_or_null("ArrowApproachRange")
	if existing != null:
		boarding_area.remove_child(existing)
		existing.queue_free()
	var approach := CollisionShape3D.new()
	approach.name = "ArrowApproachRange"
	var shape := BoxShape3D.new()
	shape.size = Vector3(13.8, 2.8, 15.2)
	approach.shape = shape
	# Centred on the hull rather than on the boarding marker, expressed relative to
	# the area's own offset so the marker keeps publishing the same world position.
	approach.position = -boarding_area.position
	boarding_area.add_child(approach)


func _add_box_collision(node_name: String, collision_position: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)


func _update_arrow_presentation(delta: float) -> void:
	if _sensor_sweep != null:
		if _core_systems_failure_pose_active:
			_sensor_sweep.rotation = CORE_SYSTEMS_FAILED_SENSOR_SWEEP_ROTATION
		else:
			_sensor_sweep.rotation.y = fmod(
				_sensor_sweep.rotation.y + delta * SENSOR_SWEEP_YAW_RATE,
				TAU
			)
			_sensor_sweep.rotation.x = (
				sin(_elapsed_arrow * SENSOR_SWEEP_PITCH_RATE)
				* SENSOR_SWEEP_PITCH_AMPLITUDE
			)
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_active := not is_destroyed() and engine_state in [ENGINE_STARTING, ENGINE_ONLINE]
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.25 + 0.1 * sin(_elapsed_arrow * 16.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.48 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.52
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var exhaust_geometry := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.y = lerpf(
			plume.scale.y,
			0.42 + engine_level * 1.3 * exhaust_geometry,
			1.0 - exp(-8.0 * delta)
		)
	for light in _arrow_engine_lights:
		light.light_energy = engine_level * 2.2
	_apply_engine_exhaust_damage_presentation(
		_engine_plumes, _arrow_engine_lights, engine_active, exhaust_profile
	)


func _on_arrow_component_damage_changed(
	component_id: StringName,
	_state: int,
	_integrity: float
	) -> void:
	if component_id == ENGINE_DAMAGE_CUE_COMPONENT_ID:
		_sync_engine_damage_collar()
	if component_id == CORE_SYSTEMS_DAMAGE_CUE_COMPONENT_ID:
		_sync_core_systems_damage_silhouette()


func _sync_engine_damage_collar() -> void:
	if _engine_collars.size() != ENGINE_COLLAR_VISIBLE_COPIES:
		return
	var model := get_component_damage()
	var state := ShipComponentDamage.ComponentState.NOMINAL
	if model != null and model.is_configured():
		state = model.get_component_state(ENGINE_DAMAGE_CUE_COMPONENT_ID)
	var damaged := state != ShipComponentDamage.ComponentState.NOMINAL
	var nominal_transforms := _engine_collar_transforms()
	for index in _engine_collars.size():
		var collar := _engine_collars[index]
		if not is_instance_valid(collar):
			continue
		collar.transform = (
			_engine_damage_collar_transform()
			if damaged and index == ENGINE_DAMAGE_CUE_COLLAR_INDEX
			else nominal_transforms[index]
		)
		collar.material_override = (
			_shared_engine_damage_collar_material
			if damaged and index == ENGINE_DAMAGE_CUE_COLLAR_INDEX
			else null
		)


func _sync_core_systems_damage_silhouette() -> void:
	var model := get_component_damage()
	var state := ShipComponentDamage.ComponentState.NOMINAL
	if model != null and model.is_configured():
		state = model.get_component_state(CORE_SYSTEMS_DAMAGE_CUE_COMPONENT_ID)
	_core_systems_failure_pose_active = state == ShipComponentDamage.ComponentState.FAILED
	if is_instance_valid(_sensor_sweep):
		_sensor_sweep.rotation = (
			CORE_SYSTEMS_FAILED_SENSOR_SWEEP_ROTATION
			if _core_systems_failure_pose_active else Vector3.ZERO
		)


func _sync_arrow_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	var exhaust_profile := get_engine_exhaust_damage_presentation_profile()
	var engine_level := 0.25 if state == ENGINE_STARTING else (0.48 if state == ENGINE_ONLINE else 0.0)
	engine_level *= float(exhaust_profile.get("intensity_multiplier", 1.0))
	var exhaust_geometry := float(exhaust_profile.get("geometry_multiplier", 1.0))
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			plume.scale.y = 0.42 + engine_level * 1.3 * exhaust_geometry if active else 0.42
	for light in _arrow_engine_lights:
		if is_instance_valid(light):
			light.light_energy = engine_level * 2.2 if active else 0.0
	_apply_engine_exhaust_damage_presentation(
		_engine_plumes, _arrow_engine_lights, active, exhaust_profile
	)


func _sync_variant_engine_presentation_immediately() -> void:
	_sync_arrow_engine_presentation_immediately()


func _preflight_variant_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	return super._preflight_variant_reset_for_reuse(spawn_transform)


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	_elapsed_arrow = 0.0
	_sync_engine_damage_collar()
	_sync_core_systems_damage_silhouette()


func _apply_arrow_metadata() -> void:
	set_meta("arrow_recon_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("creator_supported_escape_pod_count", SUPPORTED_ESCAPE_POD_COUNT)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"light_recon_pulse")
	set_meta("engine_profile", &"efficient_twin_recon")


func _collect_arrow_visual_census() -> Dictionary:
	var mesh_instances := _arrow_visual.find_children(
		"*", "MeshInstance3D", true, false
	)
	var multi_mesh_instances := _arrow_visual.find_children(
		"*", "MultiMeshInstance3D", true, false
	)
	var unique_mesh_resources := {}
	for candidate in mesh_instances:
		var instance := candidate as MeshInstance3D
		if instance.mesh != null:
			unique_mesh_resources[instance.mesh.get_instance_id()] = true
	var visible_geometry_copies := 0
	var geometry_submissions := 0
	for candidate in mesh_instances:
		var instance := candidate as MeshInstance3D
		if instance.mesh != null:
			geometry_submissions += instance.mesh.get_surface_count()
		if instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			visible_geometry_copies += 1
	for candidate in multi_mesh_instances:
		var instance := candidate as MultiMeshInstance3D
		if instance.multimesh == null:
			continue
		visible_geometry_copies += instance.multimesh.visible_instance_count
		if instance.multimesh.mesh != null:
			unique_mesh_resources[instance.multimesh.mesh.get_instance_id()] = true
			geometry_submissions += instance.multimesh.mesh.get_surface_count()
	var auto_fallback_names := 0
	for candidate in _arrow_visual.find_children("*", "Node", true, false):
		if str((candidate as Node).name).begins_with("@"):
			auto_fallback_names += 1
	return {
		"nodes": _count_visual_nodes(_arrow_visual),
		"mesh_instance_nodes": mesh_instances.size(),
		"multi_mesh_instance_nodes": multi_mesh_instances.size(),
		"geometry_submissions": geometry_submissions,
		"visible_geometry_copies": visible_geometry_copies,
		"unique_mesh_resource_allocations": unique_mesh_resources.size(),
		"auto_fallback_names": auto_fallback_names,
	}


func _inspect_recon_pulse_emitters() -> Dictionary:
	var errors := PackedStringArray()
	var roster := PackedStringArray()
	var mesh_resources := {}
	var renderer_nodes := 0
	for index in RECON_PULSE_EMITTER_NAMES.size():
		var emitter_name: String = RECON_PULSE_EMITTER_NAMES[index]
		var emitter := _arrow_visual.get_node_or_null(emitter_name) as Node3D
		if emitter == null:
			errors.append("Arrow recon pulse-emitter roster is missing %s" % emitter_name)
			continue
		roster.append(str(emitter.name))
		if emitter.get_parent() != _arrow_visual \
				or emitter.position != RECON_PULSE_EMITTER_POSITIONS[index] \
				or emitter.rotation != Vector3.ZERO \
				or emitter.scale != Vector3.ONE:
			errors.append("%s authored muzzle alignment drift" % emitter_name)
		var marker_name := "LeftMuzzle" if index == 0 else "RightMuzzle"
		var marker := get_node_or_null(marker_name) as Marker3D
		if marker == null or marker.position != emitter.position:
			errors.append("%s no longer aligns to %s" % [emitter_name, marker_name])
		var expected_side: StringName = &"port" if index == 0 else &"starboard"
		if emitter.get_meta("presentation_status", &"") != &"modern_provisional" \
				or emitter.get_meta("geometry_status", &"") != EVIDENCE_STATUS \
				or bool(emitter.get_meta("authenticated_historical_weapon", true)) \
				or emitter.get_meta("weapon_class", &"") != &"light_recon_pulse" \
				or emitter.get_meta("weapon_side", &"") != expected_side \
				or not bool(emitter.get_meta("visual_only", false)) \
				or bool(emitter.get_meta("gameplay_authority", true)):
			errors.append("%s modern provisional presentation tags drift" % emitter_name)
		if emitter.get_child_count() != RECON_PULSE_EMITTER_COMPONENT_ROSTER.size():
			errors.append("%s exact four-component roster drift" % emitter_name)
		for component_name: String in RECON_PULSE_EMITTER_COMPONENT_ROSTER:
			var component := emitter.get_node_or_null(component_name) as MeshInstance3D
			if component == null or component.get_parent() != emitter \
					or component.mesh == null:
				errors.append("%s is missing %s" % [emitter_name, component_name])
				continue
			renderer_nodes += 1
			mesh_resources[component.mesh.get_instance_id()] = true
			if component.find_children("*", "CollisionObject3D", true, false).size() > 0:
				errors.append("%s gained collision authority" % component.get_path())

		var mount := emitter.get_node_or_null("RecessedGraphiteMount") as MeshInstance3D
		var shroud := emitter.get_node_or_null("CompactGraphiteShroud") as MeshInstance3D
		var barrel := emitter.get_node_or_null("LightPulseBarrel") as MeshInstance3D
		var lens := emitter.get_node_or_null("CyanMuzzleLens") as MeshInstance3D
		if mount == null or not (mount.mesh is BoxMesh) \
				or (mount.mesh as BoxMesh).size != RECON_PULSE_MOUNT_SIZE \
				or mount.position != Vector3(0.0, 0.09, 0.31) \
				or (mount.mesh as BoxMesh).material != _arrow_materials.graphite:
			errors.append("%s compact graphite recessed-mount dimensions drift" % emitter_name)
		if shroud == null or not (shroud.mesh is TorusMesh) \
				or not is_equal_approx((shroud.mesh as TorusMesh).inner_radius, RECON_PULSE_SHROUD_INNER_RADIUS) \
				or not is_equal_approx((shroud.mesh as TorusMesh).outer_radius, RECON_PULSE_SHROUD_OUTER_RADIUS) \
				or shroud.position != Vector3(0.0, 0.0, 0.08) \
				or not shroud.rotation.is_equal_approx(Vector3(PI * 0.5, 0.0, 0.0)) \
				or (shroud.mesh as TorusMesh).material != _arrow_materials.graphite:
			errors.append("%s compact graphite shroud dimensions drift" % emitter_name)
		if barrel == null or barrel.mesh == null \
				or barrel.position != Vector3(0.0, 0.0, RECON_PULSE_BARREL_LENGTH * 0.5) \
				or not barrel.rotation.is_equal_approx(Vector3(PI * 0.5, 0.0, 0.0)) \
				or not is_equal_approx(barrel.mesh.get_aabb().size.x, RECON_PULSE_BARREL_RADIUS * 2.0) \
				or not is_equal_approx(barrel.mesh.get_aabb().size.z, RECON_PULSE_BARREL_RADIUS * 2.0) \
				or not is_equal_approx(barrel.mesh.get_aabb().size.y, RECON_PULSE_BARREL_LENGTH) \
				or barrel.mesh.surface_get_material(0) != _arrow_materials.graphite:
			errors.append("%s 0.09m light-pulse barrel dimensions drift" % emitter_name)
		if lens == null or lens.mesh == null \
				or lens.position != Vector3.ZERO \
				or not lens.rotation.is_equal_approx(Vector3(PI * 0.5, 0.0, 0.0)) \
				or not is_equal_approx(lens.mesh.get_aabb().size.x, RECON_PULSE_MUZZLE_LENS_RADIUS * 2.0) \
				or not is_equal_approx(lens.mesh.get_aabb().size.y, RECON_PULSE_MUZZLE_LENS_DEPTH) \
				or lens.mesh.surface_get_material(0) != _arrow_materials.sensor:
			errors.append("%s cyan muzzle-lens dimensions or material drift" % emitter_name)
		if not emitter.find_children("*", "CollisionObject3D", true, false).is_empty():
			errors.append("%s must remain an uncollidable visual assembly" % emitter_name)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"assembly_roster": roster,
		"component_roster": RECON_PULSE_EMITTER_COMPONENT_ROSTER.duplicate(),
		"assembly_nodes": roster.size(),
		"renderer_nodes": renderer_nodes,
		"geometry_submissions": renderer_nodes,
		"visible_geometry_copies": renderer_nodes,
		"unique_mesh_resource_allocations": mesh_resources.size(),
		"barrel_radius": RECON_PULSE_BARREL_RADIUS,
		"barrel_length": RECON_PULSE_BARREL_LENGTH,
		"mount_size": RECON_PULSE_MOUNT_SIZE,
		"muzzle_positions": RECON_PULSE_EMITTER_POSITIONS.duplicate(),
	}.duplicate(true)


func _inspect_entry_heat_attachment() -> Dictionary:
	var errors := PackedStringArray()
	var target := _entry_heat_target
	if not is_instance_valid(target):
		return {
			"valid": false,
			"errors": PackedStringArray(["Arrow entry-heat target is missing"]),
		}.duplicate(true)
	if target.name != ENTRY_HEAT_TARGET_NODE_NAME:
		errors.append("Arrow entry-heat target name drift")
	if target.get_parent() != _arrow_visual:
		errors.append("Arrow entry-heat target is not a direct visual-root child")
	if target.top_level:
		errors.append("Arrow entry-heat target gained top-level transform authority")
	if target.position != ENTRY_HEAT_TARGET_POSITION \
			or target.rotation != ENTRY_HEAT_TARGET_ROTATION \
			or target.scale != ENTRY_HEAT_TARGET_SCALE:
		errors.append("Arrow entry-heat target authored transform drift")
	if _count_direct_entry_heat_targets() != 1:
		errors.append("Arrow entry-heat target instance roster drift")
	var target_audit := target.audit()
	if not bool(target_audit.get("valid", false)):
		errors.append("Arrow entry-heat target contract is invalid")
	var authored_bounds := target.transform * target.authored_visual_bounds
	var expanded_bounds := target.transform * target.get_expanded_visual_bounds()
	if not authored_bounds.is_equal_approx(
			ENTRY_HEAT_TARGET_AUTHORED_LOCAL_BOUNDS
		) or not expanded_bounds.is_equal_approx(
			ENTRY_HEAT_TARGET_EXPANDED_LOCAL_BOUNDS
		):
		errors.append("Arrow entry-heat target fitted bounds drift")
	var presentation := target.get_presentation()
	var state := presentation.get_state_snapshot() if presentation != null else {}
	var material := target.get_material()
	var overlay := target.get_overlay()
	var compression := target.get_compression_bow()
	var mesh := overlay.mesh if overlay != null else null
	var compression_mesh := compression.mesh if compression != null else null
	var shader := material.shader if material != null else null
	var renderer := presentation.get_renderer_snapshot() if presentation != null else {}
	var configured := bool(state.get("configured", false))
	if presentation == null:
		errors.append("Arrow entry-heat presentation is missing")
	elif not configured:
		if int(state.get("generation", -1)) != 0 \
				or int(state.get("revision", -1)) != 0 \
				or int(state.get("presented_observation_count", -1)) != 0 \
				or bool(state.get("has_presented_observation", true)):
			errors.append("Arrow entry-heat target gained automatic presentation authority")
	elif not bool(presentation.audit().get("valid", false)):
		errors.append("Arrow configured entry-heat presentation is invalid")
	if material == null \
			or not material.resource_local_to_scene:
		errors.append("Arrow entry-heat target exclusive material drift")
	elif not configured and float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) != 0.0:
		errors.append("Arrow unconfigured entry-heat target baseline drift")
	var baseline := renderer.get("baseline", {}) as Dictionary
	if configured and float(baseline.get(
		PlanetaryEntryHeatTarget.OWNED_PARAMETER, -1.0
	)) != 0.0:
		errors.append("Arrow configured entry-heat target baseline drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_name": StringName(target.name),
		"direct_visual_root_child": target.get_parent() == _arrow_visual,
		"top_level": target.top_level,
		"authored_transform": {
			"position": target.position,
			"rotation": target.rotation,
			"scale": target.scale,
		},
		"authored_local_bounds": authored_bounds,
		"expanded_local_bounds": expanded_bounds,
		"target_subtree_nodes": _count_visual_nodes(target),
		"renderer_nodes": (1 if overlay != null else 0) + (1 if compression != null else 0),
		"surface_count": (mesh.get_surface_count() if mesh != null else 0) + (
			compression_mesh.get_surface_count() if compression_mesh != null else 0
		),
		"geometry_submissions": (mesh.get_surface_count() if mesh != null else 0) + (
			compression_mesh.get_surface_count() if compression_mesh != null else 0
		),
		"visible_geometry_copies": (1 if overlay != null else 0) + (
			1 if compression != null else 0
		),
		"unique_mesh_resource_allocations": (
			(1 if mesh != null else 0) + (1 if compression_mesh != null and compression_mesh != mesh else 0)
		),
		"exclusive_material_allocations": 1 if material != null else 0,
		"mesh_resource_instance_id": mesh.get_instance_id() if mesh != null else 0,
		"compression_mesh_resource_instance_id": (
			compression_mesh.get_instance_id() if compression_mesh != null else 0
		),
		"material_instance_id": material.get_instance_id() if material != null else 0,
		"shader_instance_id": shader.get_instance_id() if shader != null else 0,
		"material_local_to_scene": (
			material.resource_local_to_scene if material != null else false
		),
		"intensity_baseline": (
			baseline.get(PlanetaryEntryHeatTarget.OWNED_PARAMETER, null)
			if configured else 0.0
		),
		"live_intensity": (
			material.get_shader_parameter(PlanetaryEntryHeatTarget.OWNED_PARAMETER)
			if material != null else null
		),
		"presentation_configured": configured,
		"presentation_generation": int(state.get("generation", -1)),
		"presentation_revision": int(state.get("revision", -1)),
		"target_contract": target_audit,
	}.duplicate(true)


func _count_direct_entry_heat_targets() -> int:
	var count := 0
	for child in _arrow_visual.get_children():
		if child is PlanetaryEntryHeatTarget:
			count += 1
	return count


func _inspect_wing_root_rib_batch() -> Dictionary:
	var errors := PackedStringArray()
	var batch := _arrow_visual.get_node_or_null(
		"WingRootRibBatch"
	) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return {
			"valid": false,
			"errors": PackedStringArray(["wing-root rib batch is missing"]),
		}.duplicate(true)
	var multimesh := batch.multimesh
	var mesh := multimesh.mesh as BoxMesh
	if _arrow_visual.get_node_or_null("WingRootRib") != null:
		errors.append("retired ordinary wing-root rib renderer remains")
	if multimesh.transform_format != MultiMesh.TRANSFORM_3D:
		errors.append("wing-root rib transform format drift")
	if multimesh.use_colors or multimesh.use_custom_data:
		errors.append("wing-root rib batch gained per-copy payload")
	if multimesh.instance_count != WING_ROOT_RIB_VISIBLE_COPIES \
		or multimesh.visible_instance_count != WING_ROOT_RIB_VISIBLE_COPIES:
		errors.append("wing-root rib visible-copy roster drift")
	if mesh == null or not mesh.size.is_equal_approx(WING_ROOT_RIB_SIZE):
		errors.append("wing-root rib primitive allocation drift")
	elif mesh.material != _arrow_materials.titanium:
		errors.append("wing-root rib material identity drift")
	var expected_transforms := _wing_root_rib_transforms()
	if not _transform_arrays_match(
		_wing_root_rib_authored_transforms, expected_transforms
	):
		errors.append("wing-root rib authored transform snapshot drift")
	var metadata_transforms := batch.get_meta(
		"authored_instance_transforms", []
	) as Array
	if not _transform_arrays_match(metadata_transforms, expected_transforms):
		errors.append("wing-root rib authored transform metadata drift")
	var expected_buffer := _multi_mesh_transform_buffer(expected_transforms)
	# The dummy/headless renderer discards MultiMesh buffers and reads every
	# transform as identity. A live renderer retains the deterministic payload,
	# so validate it whenever it is available while always auditing the CPU copy.
	if not multimesh.buffer.is_empty() and multimesh.buffer != expected_buffer:
		errors.append("wing-root rib renderer transform buffer drift")
	if mesh != null:
		var expected_bounds := _transformed_mesh_bounds(
			mesh.get_aabb(), expected_transforms
		)
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("wing-root rib culling bounds drift")
	if not batch.transform.is_equal_approx(Transform3D.IDENTITY) or not batch.visible:
		errors.append("wing-root rib batch-root presentation drift")
	if batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		or batch.material_override != null:
		errors.append("wing-root rib render-state drift")
	var metadata_keys := batch.get_meta_list()
	if batch.get_child_count() != 0 or batch.get_script() != null \
		or not batch.get_groups().is_empty() \
		or metadata_keys.size() != 2 \
		or not metadata_keys.has(&"visual_detail_only") \
		or not metadata_keys.has(&"authored_instance_transforms") \
		or not bool(batch.get_meta("visual_detail_only", false)):
		errors.append("wing-root rib batch gained semantic authority")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_name": str(batch.name),
		"geometry_nodes": 1,
		"geometry_submissions": 1,
		"visible_geometry_copies": multimesh.visible_instance_count,
		"primitive_mesh_allocations": 1 if mesh != null else 0,
		"multimesh_allocations": 1,
		"renderer_buffer_auditable": not multimesh.buffer.is_empty(),
		"culling_bounds": multimesh.custom_aabb,
		"authored_transforms": _wing_root_rib_authored_transforms.duplicate(),
		"legacy": {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
			"multimesh_allocations": 0,
		},
	}.duplicate(true)


func _inspect_lateral_array_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _lateral_array_curve_joint_transforms()
	for index in LATERAL_ARRAY_CURVE_JOINT_PATHS.size():
		var path := NodePath(LATERAL_ARRAY_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"lateral-array CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("lateral-array CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("lateral-array CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append("lateral-array CurveJoint gained semantic authority: %s" % path)

	var family_child_count := 0
	for parent_name in [&"PortLateralArray", &"StarboardLateralArray"]:
		var parent := _arrow_visual.get_node_or_null(NodePath(parent_name))
		if parent == null:
			errors.append("lateral-array parent missing: %s" % parent_name)
			continue
		for child in parent.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(LATERAL_ARRAY_CURVE_JOINT_PATHS):
		errors.append("lateral-array CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("lateral-array CurveJoint shared-mesh identity drift")

	var mesh := _lateral_array_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, LATERAL_ARRAY_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, LATERAL_ARRAY_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != LATERAL_ARRAY_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("lateral-array CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("lateral-array CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("lateral-array CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("lateral-array CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 5,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		},
	}.duplicate(true)


func _inspect_sensor_leading_edge_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _sensor_leading_edge_curve_joint_transforms()
	for index in SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS.size():
		var path := NodePath(SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"sensor-leading-edge CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("sensor-leading-edge CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("sensor-leading-edge CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append("sensor-leading-edge CurveJoint gained semantic authority: %s" % path)

	var family_child_count := 0
	for parent_path in [NodePath("SensorLeadingEdge"), NodePath("@Node3D@4")]:
		var parent := _arrow_visual.get_node_or_null(parent_path)
		if parent == null:
			errors.append("sensor-leading-edge parent missing: %s" % parent_path)
			continue
		for child in parent.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS):
		errors.append("sensor-leading-edge CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("sensor-leading-edge CurveJoint shared-mesh identity drift")

	var mesh := _sensor_leading_edge_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("sensor-leading-edge CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("sensor-leading-edge CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("sensor-leading-edge CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("sensor-leading-edge CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 5,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		},
	}.duplicate(true)


func _inspect_dorsal_data_conduit_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _dorsal_data_conduit_curve_joint_transforms()
	for index in DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS.size():
		var path := NodePath(DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"dorsal-data-conduit CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("dorsal-data-conduit CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("dorsal-data-conduit CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append(
				"dorsal-data-conduit CurveJoint gained semantic authority: %s" % path
			)

	var conduit := _arrow_visual.get_node_or_null(^"DorsalDataConduit") as Node3D
	var family_child_count := 0
	if conduit == null:
		errors.append("dorsal-data-conduit parent missing")
	else:
		for child in conduit.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS):
		errors.append("dorsal-data-conduit CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("dorsal-data-conduit CurveJoint shared-mesh identity drift")

	var mesh := _dorsal_data_conduit_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("dorsal-data-conduit CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("dorsal-data-conduit CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("dorsal-data-conduit CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("dorsal-data-conduit CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 2,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 3,
			"geometry_submissions": 3,
			"visible_geometry_copies": 3,
			"primitive_mesh_allocations": 3,
		},
	}.duplicate(true)


func _inspect_fuselage_panel_band_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var bands: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _fuselage_panel_band_transforms()
	for child in _arrow_visual.get_children():
		var band := child as MeshInstance3D
		if band == null or band.mesh is not BoxMesh:
			continue
		var band_mesh := band.mesh as BoxMesh
		if not band_mesh.size.is_equal_approx(FUSELAGE_PANEL_BAND_SIZE):
			continue
		var index := bands.size()
		bands.append(band)
		var path := str(_arrow_visual.get_path_to(band))
		actual_paths.append(path)
		mesh_identities[band.mesh.get_instance_id()] = true
		if index >= expected_transforms.size() \
			or not band.transform.is_equal_approx(expected_transforms[index]):
			errors.append("fuselage panel-band transform drift: %s" % path)
		if not band.visible \
			or band.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or band.material_override != null \
			or band.material_overlay != null \
			or band.layers != 1 \
			or not is_zero_approx(band.transparency):
			errors.append("fuselage panel-band render-state drift: %s" % path)
		if band.get_child_count() != 0 \
			or band.get_script() != null \
			or not band.get_groups().is_empty() \
			or not band.get_meta_list().is_empty():
			errors.append("fuselage panel-band gained semantic authority: %s" % path)

	if bands.size() != FUSELAGE_PANEL_BAND_VISIBLE_COPIES \
		or actual_paths.is_empty() \
		or actual_paths[0] != FUSELAGE_PANEL_BAND_STABLE_PATH:
		errors.append("fuselage panel-band visible/path roster drift")
	for index in range(1, actual_paths.size()):
		if not actual_paths[index].begins_with("@MeshInstance3D@"):
			errors.append("fuselage panel-band generated sibling path drift")
			break
	if mesh_identities.size() != 1:
		errors.append("fuselage panel-band shared-mesh identity drift")

	var mesh := _fuselage_panel_band_mesh
	if mesh == null \
		or not mesh.size.is_equal_approx(FUSELAGE_PANEL_BAND_SIZE) \
		or mesh.get_surface_count() != 1:
		errors.append("fuselage panel-band primitive recipe drift")
	elif mesh.material != _arrow_materials.titanium:
		errors.append("fuselage panel-band material identity drift")
	if mesh != null:
		if not mesh.get_meta_list().is_empty():
			errors.append("fuselage panel-band mesh gained metadata")
		if mesh.resource_local_to_scene:
			errors.append("fuselage panel-band mesh became scene-local")
	for band in bands:
		if band.mesh != mesh:
			errors.append("fuselage panel-band retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": bands.size(),
		"geometry_submissions": bands.size(),
		"visible_geometry_copies": bands.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 4,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"mesh_kind": &"BoxMesh",
		"mesh_size": mesh.size if mesh != null else Vector3.ZERO,
		"legacy": {
			"geometry_nodes": 5,
			"geometry_submissions": 5,
			"visible_geometry_copies": 5,
			"primitive_mesh_allocations": 5,
		},
	}.duplicate(true)


func _count_visual_nodes(search_root: Node) -> int:
	var count := 1
	for child in search_root.get_children():
		count += _count_visual_nodes(child)
	return count


static func _wing_root_rib_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		transforms.append(Transform3D(
			Basis.from_euler(Vector3(0, side * -0.08, 0)),
			Vector3(side * 1.45, 1.03, 1.0)
		))
	return transforms


static func _lateral_array_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-1.35, 1.36, -2.0)),
		Transform3D(Basis.IDENTITY, Vector3(-2.25, 1.38, -1.2)),
		Transform3D(Basis.IDENTITY, Vector3(-3.45, 1.25, -0.25)),
		Transform3D(Basis.IDENTITY, Vector3(1.35, 1.36, -2.0)),
		Transform3D(Basis.IDENTITY, Vector3(2.25, 1.38, -1.2)),
		Transform3D(Basis.IDENTITY, Vector3(3.45, 1.25, -0.25)),
	]


static func _sensor_leading_edge_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-1.0, 1.12, -2.65)),
		Transform3D(Basis.IDENTITY, Vector3(-3.4, 1.03, -0.40)),
		Transform3D(Basis.IDENTITY, Vector3(-5.25, 0.96, 1.4)),
		Transform3D(Basis.IDENTITY, Vector3(1.0, 1.12, -2.65)),
		Transform3D(Basis.IDENTITY, Vector3(3.4, 1.03, -0.40)),
		Transform3D(Basis.IDENTITY, Vector3(5.25, 0.96, 1.4)),
	]


static func _dorsal_data_conduit_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.52, 0.94)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.65, 1.45)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.42, 3.8)),
	]


static func _fuselage_panel_band_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for seam_z in [-4.4, -2.6, 0.4, 2.2, 4.3]:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(0, FUSELAGE_PANEL_BAND_HEIGHT, seam_z)))
	return transforms


static func _transform_arrays_match(
	actual: Array,
	expected: Array[Transform3D]
	) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if not (actual[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	# Keep opaque procedural structure visibly closed independently of face
	# culling. `_transparent_material` restores CULL_BACK for the canopy below.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := _material(color, metallic, roughness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _multi_mesh_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	material: Material,
	transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return _multi_mesh_from_mesh(parent, node_name, mesh, transforms)


func _multi_mesh_from_mesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	multimesh.buffer = _multi_mesh_transform_buffer(transforms)
	multimesh.custom_aabb = _transformed_mesh_bounds(mesh.get_aabb(), transforms)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.set_meta("visual_detail_only", true)
	instance.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(instance)
	return instance


static func _multi_mesh_transform_buffer(
	transforms: Array[Transform3D]
	) -> PackedFloat32Array:
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


static func _transformed_mesh_bounds(
	mesh_bounds: AABB,
	transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var piece := (value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


func _loft_hull(parent: Node3D, node_name: String, origin: Vector3, authored_sections: PackedVector3Array, material: Material) -> MeshInstance3D:
	var curved_pressure_shell := node_name == "CanopyShellConstruction"
	# Only formed airframe skins get continuous curvature. Pressure-pod cases,
	# saddles and removable covers retain their plate lands.
	var formed_airframe := node_name in ["ReconFuselage", "GraphiteKeel", "DorsalSurveySpine", "WingtipSensorPod", "EfficientEngineHousing", "CockpitSillFairing"] or node_name.ends_with("ShoulderFairing") or node_name.ends_with("EngineIntakeFairing")
	var sections := PackedVector3Array()
	for index in authored_sections.size() - 1:
		var start := authored_sections[index]
		var finish := authored_sections[index + 1]
		for sample_index in 5:
			var t := float(sample_index) / 5.0
			var curved := start.cubic_interpolate(finish, authored_sections[maxi(0, index - 1)], authored_sections[mini(authored_sections.size() - 1, index + 2)], t) if curved_pressure_shell or formed_airframe else start.lerp(finish, t)
			if formed_airframe:
				# Keep authored extrema and all boarding/pod clearances. A cubic
				# tangent may otherwise swell beyond adjacent pressure stations.
				curved.x = clampf(curved.x, minf(start.x, finish.x), maxf(start.x, finish.x))
				curved.y = clampf(curved.y, minf(start.y, finish.y), maxf(start.y, finish.y))
			sections.append(Vector3(maxf(0.01, curved.x), maxf(0.01, curved.y), lerpf(start.z, finish.z, t)))
	sections.append(authored_sections[-1])
	const PLATE_QUADRANT := [
		Vector2(1.0, 0.0), Vector2(1.0, 0.3), Vector2(1.0, 0.6), Vector2(1.0, 0.88),
		Vector2(0.97, 0.97), Vector2(0.88, 1.0), Vector2(0.6, 1.0), Vector2(0.3, 1.0),
	]
	const RING_COUNT := 32
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	if not curved_pressure_shell and not formed_airframe:
		tool.set_smooth_group(-1)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in RING_COUNT:
			var angle := TAU * float(ring_index) / float(RING_COUNT)
			var cosine := cos(angle)
			var sine := sin(angle)
			var exponent := 0.55 if formed_airframe else 0.72
			var rounded_x := signf(cosine) * pow(absf(cosine), exponent)
			var rounded_y := signf(sine) * pow(absf(sine), exponent)
			if not curved_pressure_shell and not formed_airframe:
				# Four broad faces joined by narrow two-step chamfers.
				var quarter := ring_index / 8
				var point: Vector2 = PLATE_QUADRANT[ring_index % 8]
				for turn in quarter:
					point = Vector2(-point.y, point.x)
				rounded_x = point.x
				rounded_y = point.y
			tool.set_uv(Vector2(float(ring_index) / float(RING_COUNT), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in RING_COUNT:
			var next_ring := (ring_index + 1) % RING_COUNT
			var current := section_index * RING_COUNT + ring_index
			var current_next := section_index * RING_COUNT + next_ring
			var following := (section_index + 1) * RING_COUNT + ring_index
			var following_next := (section_index + 1) * RING_COUNT + next_ring
			tool.add_index(current)
			tool.add_index(following)
			tool.add_index(following_next)
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(current_next)
	if formed_airframe:
		tool.set_smooth_group(-1)
	var front_center := sections.size() * RING_COUNT
	tool.add_vertex(Vector3(0, 0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0, 0, sections[sections.size() - 1].z))
	for ring_index in RING_COUNT:
		var next_ring := (ring_index + 1) % RING_COUNT
		tool.add_index(front_center)
		tool.add_index(ring_index)
		tool.add_index(next_ring)
		var rear_base := (sections.size() - 1) * RING_COUNT
		tool.add_index(rear_center)
		tool.add_index(rear_base + next_ring)
		tool.add_index(rear_base + ring_index)
	tool.generate_normals()
	if not curved_pressure_shell:
		tool.index()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	instance.set_meta("closed_loft_hull", true)
	instance.set_meta("loft_section_count", sections.size())
	parent.add_child(instance)
	return instance


## All nested wing skins follow one pressure contour, so access panels and
## elevons stay seated as the large wing carries a shallow airfoil crown.
func _sensor_wing_camber(point: Vector3) -> float:
	var span := clampf((absf(point.x) - 0.9) / 4.85, 0.0, 1.0)
	var leading_z := lerpf(-2.8, 1.4, span)
	var trailing_z := lerpf(2.8, 3.65, span)
	var chord := clampf((point.z - leading_z) / (trailing_z - leading_z), 0.0, 1.0)
	return sin(chord * PI) * lerpf(0.20, 0.07, span)


func _build_planform_surface(node_name: String, outline: PackedVector3Array, depth: float, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	const SPAN_STEPS := 8
	const CHORD_STEPS := 12
	var center := (outline[0] + outline[1] + outline[2] + outline[3]) * 0.25
	center.y += _sensor_wing_camber(center)
	for face in 2:
		tool.set_smooth_group(face)
		var height := depth * (0.5 if face == 0 else -0.5)
		for span_index in SPAN_STEPS:
			for chord_index in CHORD_STEPS:
				var quad := PackedVector3Array()
				for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var span := float(span_index + corner.x) / SPAN_STEPS
					var chord := float(chord_index + corner.y) / CHORD_STEPS
					var point := outline[0].lerp(outline[1], span).lerp(outline[3].lerp(outline[2], span), chord)
					point.y += _sensor_wing_camber(point) + height
					quad.append(point)
				# Orient against the local face, not the whole curved surface's
				# centroid: a shallow crown can rise above the bottom centre.
				var face_center := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25 - Vector3.UP * height
				_arrow_panel_triangle(tool, quad[0], quad[1], quad[2], face_center)
				_arrow_panel_triangle(tool, quad[0], quad[2], quad[3], face_center)
	tool.set_smooth_group(-1)
	for edge in 4:
		var count := SPAN_STEPS if edge % 2 == 0 else CHORD_STEPS
		for sample_index in count:
			var a := outline[edge].lerp(outline[(edge + 1) % 4], float(sample_index) / count)
			var b := outline[edge].lerp(outline[(edge + 1) % 4], float(sample_index + 1) / count)
			a.y += _sensor_wing_camber(a)
			b.y += _sensor_wing_camber(b)
			var offset := Vector3.UP * depth * 0.5
			_arrow_panel_triangle(tool, a - offset, a + offset, b + offset, center)
			_arrow_panel_triangle(tool, a - offset, b + offset, b - offset, center)
	tool.generate_normals()
	tool.index()
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = tool.commit()
	return mesh


func _arrow_panel_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	# Godot front faces wind clockwise; orient each bevel against its centroid.
	var points := [a, b, c]
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - center) > 0.0:
		points = [a, c, b]
	for point: Vector3 in points:
		tool.set_uv(Vector2(point.x, point.z) * 0.2)
		tool.add_vertex(point)


func _curve_tube(
	parent: Node3D,
	node_name: String,
	points: PackedVector3Array,
	radius: float,
	material: Material,
	joint_mesh: SphereMesh = null,
	) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		_sphere(root, "CurveJoint", point, radius, material, joint_mesh)
	return root


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	# Chamfered rims at the Arrow's frozen 36 radial segments. Note what this does
	# and does not reach: the Arrow's engine housings are `_loft_hull` surfaces
	# that close on a centre point with averaged normals, and its engine collars
	# are tori, so neither ever had a 90° rim. What passes through here is the
	# mast pedestal and stem, the array crossbar, the gear struts, the conduit
	# tube segments and the emissive plume. Wall subdivision: see
	# `ShipSurfaceDetail.CYLINDER_WALL_RINGS`.
	instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 36, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, material
	)
	parent.add_child(instance)
	return instance


func _sphere(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	material: Material,
	shared_mesh: SphereMesh = null,
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := shared_mesh
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 28
		mesh.rings = 14
		mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _make_array_receiver_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = ARRAY_RECEIVER_RADIUS
	mesh.height = ARRAY_RECEIVER_RADIUS * 2.0
	mesh.radial_segments = 28
	mesh.rings = 14
	mesh.material = _arrow_materials.sensor
	return mesh


func _array_receiver_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-0.67, 0, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0.67, 0, 0)),
	]


func _inspect_array_receiver_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var batch := (
		_sensor_sweep.get_node_or_null(ARRAY_RECEIVER_BATCH_NAME)
		as MultiMeshInstance3D if is_instance_valid(_sensor_sweep) else null
	)
	if batch == null or batch.multimesh == null:
		return {
			"valid": false,
			"errors": PackedStringArray(["array receiver batch is missing"]),
		}.duplicate(true)
	var multimesh := batch.multimesh
	var mesh := multimesh.mesh as SphereMesh
	var expected_transforms := _array_receiver_transforms()
	var metadata_transforms := batch.get_meta("authored_instance_transforms", []) as Array
	if multimesh.transform_format != MultiMesh.TRANSFORM_3D \
			or multimesh.use_colors or multimesh.use_custom_data:
		errors.append("array receiver batch format drift")
	if multimesh.instance_count != ARRAY_RECEIVER_VISIBLE_COPIES \
			or multimesh.visible_instance_count != ARRAY_RECEIVER_VISIBLE_COPIES:
		errors.append("array receiver visible-copy roster drift")
	if not _transform_arrays_match(metadata_transforms, expected_transforms):
		errors.append("array receiver authored transform metadata drift")
	var expected_buffer := _multi_mesh_transform_buffer(expected_transforms)
	if not multimesh.buffer.is_empty() and multimesh.buffer != expected_buffer:
		errors.append("array receiver renderer transform buffer drift")
	if mesh != null and not multimesh.custom_aabb.is_equal_approx(
		_transformed_mesh_bounds(mesh.get_aabb(), expected_transforms)
	):
		errors.append("array receiver culling bounds drift")
	if not batch.transform.is_equal_approx(Transform3D.IDENTITY) or not batch.visible \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or batch.material_override != null or batch.material_overlay != null \
			or batch.layers != 1 or not is_zero_approx(batch.transparency):
		errors.append("array receiver render-state drift")
	var metadata_keys := batch.get_meta_list()
	if batch.get_child_count() != 0 or batch.get_script() != null \
			or not batch.get_groups().is_empty() or metadata_keys.size() != 2 \
			or not metadata_keys.has(&"visual_detail_only") \
			or not metadata_keys.has(&"authored_instance_transforms") \
			or not bool(batch.get_meta("visual_detail_only", false)):
		errors.append("array receiver batch gained semantic authority")
	if _array_receiver_mesh == null or mesh != _array_receiver_mesh \
			or not is_equal_approx(_array_receiver_mesh.radius, ARRAY_RECEIVER_RADIUS) \
			or not is_equal_approx(_array_receiver_mesh.height, ARRAY_RECEIVER_RADIUS * 2.0) \
			or _array_receiver_mesh.radial_segments != 28 or _array_receiver_mesh.rings != 14 \
			or _array_receiver_mesh.material != _arrow_materials.sensor \
			or _array_receiver_mesh.resource_local_to_scene:
		errors.append("array receiver primitive recipe drift")
	return {
		"valid": errors.is_empty(), "errors": errors,
		"node_path": str(_arrow_visual.get_path_to(batch)),
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": 1, "geometry_submissions": 1,
		"visible_geometry_copies": multimesh.visible_instance_count,
		"primitive_mesh_allocations": 1 if mesh != null else 0,
		"multimesh_allocations": 1,
		"resource_allocation_reduction": 1,
		"legacy": {"geometry_nodes": 2, "geometry_submissions": 2, "visible_geometry_copies": 2, "primitive_mesh_allocations": 2, "multimesh_allocations": 0},
	}.duplicate(true)


func _inspect_cockpit_console_key_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var cockpit := _arrow_visual.get_node_or_null("CockpitInterior") as Node3D \
		if is_instance_valid(_arrow_visual) else null
	var keys: Array[MeshInstance3D] = []
	var node_paths := PackedStringArray()
	var mesh_identities := {}
	if cockpit == null:
		errors.append("inherited cockpit is missing")
	else:
		for key_name: String in COCKPIT_CONSOLE_KEY_SHARED_MESH_ROSTER:
			var key := cockpit.get_node_or_null(NodePath(key_name)) as MeshInstance3D
			if key == null:
				errors.append("console-key roster drift: %s" % key_name)
				continue
			keys.append(key)
			node_paths.append(str(_arrow_visual.get_path_to(key)))
			if key.mesh == null or key.mesh is not BoxMesh \
					or not (key.mesh as BoxMesh).size.is_equal_approx(COCKPIT_CONSOLE_KEY_SIZE):
				errors.append("console-key primitive recipe drift: %s" % key_name)
				continue
			var expected_transform := _cockpit_console_key_transforms().get(key_name) as Transform3D
			if not key.transform.is_equal_approx(expected_transform):
				errors.append("console-key transform drift: %s" % key_name)
			mesh_identities[key.mesh.get_instance_id()] = true
			if not key.visible \
					or key.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
					or key.material_override != _arrow_materials.sensor \
					or key.material_overlay != null \
					or key.layers != 1 \
					or not is_zero_approx(key.transparency):
				errors.append("console-key render-state drift: %s" % key_name)
			if key.get_child_count() != 0 or key.get_script() != null \
					or not key.get_groups().is_empty() or not key.get_meta_list().is_empty():
				errors.append("console-key gained semantic authority: %s" % key_name)
	if keys.size() != COCKPIT_CONSOLE_KEY_SHARED_MESH_ROSTER.size():
		errors.append("console-key visible-copy roster drift")
	if mesh_identities.size() != 1:
		errors.append("console-key shared-mesh identity drift")
	if _cockpit_console_key_mesh == null \
			or _cockpit_console_key_mesh.resource_local_to_scene \
			or _cockpit_console_key_mesh.get_surface_count() != 1:
		errors.append("console-key retained mesh recipe drift")
	for key in keys:
		if key.mesh != _cockpit_console_key_mesh:
			errors.append("console-key retained a private mesh")
			break
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": node_paths,
		"authored_transforms": _cockpit_console_key_transforms(),
		"geometry_nodes": keys.size(),
		"geometry_submissions": keys.size(),
		"visible_geometry_copies": keys.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 3,
		"legacy": {
			"geometry_nodes": 4,
			"geometry_submissions": 4,
			"visible_geometry_copies": 4,
			"primitive_mesh_allocations": 4,
		},
	}.duplicate(true)


func _inspect_engine_collar_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var node_paths := PackedStringArray()
	var mesh_identities := {}
	var authored_transforms := _engine_collar_transforms()
	var expected_transforms := authored_transforms.duplicate()
	var cue := get_engine_damage_collar_snapshot()
	var cue_active := bool(cue.get("active", false))
	if cue_active:
		expected_transforms[ENGINE_DAMAGE_CUE_COLLAR_INDEX] = (
			_engine_damage_collar_transform()
		)
	if _engine_collars.size() != ENGINE_COLLAR_VISIBLE_COPIES:
		errors.append("engine-collar visible-copy roster drift")
	for index in _engine_collars.size():
		var collar := _engine_collars[index]
		if not is_instance_valid(collar) or collar.get_parent() != _arrow_visual:
			errors.append("engine-collar renderer roster drift: %d" % index)
			continue
		var path := str(_arrow_visual.get_path_to(collar))
		node_paths.append(path)
		if index >= expected_transforms.size() \
				or not collar.transform.is_equal_approx(expected_transforms[index]):
			errors.append("engine-collar transform drift: %s" % path)
		if collar.mesh == null:
			errors.append("engine-collar mesh missing: %s" % path)
		else:
			mesh_identities[collar.mesh.get_instance_id()] = true
		var expected_material_override: Material = (
			_shared_engine_damage_collar_material
			if cue_active and index == ENGINE_DAMAGE_CUE_COLLAR_INDEX
			else null
		)
		if not collar.visible \
				or collar.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or collar.material_override != expected_material_override \
				or collar.material_overlay != null \
				or collar.layers != 1 \
				or not is_zero_approx(collar.transparency):
			errors.append("engine-collar render-state drift: %s" % path)
		if collar.get_child_count() != 0 or collar.get_script() != null \
				or not collar.get_groups().is_empty() \
				or not collar.get_meta_list().is_empty():
			errors.append("engine-collar gained semantic authority: %s" % path)
	if node_paths.size() == ENGINE_COLLAR_VISIBLE_COPIES:
		if node_paths[0] != "EngineCollar" \
				or not node_paths[1].begins_with("@MeshInstance3D@"):
			errors.append("engine-collar path roster drift")
	if mesh_identities.size() != 1:
		errors.append("engine-collar shared-mesh identity drift")
	var mesh := _engine_collar_mesh
	var tessellation := Vector2i(mesh.rings, mesh.ring_segments) \
		if mesh != null else Vector2i.ZERO
	var budget_metadata_valid: bool = mesh != null \
		and mesh.get_meta_list() == [StringName(TorusGeometryBudget.AUTHORED_META)] \
		and mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) \
			== ENGINE_COLLAR_AUTHORED_TESSELLATION
	var tessellation_valid: bool = tessellation == ENGINE_COLLAR_AUTHORED_TESSELLATION \
		and mesh != null and mesh.get_meta_list().is_empty()
	tessellation_valid = tessellation_valid or (
		tessellation == ENGINE_COLLAR_BUDGETED_TESSELLATION \
		and budget_metadata_valid
	)
	if mesh == null \
			or not is_equal_approx(mesh.inner_radius, ENGINE_COLLAR_INNER_RADIUS) \
			or not is_equal_approx(mesh.outer_radius, ENGINE_COLLAR_OUTER_RADIUS) \
			or not tessellation_valid \
			or mesh.get_surface_count() != 1:
		errors.append("engine-collar primitive recipe drift")
	elif mesh.material != _arrow_materials.ceramic:
		errors.append("engine-collar material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("engine-collar shared mesh gained instance authority")
	for collar in _engine_collars:
		if is_instance_valid(collar) and collar.mesh != mesh:
			errors.append("engine-collar retained a private mesh")
			break
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": node_paths,
		"authored_transforms": authored_transforms.duplicate(),
		"presented_transforms": expected_transforms.duplicate(),
		"geometry_nodes": _engine_collars.size(),
		"geometry_submissions": _engine_collars.size(),
		"visible_geometry_copies": _engine_collars.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 1,
		"tessellation": tessellation,
		"mesh_metadata": mesh.get_meta_list() if mesh != null else [],
		"damage_cue": cue,
		"legacy": {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
		},
	}.duplicate(true)


func _inspect_main_gear_foot_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var node_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _main_gear_foot_transforms()
	if _main_gear_feet.size() != MAIN_GEAR_FOOT_VISIBLE_COPIES:
		errors.append("main-gear-foot visible-copy roster drift")
	for index in _main_gear_feet.size():
		var foot := _main_gear_feet[index]
		if not is_instance_valid(foot) or foot.get_parent() != _arrow_visual:
			errors.append("main-gear-foot renderer roster drift: %d" % index)
			continue
		var path := str(_arrow_visual.get_path_to(foot))
		node_paths.append(path)
		if index >= expected_transforms.size() \
				or not foot.transform.is_equal_approx(expected_transforms[index]):
			errors.append("main-gear-foot transform drift: %s" % path)
		if foot.mesh == null:
			errors.append("main-gear-foot mesh missing: %s" % path)
		else:
			mesh_identities[foot.mesh.get_instance_id()] = true
		if not foot.visible \
				or foot.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or foot.material_override != null \
				or foot.material_overlay != null \
				or foot.layers != 1 \
				or not is_zero_approx(foot.transparency):
			errors.append("main-gear-foot render-state drift: %s" % path)
		if foot.get_child_count() != 0 or foot.get_script() != null \
				or not foot.get_groups().is_empty() \
				or not foot.get_meta_list().is_empty() \
				or not foot.find_children(
					"*", "CollisionObject3D", true, false
				).is_empty():
			errors.append("main-gear-foot gained semantic authority: %s" % path)
	if node_paths.size() == MAIN_GEAR_FOOT_VISIBLE_COPIES:
		if node_paths[0] != "MainGearFoot" \
				or not node_paths[1].begins_with("@MeshInstance3D@"):
			errors.append("main-gear-foot path roster drift")
	if mesh_identities.size() != 1:
		errors.append("main-gear-foot shared-mesh identity drift")
	var mesh := _main_gear_foot_mesh
	if mesh == null \
			or not is_equal_approx(mesh.inner_radius, MAIN_GEAR_FOOT_INNER_RADIUS) \
			or not is_equal_approx(mesh.outer_radius, MAIN_GEAR_FOOT_OUTER_RADIUS) \
			or mesh.get_surface_count() != 1:
		errors.append("main-gear-foot primitive recipe drift")
	elif mesh.material != _arrow_materials.titanium:
		errors.append("main-gear-foot material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("main-gear-foot shared mesh gained instance authority")
	for foot in _main_gear_feet:
		if is_instance_valid(foot) and foot.mesh != mesh:
			errors.append("main-gear-foot retained a private mesh")
			break
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": node_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": _main_gear_feet.size(),
		"geometry_submissions": _main_gear_feet.size(),
		"visible_geometry_copies": _main_gear_feet.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 1,
		"legacy": {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
		},
	}.duplicate(true)


func _inspect_pod_separation_collar_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var node_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transform := Transform3D(
		Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)) \
			* Basis.from_scale(POD_SEPARATION_COLLAR_SCALE),
		Vector3.ZERO
	)
	if _pod_separation_collars.size() != POD_SEPARATION_COLLAR_VISIBLE_COPIES:
		errors.append("pod-separation-collar visible-copy roster drift")
	for index in _pod_separation_collars.size():
		var collar := _pod_separation_collars[index]
		var expected_parent := _escape_pods[index] \
			if index < _escape_pods.size() else null
		if not is_instance_valid(collar) or collar.get_parent() != expected_parent:
			errors.append("pod-separation-collar renderer roster drift: %d" % index)
			continue
		var path := str(_arrow_visual.get_path_to(collar))
		node_paths.append(path)
		if not collar.transform.is_equal_approx(expected_transform):
			errors.append("pod-separation-collar transform drift: %s" % path)
		if collar.mesh == null:
			errors.append("pod-separation-collar mesh missing: %s" % path)
		else:
			mesh_identities[collar.mesh.get_instance_id()] = true
		if not collar.visible \
				or collar.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or collar.material_override != null \
				or collar.material_overlay != null \
				or collar.layers != 1 \
				or not is_zero_approx(collar.transparency):
			errors.append("pod-separation-collar render-state drift: %s" % path)
		if collar.get_child_count() != 0 or collar.get_script() != null \
				or not collar.get_groups().is_empty() \
				or not collar.get_meta_list().is_empty() \
				or not collar.find_children(
					"*", "CollisionObject3D", true, false
				).is_empty():
			errors.append("pod-separation-collar gained semantic authority: %s" % path)
	var expected_paths := PackedStringArray([
		"PortEscapePod/PodSeparationCollar",
		"StarboardEscapePod/PodSeparationCollar",
	])
	if node_paths != expected_paths:
		errors.append("pod-separation-collar path roster drift")
	if mesh_identities.size() != 1:
		errors.append("pod-separation-collar shared-mesh identity drift")
	var mesh := _pod_separation_collar_mesh
	var tessellation := Vector2i(mesh.rings, mesh.ring_segments) \
		if mesh != null else Vector2i.ZERO
	var budget_metadata_valid: bool = mesh != null \
		and mesh.get_meta_list() == [StringName(TorusGeometryBudget.AUTHORED_META)] \
		and mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) \
			== POD_SEPARATION_COLLAR_AUTHORED_TESSELLATION
	var tessellation_valid: bool = (
		tessellation == POD_SEPARATION_COLLAR_AUTHORED_TESSELLATION
		and mesh != null and mesh.get_meta_list().is_empty()
	)
	tessellation_valid = tessellation_valid or (
		tessellation == POD_SEPARATION_COLLAR_BUDGETED_TESSELLATION
		and budget_metadata_valid
	)
	if mesh == null \
			or not is_equal_approx(
				mesh.inner_radius, POD_SEPARATION_COLLAR_INNER_RADIUS
			) \
			or not is_equal_approx(
				mesh.outer_radius, POD_SEPARATION_COLLAR_OUTER_RADIUS
			) \
			or not tessellation_valid \
			or mesh.get_surface_count() != 1:
		errors.append("pod-separation-collar primitive recipe drift")
	elif mesh.material != _arrow_materials.graphite:
		errors.append("pod-separation-collar material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("pod-separation-collar shared mesh gained instance authority")
	for collar in _pod_separation_collars:
		if is_instance_valid(collar) and collar.mesh != mesh:
			errors.append("pod-separation-collar retained a private mesh")
			break
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": node_paths,
		"authored_local_transform": expected_transform,
		"geometry_nodes": _pod_separation_collars.size(),
		"geometry_submissions": _pod_separation_collars.size(),
		"visible_geometry_copies": _pod_separation_collars.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 1,
		"tessellation": tessellation,
		"mesh_metadata": mesh.get_meta_list() if mesh != null else [],
		"legacy": {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
		},
	}.duplicate(true)


static func _engine_collar_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		transforms.append(Transform3D(
			Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)),
			Vector3(side * 0.92, 0.94, 6.48)
		))
	return transforms


static func _engine_damage_collar_transform() -> Transform3D:
	return Transform3D(
		Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)) \
			* Basis.from_scale(ENGINE_DAMAGE_COLLAR_SCALE),
		ENGINE_DAMAGE_COLLAR_POSITION
	)


static func _main_gear_foot_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		transforms.append(Transform3D(
			Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)) \
				* Basis.from_scale(MAIN_GEAR_FOOT_SCALE),
			Vector3(side * 1.7, -0.64, 2.25)
		))
	return transforms


func _cockpit_console_key_transforms() -> Dictionary:
	return {
		"PortConsoleKey00": Transform3D(Basis.IDENTITY, Vector3(-0.76, 2.41, -0.88)),
		"PortConsoleKey02": Transform3D(Basis.IDENTITY, Vector3(-0.67, 2.41, -0.24)),
		"StarboardConsoleKey00": Transform3D(Basis.IDENTITY, Vector3(0.76, 2.41, -0.88)),
		"StarboardConsoleKey02": Transform3D(Basis.IDENTITY, Vector3(0.85, 2.41, -0.24)),
	}


func _torus(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	inner_radius: float,
	outer_radius: float,
	material: Material,
	rotation_degrees_value := Vector3.ZERO,
	scale_value := Vector3.ONE,
	shared_mesh: TorusMesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	instance.scale = scale_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = TorusMesh.new()
		mesh.inner_radius = inner_radius
		mesh.outer_radius = outer_radius
		mesh.rings = 64
		mesh.ring_segments = 18
		mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


## The survey electronics have two removable dorsal lids, with a continuous
## recessed gasket and flush quarter-turn latch lands. Sample the actual formed
## hull triangles: these skins sit in its opening, rather than floating above
## the nose as boxes or straight strips. All fittings reuse fleet materials.
func _fit_nose_survey_service_bay() -> void:
	var shell := _arrow_visual.get_node("ReconFuselage") as MeshInstance3D
	var arrays := shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var stations := int(shell.get_meta("loft_section_count"))
	var grid := {}
	for index in vertices.size():
		var station := roundi(uvs[index].y * float(stations - 1))
		var ring := roundi(uvs[index].x * 32.0)
		if vertices[index].y > 0.0:
			grid[Vector2i(station, ring)] = vertices[index]
	_cut_pressure_panel(shell, "SurveyServiceGasket", 5, 12, 5, 11, _arrow_materials.graphite)
	var covers := SurfaceTool.new()
	covers.begin(Mesh.PRIMITIVE_TRIANGLES)
	covers.set_material(_arrow_materials.ceramic)
	var latches := SurfaceTool.new()
	latches.begin(Mesh.PRIMITIVE_TRIANGLES)
	latches.set_material(_arrow_materials.titanium)
	for span: Vector2 in [Vector2(5.12, 8.85), Vector2(9.05, 11.88)]:
		_nose_surface_patch(covers, grid, span, Vector2(5.15, 10.85), -0.008, 0.037)
		for station in [span.x + 0.32, span.y - 0.32]:
			for ring in [5.7, 10.3]:
				_nose_surface_patch(latches, grid, Vector2(station - 0.10, station + 0.10), Vector2(ring - 0.16, ring + 0.16), -0.003)
	for spec: Array in [["SurveyServiceCovers", covers], ["SurveyServiceLatches", latches]]:
		var tool := spec[1] as SurfaceTool
		tool.generate_normals()
		tool.index()
		tool.generate_tangents()
		var fitting := MeshInstance3D.new()
		fitting.name = spec[0]
		fitting.mesh = tool.commit()
		shell.add_child(fitting)


## Sample vertices on the original hull triangles, subdividing at their cells.
## Narrow border cells approximate the contour between samples; their small
## triangulation difference fits within the recessed gasket clearance.
func _nose_surface_patch(tool: SurfaceTool, grid: Dictionary, span: Vector2, rings: Vector2, inset: float, edge_depth := 0.0) -> void:
	var station_samples: Array[float] = [span.x]
	for station in range(ceili(span.x), ceili(span.y)):
		station_samples.append(float(station))
	station_samples.append(span.y)
	var ring_samples: Array[float] = [rings.x]
	for ring in range(ceili(rings.x), ceili(rings.y)):
		ring_samples.append(float(ring))
	ring_samples.append(rings.y)
	for station in station_samples.size() - 1:
		for ring in ring_samples.size() - 1:
			var quad := PackedVector3Array()
			for uv: Vector2 in [Vector2(station_samples[station], ring_samples[ring]), Vector2(station_samples[station + 1], ring_samples[ring]), Vector2(station_samples[station + 1], ring_samples[ring + 1]), Vector2(station_samples[station], ring_samples[ring + 1])]:
				var cell := Vector2i(floori(uv.x), floori(uv.y))
				var fraction := uv - Vector2(cell)
				var a: Vector3 = grid[cell]
				var b: Vector3 = grid[cell + Vector2i(1, 0)]
				var c: Vector3 = grid[cell + Vector2i(1, 1)]
				var d: Vector3 = grid[cell + Vector2i(0, 1)]
				var point := a + (b - a) * fraction.x + (c - b) * fraction.y if fraction.x >= fraction.y else a + (c - d) * fraction.x + (d - a) * fraction.y
				point += Vector3(point.x, point.y, 0).normalized() * inset
				quad.append(point)
			tool.set_smooth_group(0)
			for corner in [0, 1, 2, 0, 2, 3]:
				tool.set_uv(Vector2(quad[corner].x, quad[corner].z))
				tool.add_vertex(quad[corner])
			if edge_depth > 0.0:
				tool.set_smooth_group(-1)
				var boundaries := [ring == 0, station == station_samples.size() - 2, ring == ring_samples.size() - 2, station == 0]
				for edge in 4:
					if not boundaries[edge]:
						continue
					var a := quad[edge]
					var b := quad[(edge + 1) % 4]
					var lower_a := a - Vector3(a.x, a.y, 0).normalized() * edge_depth
					var lower_b := b - Vector3(b.x, b.y, 0).normalized() * edge_depth
					for point in [a, lower_a, lower_b, a, lower_b, b]:
						tool.set_uv(Vector2(point.x, point.z))
						tool.add_vertex(point)


## Cut a bounded grid patch out of a loft and recess its replacement surface.
## The exposed edge is a real sidewall; access panels follow hull curvature.
func _cut_pressure_panel(shell: MeshInstance3D, panel_name: String, first_section: int, last_section: int, first_ring: int, last_ring: int, material: Material) -> void:
	var arrays := shell.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var section_count := int(shell.get_meta("loft_section_count"))
	# Hard plate edges duplicate vertices with different face normals. Use one
	# radial inset direction per position so each access skin stays watertight
	# across those duplicates instead of opening tiny sawtooth cracks.
	for vertex_index in vertices.size():
		normals[vertex_index] = Vector3(vertices[vertex_index].x, vertices[vertex_index].y, 0.0).normalized()
	var logical_vertices := {}
	for vertex_index in vertices.size():
		if absf(vertices[vertex_index].x) + absf(vertices[vertex_index].y) < 0.001:
			continue
		var section := roundi(uvs[vertex_index].y * float(section_count - 1))
		var ring := roundi(uvs[vertex_index].x * 32.0)
		logical_vertices[section * 32 + ring] = vertex_index
	var retained := PackedInt32Array()
	var patch := SurfaceTool.new()
	patch.begin(Mesh.PRIMITIVE_TRIANGLES)
	patch.set_material(material)
	for triangle in range(0, indices.size(), 3):
		var belongs := true
		for corner in 3:
			var vertex_index := indices[triangle + corner]
			var section := roundi(uvs[vertex_index].y * float(section_count - 1))
			var ring := roundi(uvs[vertex_index].x * 32.0)
			belongs = belongs and section >= first_section and section <= last_section and ring >= first_ring and ring <= last_ring
		if belongs:
			for corner in 3:
				var vertex_index := indices[triangle + corner]
				patch.set_uv(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
				patch.add_vertex(vertices[vertex_index] - normals[vertex_index] * 0.045)
		else:
			for corner in 3:
				retained.append(indices[triangle + corner])
	var boundary := PackedInt32Array()
	for section in range(first_section, last_section): boundary.append(section * 32 + first_ring)
	for ring in range(first_ring, last_ring): boundary.append(last_section * 32 + ring)
	for section in range(last_section, first_section, -1): boundary.append(section * 32 + last_ring)
	for ring in range(last_ring, first_ring, -1): boundary.append(first_section * 32 + ring)
	for edge in boundary.size():
		var a := int(logical_vertices[boundary[edge]])
		var b := int(logical_vertices[boundary[(edge + 1) % boundary.size()]])
		for point in [vertices[a], vertices[b], vertices[b] - normals[b] * 0.045, vertices[a], vertices[b] - normals[b] * 0.045, vertices[a] - normals[a] * 0.045]:
			patch.set_uv(Vector2(point.x, point.z))
			patch.add_vertex(point)
	arrays[Mesh.ARRAY_INDEX] = retained
	var replacement := ArrayMesh.new()
	replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	replacement.surface_set_material(0, shell.mesh.surface_get_material(0))
	shell.mesh = replacement
	patch.generate_normals()
	var insert := MeshInstance3D.new()
	insert.name = panel_name
	insert.mesh = patch.commit()
	shell.add_child(insert)


## Slim pressure-frame arches are fitted to the actual laminated shell rather
## than suspended as straight rails above its curved roof.
func _fit_canopy_frame(glazing: MeshInstance3D, section: int, material: Material) -> void:
	var arrays := glazing.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var sections := int(glazing.get_meta("loft_section_count"))
	var arch := {}
	for vertex_index in vertices.size():
		if roundi(uvs[vertex_index].y * float(sections - 1)) == section:
			arch[roundi(uvs[vertex_index].x * 32.0)] = vertex_index
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for ring in 16:
		var a := int(arch[ring])
		var b := int(arch[ring + 1])
		var pa := vertices[a] + normals[a] * 0.018
		var pb := vertices[b] + normals[b] * 0.018
		for point in [pa + Vector3.FORWARD * 0.033, pb + Vector3.BACK * 0.033, pb + Vector3.FORWARD * 0.033, pa + Vector3.FORWARD * 0.033, pa + Vector3.BACK * 0.033, pb + Vector3.BACK * 0.033]:
			tool.set_uv(Vector2(point.x, point.z))
			tool.add_vertex(point)
	tool.generate_normals()
	var frame := MeshInstance3D.new()
	frame.name = "PressureFrame%02d" % section
	frame.mesh = tool.commit()
	frame.layers = glazing.layers
	glazing.add_child(frame)
