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
const SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS := 0.105
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
const FUSELAGE_PANEL_BAND_SIZE := Vector3(2.0, 0.045, 0.11)
const FUSELAGE_PANEL_BAND_HEIGHT := 1.84
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
	"nodes": 189,
	"mesh_instance_nodes": 164,
	"multi_mesh_instance_nodes": 3,
	"geometry_submissions": 167,
	"visible_geometry_copies": 171,
	"unique_mesh_resource_allocations": 123,
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

	_create_arrow_materials()
	_build_slender_airframe()
	_build_recon_systems()
	_build_recon_pulse_emitters()
	_build_escape_pods()
	_build_engines_and_landing_gear()
	_restyle_inherited_cockpit(cockpit, canopy)
	_share_inherited_console_key_meshes(cockpit)
	_replace_collision_and_markers()
	if not replace_variant_visual_root(_arrow_visual):
		return false
	return true


func _create_arrow_materials() -> void:
	# The `pearl`/`ceramic` material-family keys are the craft's stable public
	# material API and are left alone; only the tints they carry changed.
	_arrow_materials.pearl = _material(HULL_SLATE, 0.18, 0.28)
	_arrow_materials.ceramic = _material(HULL_SLATE_SHADE, 0.12, 0.36)
	# Secondary structure carries a deliberately wide material response. Before
	# this pass titanium/graphite/pod sat at roughness 0.34/0.30/0.42 and
	# metallic 0.58/0.64/0.20 — three surfaces a player could only tell apart by
	# hue. They are now bare machined alloy, matte painted composite, and a
	# painted survival-orange shell, which is three different behaviours under
	# the same light. Colours are untouched; see the palette note above.
	_arrow_materials.titanium = _material(TITANIUM, 0.72, 0.24)
	_arrow_materials.graphite = _material(GRAPHITE, 0.30, 0.68)
	_arrow_materials.sensor = _material(SENSOR_CYAN, 0.18, 0.22, SENSOR_CYAN, 1.7)
	_arrow_materials.pod = _material(POD_ORANGE, 0.10, 0.58)
	_arrow_materials.engine = _material(ENGINE_CYAN, 0.1, 0.16, ENGINE_CYAN, 3.0)
	_arrow_materials.nav_red = _material(ARROW_NAV_RED, 0.1, 0.2, ARROW_NAV_RED, 2.2)
	_arrow_materials.nav_green = _material(ARROW_NAV_GREEN, 0.1, 0.2, ARROW_NAV_GREEN, 2.2)
	_arrow_materials.glass = _transparent_material(Color(0.3, 0.68, 0.7, 0.09), 0.04, 0.08)
	var hull_albedo := load("res://assets/materials/arrow-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/arrow-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/arrow-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_arrow_materials.pearl, _arrow_materials.ceramic]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.62
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# Triplanar projection keeps the generated aerospace panel treatment stable
		# across the procedural loft and avoids stretched seams at its ring caps.
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.0
		hull_material.uv1_scale = Vector3(0.34, 0.34, 0.34)
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.48
		hull_material.clearcoat_roughness = 0.2
	# Nacelles, wing-root ribs, wingtip pods, the sensor gimbal, the fuselage
	# panel bands, gear feet and the mast pedestal all shared one flat slab of
	# `TITANIUM` with no map of any kind: the aft crop of the baseline capture
	# shows the engine housing as a single uniform grey cylinder. The registered
	# Arrow normal map that already dresses the hull is reused here through
	# triplanar projection at 5-10x the hull's frequency: the hull tiles about
	# once every three metres, and a 0.3 m strut or a 0.4 m collar at that rate
	# receives a fraction of one feature and cannot show relief at all.
	# Measured honestly, this relief is a small contribution under the current
	# station lighting — a rendered A/B at an absurd normal_scale of 12.0 moved
	# under 1% of a berth frame — so the widened metallic/roughness response
	# above is what carries this pass. The relief is kept because it costs
	# nothing and will pay off if the lighting gains contrast. No albedo texture
	# is bound, so the fleet colour floors see exactly the tints above.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.titanium, hull_normal, 3.5, 1.20)
	# Struts, keel, mast stem and pod collars are painted composite, not bare
	# metal, so they take the matte end of the craft's roughness range while
	# titanium takes the glossy end.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.graphite, hull_normal, 3.0, 1.10)
	# The escape pods were the single most primitive-looking object on the
	# craft: a saturated flat orange blob beside a textured fuselage. A coarser
	# projection than the hardware gives them shell seams at pod scale.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.pod, hull_normal, 1.6, 1.30)


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
	# A narrow 32-section elliptical fuselage, not the Torrent's broad delta.
	_loft_hull(
		_arrow_visual,
		"ReconFuselage",
		Vector3(0, 1.22, -0.45),
		PackedVector3Array([
			Vector3(0.18, 0.12, -7.2),
			Vector3(0.72, 0.46, -6.15),
			Vector3(1.28, 0.72, -3.7),
			Vector3(1.5, 0.86, -0.7),
			Vector3(1.62, 0.82, 2.6),
			Vector3(1.25, 0.7, 5.2),
			Vector3(0.84, 0.55, 6.3),
		]),
		_arrow_materials.pearl
	)
	_loft_hull(
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
	)

	# Long swept sensor wings use curved planform lofts and inset titanium roots.
	var wing_root_rib_transforms: Array[Transform3D] = []
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var wing := _build_planform_surface(
			"PortSensorWing" if side_index == 0 else "StarboardSensorWing",
			PackedVector3Array([
				Vector3(side * 0.9, 1.05, -1.6),
				Vector3(side * 5.35, 0.92, 0.75),
				Vector3(side * 5.75, 0.86, 3.65),
				Vector3(side * 1.15, 0.98, 2.8),
			]),
			0.18,
			_arrow_materials.ceramic
		)
		_arrow_visual.add_child(wing)
		wing_root_rib_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0, side * -0.08, 0)),
			Vector3(side * 1.45, 1.03, 1.0)
		))
		_curve_tube(
			_arrow_visual,
			"SensorLeadingEdge",
			PackedVector3Array([
				Vector3(side * 1.0, 1.19, -1.65),
				Vector3(side * 3.4, 1.1, -0.55),
				Vector3(side * 5.35, 1.02, 0.75),
			]),
			SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS,
			_arrow_materials.sensor,
			_sensor_leading_edge_curve_joint_mesh
		)
		_loft_hull(
			_arrow_visual,
			"WingtipSensorPod",
			Vector3(side * 5.55, 1.0, 2.45),
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.85),
				Vector3(0.33, 0.24, -1.25),
				Vector3(0.42, 0.28, 0.65),
				Vector3(0.18, 0.14, 1.75),
			]),
			_arrow_materials.titanium
		)
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
	_loft_hull(
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
	)
	_curve_tube(
		_arrow_visual,
		"DorsalDataConduit",
		PackedVector3Array([
			Vector3(0, 2.52, -0.6),
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


func _build_recon_systems() -> void:
	var mast := Node3D.new()
	mast.name = "ReconSensorMast"
	mast.position = Vector3(0, 2.5, 3.55)
	mast.set_meta("provisional_sensor_system", true)
	_arrow_visual.add_child(mast)
	_cylinder(mast, "MastPedestal", Vector3(0, 0.45, 0), 0.16, 0.9, _arrow_materials.titanium)
	_cylinder(mast, "MastStem", Vector3(0, 1.15, 0), 0.08, 0.72, _arrow_materials.graphite)
	_sensor_sweep = Node3D.new()
	_sensor_sweep.name = "SensorSweep"
	_sensor_sweep.position = Vector3(0, 1.48, 0)
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
		_loft_hull(
			pod,
			"PodPressureShell",
			Vector3.ZERO,
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.45),
				Vector3(0.52, 0.42, -0.82),
				Vector3(0.58, 0.47, 0.72),
				Vector3(0.24, 0.18, 1.32),
			]),
			_arrow_materials.pod
		)
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
		_box(pod, "PodIdentityStripe", Vector3(side * 0.48, 0.02, -0.05), Vector3(0.06, 0.22, 1.55), _arrow_materials.sensor)
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
		_loft_hull(
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
		)
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


func _restyle_inherited_cockpit(cockpit: Node3D, canopy: Node3D) -> void:
	if cockpit != null:
		# Darker interior preserves high contrast behind the unusually clear canopy.
		for node in cockpit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if "Display" in mesh_instance.name or "ConsoleKey" in mesh_instance.name:
				mesh_instance.material_override = _arrow_materials.sensor
	if canopy != null:
		var glass := canopy.get_node_or_null("CanopyGlass") as MeshInstance3D
		if glass != null:
			glass.material_override = _arrow_materials.glass
			# Retain the inherited physical canopy envelope. Enlarging the shell
			# independently of its private camera/hinge geometry creates a cyan first-
			# person wash and overstates the high-visibility canopy from outside.
			glass.scale = Vector3.ONE
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _arrow_materials.graphite
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _arrow_materials.ceramic


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
		plume.scale.z = lerpf(
			plume.scale.z,
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
			plume.scale.z = 0.42 + engine_level * 1.3 * exhaust_geometry if active else 0.42
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
	var visible_geometry_copies := mesh_instances.size()
	var geometry_submissions := 0
	for candidate in mesh_instances:
		var instance := candidate as MeshInstance3D
		if instance.mesh != null:
			geometry_submissions += instance.mesh.get_surface_count()
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
		Transform3D(Basis.IDENTITY, Vector3(-1.0, 1.19, -1.65)),
		Transform3D(Basis.IDENTITY, Vector3(-3.4, 1.1, -0.55)),
		Transform3D(Basis.IDENTITY, Vector3(-5.35, 1.02, 0.75)),
		Transform3D(Basis.IDENTITY, Vector3(1.0, 1.19, -1.65)),
		Transform3D(Basis.IDENTITY, Vector3(3.4, 1.1, -0.55)),
		Transform3D(Basis.IDENTITY, Vector3(5.35, 1.02, 0.75)),
	]


static func _dorsal_data_conduit_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.52, -0.6)),
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


func _loft_hull(parent: Node3D, node_name: String, origin: Vector3, sections: PackedVector3Array, material: Material) -> MeshInstance3D:
	const RING_COUNT := 20
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in RING_COUNT:
			var angle := TAU * float(ring_index) / float(RING_COUNT)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.72)
			var rounded_y := signf(sine) * pow(absf(sine), 0.72)
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
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	instance.set_meta("closed_loft_hull", true)
	parent.add_child(instance)
	return instance


func _build_planform_surface(node_name: String, outline: PackedVector3Array, thickness: float, material: Material) -> MeshInstance3D:
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
		var top_a := index
		var top_b := next
		var bottom_a := outline.size() + index
		var bottom_b := outline.size() + next
		tool.add_index(top_a)
		tool.add_index(bottom_a)
		tool.add_index(bottom_b)
		tool.add_index(top_a)
		tool.add_index(bottom_b)
		tool.add_index(top_b)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	return instance


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
