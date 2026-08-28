class_name AftJunctionStack
extends Node3D

## Source-bounded, reusable interpretation of an aft station junction.
##
## Surviving material supports an exposed grey lattice, compact windowed rooms,
## short vertical circulation, and cyan/red access landmarks. It does not prove
## this module's exact plan, dimensions, furniture, adjacency, or name. Those
## details are deliberately identified as modern interpretation in the public
## evidence report rather than being presented as recovered original geometry.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"aft-junction-stack"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Declared station connection slot. `ShipyardWorld` publishes the matching hub
## endpoint; the pair is what `StationRouteRegistry` records as one graph edge.
const HUB_CONNECTION_SLOT: StringName = &"hub-aft-junction"
const WORLD_LAYER := PhysicsLayers.WORLD
const ShipServiceConsoleType := preload(
	"res://scripts/interaction/ship_service_console.gd"
)

## Distance fade applied to every fixture practical in this module. Measured
## rather than chosen — see `_fixture_practical`. A fade that ended at 24 m ended
## inside the subject and switched the whole pass off in every framing but the
## two interiors; this ends at 85 m, past the station, and still spares the
## 140 m-plus lattice overview.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0
## Authored room-local colour separation. This is deliberately a static
## practical hue, not a cue colour or an exposure/glow adjustment.
const OPERATIONS_WARM_COVE_COLOR := Color("ffb56b")
const INTERFACE_COLLAR_KIND_META := "aft_interface_collar_kind"

## The first repeated childless visual family not already served by the rounded
## box/chamfered-cylinder caches or the independently profiled interface collars.
## Four named renderer nodes and four submissions remain; only their exact
## TorusMesh recipe becomes one module-owned resource treated as immutable.
const POD_CORNER_COLLAR_INNER_RADIUS := 0.25
const POD_CORNER_COLLAR_OUTER_RADIUS := 0.34
const POD_CORNER_COLLAR_RINGS := 48
const POD_CORNER_COLLAR_RING_SEGMENTS := 16
const POD_CORNER_COLLAR_BUDGETED_RINGS := 34
const POD_CORNER_COLLAR_BUDGETED_RING_SEGMENTS := 14
const POD_CORNER_COLLAR_COPY_COUNT := 4
const POD_CORNER_COLLAR_FAMILY_META := "aft_visual_resource_family"
const POD_CORNER_COLLAR_FAMILY_ID: StringName = &"pod_corner_collars"
const POD_CORNER_COLLAR_POSITIONS := [
	Vector3(0.4, 4.45, 9.18),
	Vector3(10.8, 4.45, 9.18),
	Vector3(0.4, 4.45, 17.24),
	Vector3(10.8, 4.45, 17.24),
]
## Four identical brass rings at the feet and crowns of the two VIP facade
## columns. They are childless presentation trim: the adjacent columns carry
## the visible structure, and the independent StationDoor/evidence hierarchy
## carries all interaction and provenance authority.
const VIP_FACADE_COLUMN_TRIM_INNER_RADIUS := 0.19
const VIP_FACADE_COLUMN_TRIM_OUTER_RADIUS := 0.28
const VIP_FACADE_COLUMN_TRIM_RINGS := 48
const VIP_FACADE_COLUMN_TRIM_RING_SEGMENTS := 16
const VIP_FACADE_COLUMN_TRIM_BUDGETED_RINGS := 32
const VIP_FACADE_COLUMN_TRIM_BUDGETED_RING_SEGMENTS := 14
const VIP_FACADE_COLUMN_TRIM_COPY_COUNT := 4
const VIP_FACADE_COLUMN_TRIM_TRANSFORMS := [
	Transform3D(Basis.IDENTITY, Vector3(-9.0, 4.43, 20.02)),
	Transform3D(Basis.IDENTITY, Vector3(-9.0, 8.07, 20.02)),
	Transform3D(Basis.IDENTITY, Vector3(-1.3, 4.43, 20.02)),
	Transform3D(Basis.IDENTITY, Vector3(-1.3, 8.07, 20.02)),
]
## Five copper clamps around the existing operations-room roof spine. The spine
## remains the structural/semantic object and all five ordinary renderer nodes
## remain addressable; only their identical immutable TorusMesh is shared.
const SPINE_CLAMP_INNER_RADIUS := 0.16
const SPINE_CLAMP_OUTER_RADIUS := 0.225
const SPINE_CLAMP_RINGS := 48
const SPINE_CLAMP_RING_SEGMENTS := 16
const SPINE_CLAMP_BUDGETED_RINGS := 32
const SPINE_CLAMP_BUDGETED_RING_SEGMENTS := 8
const SPINE_CLAMP_COPY_COUNT := 5
const SPINE_CLAMP_POSITIONS := [
	Vector3(5.6, 5.62, 9.55),
	Vector3(5.6, 5.62, 11.4),
	Vector3(5.6, 5.62, 13.25),
	Vector3(5.6, 5.62, 15.1),
	Vector3(5.6, 5.62, 16.95),
]
## Four brass clamps around the existing watch-rack cable tray. The tray keeps
## all structural and content meaning and the ordinary clamp nodes stay in
## place; their identical TorusMesh recipe is the only shared allocation.
const RACK_CABLE_TRAY_CLAMP_INNER_RADIUS := 0.09
const RACK_CABLE_TRAY_CLAMP_OUTER_RADIUS := 0.135
const RACK_CABLE_TRAY_CLAMP_RINGS := 48
const RACK_CABLE_TRAY_CLAMP_RING_SEGMENTS := 16
const RACK_CABLE_TRAY_CLAMP_BUDGETED_RINGS := 32
const RACK_CABLE_TRAY_CLAMP_BUDGETED_RING_SEGMENTS := 8
const RACK_CABLE_TRAY_CLAMP_COPY_COUNT := 4
const RACK_CABLE_TRAY_CLAMP_POSITIONS := [
	Vector3(4.35, 2.44, 9.58),
	Vector3(6.05, 2.44, 9.58),
	Vector3(7.75, 2.44, 9.58),
	Vector3(9.45, 2.44, 9.58),
]
## Six rubber isolation collars around the three console bays' existing copper
## shock mounts. Childless Marker3D anchors retain every bay-local path and pose;
## one room-local MultiMesh draws the exact torus copies. Mounts and bays retain
## all collision, interaction and semantic authority.
const CONSOLE_SHOCK_COLLAR_INNER_RADIUS := 0.09
const CONSOLE_SHOCK_COLLAR_OUTER_RADIUS := 0.13
const CONSOLE_SHOCK_COLLAR_RINGS := 48
const CONSOLE_SHOCK_COLLAR_RING_SEGMENTS := 16
const CONSOLE_SHOCK_COLLAR_BUDGETED_RINGS := 32
const CONSOLE_SHOCK_COLLAR_BUDGETED_RING_SEGMENTS := 8
const CONSOLE_SHOCK_COLLAR_COPY_COUNT := 6
const CONSOLE_SHOCK_COLLAR_LOCAL_POSITIONS := [
	Vector3(-0.86, 0.08, 0.34),
	Vector3(0.86, 0.08, 0.34),
	Vector3(-0.86, 0.08, 0.34),
	Vector3(0.86, 0.08, 0.34),
	Vector3(-0.86, 0.08, 0.34),
	Vector3(0.86, 0.08, 0.34),
]
## Four copper visual bearings wrapped around the operations chairs' existing
## collision-backed pedestal bodies. Every chair, pedestal and bearing node
## remains ordinary and separately addressable; only the exact TorusMesh recipe
## becomes one component-local immutable allocation.
const PEDESTAL_BEARING_INNER_RADIUS := 0.18
const PEDESTAL_BEARING_OUTER_RADIUS := 0.25
const PEDESTAL_BEARING_RINGS := 48
const PEDESTAL_BEARING_RING_SEGMENTS := 16
const PEDESTAL_BEARING_BUDGETED_RINGS := 32
const PEDESTAL_BEARING_BUDGETED_RING_SEGMENTS := 8
const PEDESTAL_BEARING_COPY_COUNT := 4
const PEDESTAL_BEARING_LOCAL_POSITION := Vector3(0.0, 0.68, 0.0)
## Three brass visual collars around the service wall's existing conduit
## renderers. The childless collar nodes and their exact presentation stay in
## place; only their identical TorusMesh recipe becomes one component-local
## immutable allocation. Neither collar nor conduit owns collision or gameplay.
const CONDUIT_COLLAR_INNER_RADIUS := 0.1
const CONDUIT_COLLAR_OUTER_RADIUS := 0.16
const CONDUIT_COLLAR_RINGS := 48
const CONDUIT_COLLAR_RING_SEGMENTS := 16
const CONDUIT_COLLAR_BUDGETED_RINGS := 32
const CONDUIT_COLLAR_BUDGETED_RING_SEGMENTS := 8
const CONDUIT_COLLAR_COPY_COUNT := 3
const CONDUIT_COLLAR_POSITIONS := [
	Vector3(-0.55, 2.95, -2.05),
	Vector3(-0.55, 2.95, 0.0),
	Vector3(-0.55, 2.95, 2.05),
]
const EXTERIOR_PIPE_CLAMP_INNER_RADIUS := 0.065
const EXTERIOR_PIPE_CLAMP_OUTER_RADIUS := 0.1
const EXTERIOR_PIPE_CLAMP_RINGS := 48
const EXTERIOR_PIPE_CLAMP_RING_SEGMENTS := 16
const EXTERIOR_PIPE_CLAMP_COPY_COUNT := 4
const EXTERIOR_PIPE_CLAMP_POSITIONS := [
	Vector3(11.18, 0.82, 10.2),
	Vector3(11.18, 0.82, 12.2),
	Vector3(11.18, 0.82, 14.2),
	Vector3(11.18, 0.82, 16.2),
]
## Two childless roof-vent collars retain their authored visual nodes and one
## surface each; only their identical immutable TorusMesh allocation is shared.
const ROOF_VENT_COLLAR_INNER_RADIUS := 0.34
const ROOF_VENT_COLLAR_OUTER_RADIUS := 0.46
const ROOF_VENT_COLLAR_RINGS := 48
const ROOF_VENT_COLLAR_RING_SEGMENTS := 16
const ROOF_VENT_COLLAR_BUDGETED_RINGS := 40
const ROOF_VENT_COLLAR_BUDGETED_RING_SEGMENTS := 16
const ROOF_VENT_COLLAR_COPY_COUNT := 2
const ROOF_VENT_COLLAR_POSITIONS := [Vector3(3.05, 5.31, 13.0), Vector3(8.1, 5.31, 13.0)]
const ROOF_VENT_COLLAR_FAMILY_META: StringName = &"aft_roof_vent_collar_family"
const ROOF_VENT_COLLAR_FAMILY_ID: StringName = &"roof_vent_collars"
## Fourteen presentation-only insert cards fill the two open cages in the
## isolated watch rack. Their names remain childless Marker3D anchors while one
## MultiMesh submits the same cached rounded-box surface at the authored poses.
const RACK_CARD_SIZE := Vector3(0.02, 0.24, 0.10)
const RACK_CARD_COPY_COUNT := 14
const JUNCTION_ARC_TILE_COPY_COUNT := 8
## Fifteen childless visual treads sit over the continuous collision ramp. Their
## authored names remain as Marker3D anchors while one circulation-local batch
## draws the identical rounded-box surfaces. The ramp remains the only physics
## and navigation authority for the stair.
const STAIR_TREAD_SIZE := Vector3(2.92, 0.1, 0.72)
const STAIR_TREAD_COPY_COUNT := STAIR_STEP_COUNT
## Six identical emissive lenses are presentation surfaces for six independent
## ceiling practicals. The housings and Light3D nodes remain ordinary; only the
## visual-only rounded-box submissions are combined here.
const CEILING_LUMINAIRE_LENS_SIZE := Vector3(1.85, 0.035, 0.2)
const CEILING_LUMINAIRE_LENS_COPY_COUNT := 6
const CEILING_LUMINAIRE_LENS_POSITIONS := [
	Vector3(3.2, 4.405, 11.15),
	Vector3(3.2, 4.405, 14.15),
	Vector3(3.2, 4.405, 16.15),
	Vector3(8.0, 4.405, 11.15),
	Vector3(8.0, 4.405, 14.15),
	Vector3(8.0, 4.405, 16.15),
]
## Six identical graphite louvres sit above the two collision-free roof vents.
## They have no children or authority; stable anchors retain the authored copy
## roster while one envelope-local MultiMesh submits their unchanged surfaces.
const ROOF_VENT_LOUVRE_SIZE := Vector3(0.09, 0.06, 0.58)
const ROOF_VENT_LOUVRE_COPY_COUNT := 6
const ROOF_VENT_LOUVRE_POSITIONS := [
	Vector3(2.81, 5.34, 13.0),
	Vector3(3.05, 5.34, 13.0),
	Vector3(3.29, 5.34, 13.0),
	Vector3(7.86, 5.34, 13.0),
	Vector3(8.10, 5.34, 13.0),
	Vector3(8.34, 5.34, 13.0),
]
## Five identical pressure-rib arcs cross the operations-room roof. Each arc is
## still represented by its inert named envelope anchor, while the 14 matching
## tube recipes are submitted once apiece across all five Z planes. The roof box
## remains the sole collider and the ribs carry no gameplay or light authority.
const PRESSURE_RIB_COPY_COUNT := 5
const PRESSURE_RIB_SEGMENT_COUNT := 14
const PRESSURE_RIB_VISIBLE_COPY_COUNT := PRESSURE_RIB_COPY_COUNT * PRESSURE_RIB_SEGMENT_COUNT
const PRESSURE_RIB_Z_START := 9.45
const PRESSURE_RIB_Z_STEP := 1.88
const PRESSURE_RIB_X_MIN := 0.28
const PRESSURE_RIB_X_MAX := 10.92
const PRESSURE_RIB_SPRING_HEIGHT := 4.82
const PRESSURE_RIB_CROWN_HEIGHT := 5.58
const PRESSURE_RIB_RADIUS := 0.105
## Three identical cyan route-light strips are presentation-only overlays on the
## collision-backed lower deck. Their authored names remain childless anchors;
## one lower-deck MultiMesh draws the unchanged cached rounded-box surface.
const LOW_ROUTE_LIGHT_SIZE := Vector3(0.38, 0.025, 0.12)
const LOW_ROUTE_LIGHT_COPY_COUNT := 3
const LOW_ROUTE_LIGHT_POSITIONS := [
	Vector3(0.0, 0.088, 1.0),
	Vector3(0.0, 0.088, 4.25),
	Vector3(0.0, 0.088, 8.9),
]
## Six brass collars dress the non-colliding approach service tubes. The tubes
## remain the only visual structure in this family; these childless markers
## preserve each authored copy transform while one inert batch submits the
## unchanged chamfered-cylinder surface.
const APPROACH_EDGE_COLLAR_RADIUS := 0.115
const APPROACH_EDGE_COLLAR_HEIGHT := 0.16
const APPROACH_EDGE_COLLAR_COPY_COUNT := 6
const BASELINE_RENDER_DESCENDANT_NODE_COUNT := 1183
const RENDER_DESCENDANT_NODE_COUNT := 1148
const BASELINE_RENDERER_NODE_COUNT := 862
const RENDERER_NODE_COUNT := 748
const BASELINE_DRAWN_COPY_COUNT := 872
const DRAWN_COPY_COUNT := 888
const BASELINE_SURFACE_SUBMISSION_COUNT := 862
const SURFACE_SUBMISSION_COUNT := 748
const BASELINE_MESH_RESOURCE_COUNT := 326
const MESH_RESOURCE_COUNT := 302
const BASELINE_MATERIAL_RESOURCE_COUNT := 34
const MATERIAL_RESOURCE_COUNT := 34

const LOWER_FLOOR_ELEVATION := 0.0
const UPPER_FLOOR_ELEVATION := 4.2
## Width of the presentation-only route ribbon. The lower ribbon retains its
## original 0.18 m width and clears the Operations Access frame; readability
## comes from turning the ribbon toward the actual stair instead of widening it
## into the door post.
const ROUTE_STRIPE_WIDTH := 0.18
const STAIR_STEP_COUNT := 15
const STAIR_RISE := UPPER_FLOOR_ELEVATION / float(STAIR_STEP_COUNT - 1)
const STAIR_RUN := 9.8 / float(STAIR_STEP_COUNT - 1)
const STAIR_CLEAR_WIDTH := 2.8
const STAIR_HEAD_CLEARANCE := 2.7

## The upper-deck handoff used to be identified only by a flat red line. These
## paired ribs give the first few metres beyond the stair a recognisable Aft
## transfer-zone silhouette while keeping the walking lane open to the sky.
## Every rib visibly bears on the collision-backed floor outside the lane; the
## six red skins and six attached brass datum bands cost only two submissions.
const UPPER_TRANSFER_RIB_SIZE := Vector3(0.24, 2.35, 0.52)
const UPPER_TRANSFER_BAND_SIZE := Vector3(0.28, 0.16, 0.56)
const UPPER_TRANSFER_RIB_X_POSITIONS := [-7.1, -3.2]
const UPPER_TRANSFER_RIB_Z_POSITIONS := [14.15, 14.75, 15.35]
const UPPER_TRANSFER_CLEAR_WIDTH := 3.66
const UPPER_TRANSFER_OPEN_CLEARANCE := 6.0

## The stair-base landing is walked across, not looked at. Its footprint is a
## constant because two separate rail runs have to be kept off it: the approach
## rail must stop at its southern edge, and the eastern stair rail must not begin
## until the ramp has climbed clear of it. MAP-001 was exactly that pair of rails
## closing the only gate between the connection deck and the ramp foot.
# Hold the landing's east edge at x=-2.40 while extending its west edge to the
# visible tread edge at x=-7.16. This closes the 0.36 m unsupported frontage
# beside the ramp collision without moving the stair, route stripe, or signs.
const STAIR_BASE_LANDING_CENTRE := Vector3(-4.78, -0.32, 3.25)
const STAIR_BASE_LANDING_SIZE := Vector3(4.76, 0.64, 3.5)

## Physical size of one station panel plate in this module, in metres of world
## space per texture repeat. Frozen; the Fleet Dock comb and the hub match it so
## no plate changes size across a connector seam.
const PANEL_SURFACE_SCALE := 0.30

const OPERATIONS_ROOM_CENTER := Vector3(5.6, 2.4, 13.2)
# Include the floor-contact tolerance of a CharacterBody root. The previous
# 2.35 m half-height began at local Y=0.05 and incorrectly rejected an avatar
# standing exactly on the physical room floor.
const OPERATIONS_ROOM_HALF_EXTENTS := Vector3(5.0, 2.45, 3.6)
## The retained StationDoor authors this exact header and matching collision
## envelope. A quarter-metre end radius replaces its gameplay-distance box
## silhouette without changing the door, opening, frame body or panel family.
const OPERATIONS_ENTRANCE_HEADER_SIZE := Vector3(4.2, 0.5, 0.72)
const OPERATIONS_ENTRANCE_HEADER_END_RADIUS := 0.25
const OPERATIONS_ENTRANCE_HEADER_CURVE_SEGMENTS := 8
const FOOTPRINT_MIN := Vector3(-10.4, -1.5, -2.6)
const FOOTPRINT_MAX := Vector3(11.2, 8.4, 21.0)
const OPEN_WALKABLE_AREA_ESTIMATE := 174.0
const COVERED_WALKABLE_AREA_ESTIMATE := 83.2

const EVIDENCE_REFERENCES := [
	"RESEARCH.md: implementation evidence map / exposed dock lattice",
	"B2@04:55-05:10 / separated nodes, narrow arms, substantial void",
	"B3@00:20-00:52 / exposed junction and short vertical route",
	"B3@02:40-03:00 / compact grey console room with windows and blue access",
	"B4@04:20-04:30 / chair-console banks and broad windows, context uncertain",
]

const CONTENT_NOTE := (
	"The open-lattice hierarchy, vertical transition, compact windowed room, and "
	+ "coloured access landmarks are bounded by surviving observations. The Aft "
	+ "Junction Stack name, exact geometry, measurements, furniture arrangement, "
	+ "service wall, door motion, and adjacency are original modern design. The red "
	+ "VIP door is a landmark with no authenticated interior: what stands behind it "
	+ "is `VipReceptionSuite`, an invented modern interpretation at confidence none, "
	+ "and this module claims no original VIP room, adjacency or era."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_lower_junction: Marker3D = %RouteLowerJunction
@onready var _route_stair_base: Marker3D = %RouteStairBase
@onready var _route_stair_top: Marker3D = %RouteStairTop
@onready var _operations_room_anchor: Marker3D = %OperationsRoomAnchor
@onready var _upper_floor_anchor: Marker3D = %UpperFloorAnchor
@onready var _vip_access_anchor: Marker3D = %VIPAccessAnchor
@onready var _operations_entrance: StationDoor = %OperationsEntrance
@onready var _vip_access: StationDoor = %VIPAccess

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _pod_corner_collar_mesh: TorusMesh
var _vip_facade_column_trim_batch: MultiMeshInstance3D
var _rack_card_batch: MultiMeshInstance3D
var _junction_arc_tile_batch: MultiMeshInstance3D
var _stair_tread_batch: MultiMeshInstance3D
var _console_shock_collar_batch: MultiMeshInstance3D
var _cabinet_fastener_batch: MultiMeshInstance3D
var _ceiling_luminaire_lens_batch: MultiMeshInstance3D
var _roof_vent_louvre_batch: MultiMeshInstance3D
var _approach_edge_collar_batch: MultiMeshInstance3D
var _exterior_pipe_clamp_mesh: TorusMesh
var _spine_clamp_mesh: TorusMesh
var _rack_cable_tray_clamp_mesh: TorusMesh
var _console_shock_collar_mesh: TorusMesh
var _pedestal_bearing_mesh: TorusMesh
var _conduit_collar_mesh: TorusMesh
var _roof_vent_collar_mesh: TorusMesh
var _route_markers: Dictionary = {}
var _chair_nodes: Array[Node3D] = []
var _console_nodes: Array[Node3D] = []
var _built := false
var _module_enabled := true
## Content-pass animation state. See `_process` / `_update_operations_content`.
var _content_clock := 0.0
var _sweep_arm: Node3D = null
var _content_lenses: Array[MeshInstance3D] = []
var _content_lens_specs: Array[Dictionary] = []


func _ready() -> void:
	if not _built:
		_built = true
		_create_materials()
		_index_routes()
		_build_structure()
		_style_access_landmarks()
		_apply_operations_entrance_header_curve()
		_apply_metadata()
	# Reconcile the real node state against `_module_enabled` on every ready, so a
	# scene-authored or externally drifted layer/visibility cannot survive.
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


func get_operations_entrance() -> StationDoor:
	return _operations_entrance


func get_vip_access() -> StationDoor:
	return _vip_access


func get_operations_room_marker() -> Marker3D:
	return _operations_room_anchor


func get_upper_floor_marker() -> Marker3D:
	return _upper_floor_anchor


func get_vip_access_marker() -> Marker3D:
	return _vip_access_anchor


func get_route_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_id: StringName in _route_markers.keys():
		result.append(route_id)
	result.sort()
	return result


func has_route_marker(route_id: StringName) -> bool:
	return _route_markers.has(route_id)


func get_route_marker(route_id: StringName) -> Marker3D:
	return _route_markers.get(route_id) as Marker3D


func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


func get_route_transforms() -> Dictionary:
	var result := {}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		result[route_id] = marker.global_transform
	return result


func get_floor_elevations() -> PackedFloat32Array:
	return PackedFloat32Array([LOWER_FLOOR_ELEVATION, UPPER_FLOOR_ELEVATION])


func get_stair_profile() -> Dictionary:
	return {
		"step_count": STAIR_STEP_COUNT,
		"riser_height": STAIR_RISE,
		"tread_run": STAIR_RUN,
		"clear_width": STAIR_CLEAR_WIDTH,
		"minimum_head_clearance": STAIR_HEAD_CLEARANCE,
		"lower_elevation": LOWER_FLOOR_ELEVATION,
		"upper_elevation": UPPER_FLOOR_ELEVATION,
		"collision_solution": &"continuous_ramp_beneath_visible_treads",
	}


## Local-space surface samples down the centre of the continuous stair route.
func get_stair_surface_samples() -> PackedVector3Array:
	var samples := PackedVector3Array()
	for index in STAIR_STEP_COUNT:
		var progress := float(index) / float(STAIR_STEP_COUNT - 1)
		samples.append(Vector3(-5.7, progress * UPPER_FLOOR_ELEVATION + 0.11, 3.0 + progress * 9.8))
	return samples


func get_upper_transfer_gate_profile() -> Dictionary:
	return {
		"rib_count": UPPER_TRANSFER_RIB_X_POSITIONS.size() \
			* UPPER_TRANSFER_RIB_Z_POSITIONS.size(),
		"clear_width": UPPER_TRANSFER_CLEAR_WIDTH,
		"open_clearance": UPPER_TRANSFER_OPEN_CLEARANCE,
		"collision_solution": &"deck_supported_visual_ribs_outside_lane",
		"render_submissions": 2,
		"route_authority": &"none",
	}


func get_chair_count() -> int:
	return _chair_nodes.size()


func get_console_bay_count() -> int:
	return _console_nodes.size()


func get_service_wall() -> Node3D:
	return get_node_or_null("Structure/OperationsRoom/ServiceWall") as Node3D


func contains_operations_room(world_position: Vector3) -> bool:
	var local_position := to_local(world_position)
	var relative := local_position - OPERATIONS_ROOM_CENTER
	return absf(relative.x) <= OPERATIONS_ROOM_HALF_EXTENTS.x \
		and absf(relative.y) <= OPERATIONS_ROOM_HALF_EXTENTS.y \
		and absf(relative.z) <= OPERATIONS_ROOM_HALF_EXTENTS.z


func get_operations_room_volume() -> Dictionary:
	return {
		"local_center": OPERATIONS_ROOM_CENTER,
		"half_extents": OPERATIONS_ROOM_HALF_EXTENTS,
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, OPERATIONS_ROOM_CENTER),
	}


func get_open_to_space_ratio() -> float:
	return OPEN_WALKABLE_AREA_ESTIMATE / (OPEN_WALKABLE_AREA_ESTIMATE + COVERED_WALKABLE_AREA_ESTIMATE)


## The root origin is the south connection plane. Integrators can place that
## origin at the end of an existing aft spine without reverse-engineering meshes.
func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"exposed modular station lattice with substantial negative space",
			"short vertical circulation near an open junction",
			"compact grey console room with broad windows",
			"cyan operated access and red VIP landmark",
		]),
		"modern_interpretations": PackedStringArray([
			"module name and exact dimensions",
			"asymmetric two-level arrangement",
			"operations furniture and service wall",
			# The content pass. Surviving material supports "a compact grey console
			# room with windows"; it supports nothing whatever about what is in one.
			# The rack bank, the module status board and its route schematic, the
			# traffic plot table and its tokens, the coordinator's desk, the chart
			# press, the refreshment stand, the crew traces and the stair-head muster
			# locker are all original modern design, and the working state each of
			# them shows — which rack is isolated, which traffic is inbound, which
			# annunciator is up — is invented, not recovered.
			"operations-room apparatus, its indicated working state, and the stair-head muster locker",
			"door mechanics and exact adjacency",
			"the project-original station panel material family mapped across floors, stair ramp, and pressure plates",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null:
		errors.append("module integration anchor is missing")
	if _operations_entrance == null:
		errors.append("operations entrance StationDoor is missing")
	if _vip_access == null:
		errors.append("VIP access StationDoor is missing")
	elif _vip_access.deferred_access or _vip_access.locked:
		# Reversed on the day the interior was built. The landmark used to be
		# required to stay shut because there was nothing behind it; it is now
		# required to stay openable, because a door that refuses to open in front
		# of a room the player can see through the glazing is a worse lie than an
		# empty facade ever was. The evidence boundary moved from the door to the
		# room, where `VipReceptionSuite` publishes it.
		errors.append("VIP access opens onto a built interior and must not be locked or deferred")
	if _route_markers.size() < 7:
		errors.append("the complete lower, stair, room, upper, and VIP route is not exposed")
	if _chair_nodes.size() != 4:
		errors.append("operations room must expose exactly four physical chairs")
	if _console_nodes.size() != 3:
		errors.append("operations room must expose exactly three console bays")
	if get_service_wall() == null:
		errors.append("operations service wall is missing")
	if get_open_to_space_ratio() < 0.5:
		errors.append("less than half of the estimated walkable area is open to space")
	# The collision, performance, and lifecycle contracts are only meaningful if
	# this module rejects on them. Without these checks a drifted collision layer
	# or a blown budget is reported in the contract dictionary and validated
	# clean, so `validate_contract` would call the module valid anyway.
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle):
		errors.append("static body collision layers differ from the current lifecycle state")
	if not bool(collision.all_masks_zero):
		errors.append("station structure must not query collision through a mask")
	if not bool(collision.all_shapes_present_and_enabled):
		errors.append("a walkable surface is missing an enabled collision shape")
	var performance := get_performance_contract()
	if not bool(performance.within_budget):
		errors.append("module component counts exceed the declared quality budget")
	if not bool(performance.pod_corner_collar_visual_sharing.valid):
		errors.append("shared pod-corner collar visual allocation contract drifted")
	if not bool(performance.vip_facade_column_trim_batch.valid):
		errors.append("VIP facade column-trim batch contract drifted")
	if not bool(performance.rack_card_batch.valid):
		errors.append("watch-rack card batch contract drifted")
	if not bool(performance.spine_clamp_visual_sharing.valid):
		errors.append("shared spine-clamp visual allocation contract drifted")
	if not bool(performance.rack_cable_tray_clamp_visual_sharing.valid):
		errors.append("shared rack-cable-tray clamp visual allocation contract drifted")
	if not bool(performance.console_shock_collar_visual_sharing.valid):
		errors.append("shared console-shock-collar visual allocation contract drifted")
	if not bool(performance.pedestal_bearing_visual_sharing.valid):
		errors.append("shared chair-pedestal-bearing visual allocation contract drifted")
	if not bool(performance.conduit_collar_visual_sharing.valid):
		errors.append("shared service-wall-conduit-collar visual allocation contract drifted")
	if not bool(performance.exterior_pipe_clamp_visual_sharing.valid):
		errors.append("shared exterior-pipe-clamp visual allocation contract drifted")
	if not bool(performance.roof_vent_collar_visual_sharing.valid):
		errors.append("shared roof-vent collar visual allocation contract drifted")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
		or not bool(lifecycle.visible_matches_enabled) \
		or not bool(lifecycle.collision_matches_enabled):
		errors.append("module lifecycle state does not match the enabled flag")
	if not bool(lifecycle.process_matches_lifecycle):
		errors.append("module keeps processing while disabled")
	return errors


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence": get_evidence_metadata(),
		"route_ids": get_route_ids(),
		"floor_elevations": get_floor_elevations(),
		"stair_profile": get_stair_profile(),
		"operations_room": get_operations_room_volume(),
		"chair_count": get_chair_count(),
		"console_bay_count": get_console_bay_count(),
		"open_to_space_ratio": get_open_to_space_ratio(),
		"vip_deferred": _vip_access != null and _vip_access.deferred_access,
		"vip_leads_to_interpretation_interior": _vip_access != null \
			and not _vip_access.locked \
			and not _vip_access.deferred_access,
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["chair_count"] = get_chair_count()
	roster["console_bay_count"] = get_console_bay_count()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(
		self, WORLD_LAYER, _module_enabled
	)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_performance_contract() -> Dictionary:
	# Budgets are this module's own policy: declared regression ceilings measured
	# against the built module, not representative-hardware performance evidence.
	# The mesh ceiling sits just above the 532 primitives the stair treads,
	# railings, and service detail actually produce; it was previously set to 170,
	# a figure no build ever met.
	var contract := StationModuleContract.build_performance_contract(self, {
		# Mesh ceiling re-frozen in the open, 170 -> 600 -> 848, and it is now the
		# exact built count rather than the previous ~13% of headroom, for the same
		# reason the light ceiling already was: a ceiling with slack in it lets the
		# next content pass land without declaring itself. 600 -> 853 was the content
		# pass; batching fourteen rack cards into one renderer brings it to 840.
		# Every content primitive remains in this file. Measured per assembly
		# against the live tree:
		#
		#   Watch rack bank, 118. Three rack frames, kicks, caps and their cable
		#   drops; a fascia each on the two made-up racks and, on the isolated one,
		#   the removed fascia, its open backplane, three cable looms, a lockout
		#   hasp/chain/tag, two open card cages and fourteen cards; four plug-in
		#   modules per made-up rack with a vent, readout and two knobs each; a
		#   status lens, breaker body and breaker lever per rack; the tray, its four
		#   clamps and the riser into the service wall.
		#   Module status board, 41. Body, chart field, four frame members, five
		#   schematic links, six nodes and six node lenses, six annunciator bodies,
		#   lenses and flags, and the legend.
		#   Traffic plot table, 70. Base, two pedestals, top, apron, chart cradle and
		#   four rolls, plot disc, rim, three graticule rings, four bearings, hub,
		#   five tokens and five pins, four rim posts and two rails, two chart
		#   borders, two sheets, two edge trims, the four-piece sweep assembly, and
		#   the logbook, mug, gloves and dividers left on it.
		#   Coordinator desk, 26. Body, top, kick, two drawer fronts and two pulls,
		#   the lamp's three pieces, the log's four, the handset's three, two manual
		#   stacks, and the headset's four.
		#   Chart press, 32. Body, top, kick, five drawer fronts and five pulls, four
		#   rolls, a strap, the notice board, seven sheets, two pins, the clipboard
		#   hook, board and sheet.
		#   Refreshment stand, 18, plus the waste bin and its rim.
		#   Crew traces, 6, and the coordinator's coverall, 3.
		#   Stair-head muster locker, 25.
		#
		# Frame cost is unmeasured and unmeasurable on this box: it renders through
		# llvmpipe. What is measured is that every one of these is a chamfered kit
		# primitive sharing this module's two mesh caches, so the added *unique*
		# mesh resources are far fewer than the added instances.
		# The adjacent physical Ship Services workstation adds three literal
		# display meshes to the retained ConsoleBay03; no hidden headroom is used.
		"mesh_instances": 838,
		# Unchanged at 120 against 103 built, up from 87. The content pass added
		# sixteen colliders and every one of them is a piece of furniture a player
		# can walk into: three rack frames, the plot table's base, two pedestals and
		# top, the coordinator desk body and top, the chart press body and top, the
		# refreshment counter and top, the waste bin, and the muster locker's two
		# carcass halves. Anything
		# in this room that looks solid at arm's reach is solid. These two ceilings
		# are deliberately left with their existing headroom rather than pinned to
		# the built figure — the mesh and light ceilings are this module's declared
		# regression gates and two is enough.
		"static_bodies": 120,
		"collision_shapes": 120,
		"labels": 4,
		# Light ceiling re-frozen in the open, 12 -> 32 -> 40. The module built 11
		# lights against that 12; the fixture pass took it to 32, all of them
		# fixture practicals — see `_fixture_practical`. Every one is shadowless,
		# under 9 m range, steeply attenuated and distance-faded, and they exist
		# because emission illuminates nothing in Forward+, so a lens, strip,
		# status light or sign could not light the plate it is bolted to no matter
		# what energy it carried.
		#
		# 32 -> 40 is the interior legibility pass, and all eight are in the
		# operations room: the single centreline row of three ceiling luminaires
		# becomes two rows of three (+3) in a 10.4 m-wide room that had no overhead
		# over either side third, each of the two 7.3 m ceiling coves goes from one
		# lamp at its midpoint to three down its length (+4), and the coordinator
		# chair — the one seat in the room with no fixture within range of it in
		# any direction — gets the same under-console task wash the other two
		# working positions already had (+1). Per-fixture energy comes *down* in
		# both places the count went up, so this is a redistribution of the room's
		# existing luminaires across the room's actual volume and not added gain;
		# see the long note on `_build_operations_lighting`.
		#
		# The ceiling is deliberately set at the exact built count rather than left
		# with headroom, so the next addition has to be declared here too. Frame
		# cost is unmeasured: this box renders through llvmpipe.
		#
		# 40 -> 50 is the content pass, and it is the same trade every fixture in
		# this module has already made: emission is a local surface term in
		# Forward+, so a lens that lights nothing is a decal, and every lit thing
		# this pass added had to either throw light or not be lit. All ten are
		# `_fixture_practical` — shadowless, sub-4 m, steeply attenuated, faded out
		# by 85 m — and each carries its own fixture's hue:
		#
		#   `WatchRackStatusSpill` x2. One per *made-up* rack, and deliberately none
		#   on the isolated one. This is the hardware-state rule doing real work: the
		#   rack that is out throws no light, so which rack is dead is legible with
		#   the room's own colour discarded.
		#   `StatusBoardWash` x2. The south wall is the only wall with no overhead
		#   within 1.8 m, and the board is 5.4 m across; one lamp at its centre was
		#   photographed and left both ends dark.
		#   `PlotTableGlow` and `PlotSweepLamp`. The plot disc and the sweep head are
		#   the two lit surfaces on the table; the second is a child of the moving
		#   arm, so the light travels with the instrument that carries it.
		#   `CoordinatorLampSpill`, `NoticeBoardWash`, `RefreshmentSpill`. One each
		#   for the three pockets of this room the six overheads do not reach: the
		#   coordinator's corner, the west wall, and the north-west counter.
		#   `MusterLockerLamp`. The stair-head locker on the open upper deck, which
		#   has no local light of any kind above the stair's three courtesy pools.
		#
		# Every one of the ten is at or below 0.34 energy and none reaches beyond
		# 3.8 m, so this is ten small pools sited on ten fixtures, not a lift.
		"lights": 50,
		# Now genuinely used, where it was budgeted-but-unspent before. The content
		# pass gave the module one `_process`: it turns the plot table's sweep arm
		# and pulses one annunciator lens, both closed-form in an accumulated clock,
		# and `_apply_enabled_state` switches it off with the module.
		"process_loops": 1,
		"physics_process_loops": 1,
	})
	contract["schema_version"] = SCHEMA_VERSION
	var visual_sharing := get_pod_corner_collar_visual_allocation_audit()
	var facade_batch := get_vip_facade_column_trim_batch_audit()
	var rack_card_batch := get_rack_card_batch_audit()
	var spine_sharing := get_spine_clamp_visual_allocation_audit()
	var tray_clamp_sharing := get_rack_cable_tray_clamp_visual_allocation_audit()
	var console_collar_sharing := get_console_shock_collar_visual_allocation_audit()
	var cabinet_fastener_batch := get_cabinet_fastener_batch_audit()
	var pedestal_bearing_sharing := get_pedestal_bearing_visual_allocation_audit()
	var conduit_collar_sharing := get_conduit_collar_visual_allocation_audit()
	var exterior_pipe_clamp_sharing := get_exterior_pipe_clamp_visual_allocation_audit()
	var roof_vent_collar_sharing := get_roof_vent_collar_visual_allocation_audit()
	var ceiling_lens_batch := get_ceiling_luminaire_lens_batch_audit()
	var approach_edge_collar_batch := get_approach_edge_collar_batch_audit()
	contract["pod_corner_collar_visual_sharing"] = visual_sharing
	contract["vip_facade_column_trim_batch"] = facade_batch
	contract["rack_card_batch"] = rack_card_batch
	contract["spine_clamp_visual_sharing"] = spine_sharing
	contract["rack_cable_tray_clamp_visual_sharing"] = tray_clamp_sharing
	contract["console_shock_collar_visual_sharing"] = console_collar_sharing
	contract["cabinet_fastener_batch"] = cabinet_fastener_batch
	contract["pedestal_bearing_visual_sharing"] = pedestal_bearing_sharing
	contract["conduit_collar_visual_sharing"] = conduit_collar_sharing
	contract["exterior_pipe_clamp_visual_sharing"] = exterior_pipe_clamp_sharing
	contract["roof_vent_collar_visual_sharing"] = roof_vent_collar_sharing
	contract["ceiling_luminaire_lens_batch"] = ceiling_lens_batch
	contract["approach_edge_collar_batch"] = approach_edge_collar_batch
	contract["within_budget"] = (
		bool(contract.within_budget)
		and bool(visual_sharing.valid)
		and bool(facade_batch.valid)
		and bool(rack_card_batch.valid)
		and bool(spine_sharing.valid)
		and bool(tray_clamp_sharing.valid)
		and bool(console_collar_sharing.valid)
		and bool(cabinet_fastener_batch.valid)
		and bool(pedestal_bearing_sharing.valid)
		and bool(conduit_collar_sharing.valid)
		and bool(exterior_pipe_clamp_sharing.valid)
		and bool(roof_vent_collar_sharing.valid)
		and bool(ceiling_lens_batch.valid)
		and bool(approach_edge_collar_batch.valid)
	)
	return contract


## Component-local proof for the six visual-only ceiling-luminaire lenses.
## Housings and practical Light3D nodes stay ordinary and retain their authored
## transforms; one bounded MultiMesh replaces only the six lens submissions.
func get_ceiling_luminaire_lens_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var batch := _ceiling_luminaire_lens_batch
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh if multimesh != null else null
	var lighting := get_node_or_null(
		^"Structure/OperationsRoom/LocalizedLighting"
	) as Node3D
	var expected_transforms: Array[Transform3D] = []
	for position in CEILING_LUMINAIRE_LENS_POSITIONS:
		expected_transforms.append(Transform3D(Basis.IDENTITY, position as Vector3))
	var expected_buffer := _encode_multimesh_transforms(expected_transforms)
	var expected_bounds := (
		_transformed_mesh_bounds(mesh.get_aabb(), expected_transforms)
		if mesh != null else AABB()
	)
	var anchors: Array[Marker3D] = []
	var housings: Array[MeshInstance3D] = []
	var practicals: Array[OmniLight3D] = []
	if lighting != null:
		for child in lighting.get_children():
			if child is Marker3D and bool(child.get_meta("ceiling_luminaire_lens_anchor", false)):
				anchors.append(child as Marker3D)
			elif child is MeshInstance3D:
				var housing_candidate := child as MeshInstance3D
				if housing_candidate.material_override == _materials.get("hull_dark") \
						and housing_candidate.mesh != null \
						and housing_candidate.mesh.get_aabb().size.is_equal_approx(Vector3(2.15, 0.11, 0.44)):
					housings.append(housing_candidate)
			elif child is OmniLight3D:
				var light_candidate := child as OmniLight3D
				for lens_position in CEILING_LUMINAIRE_LENS_POSITIONS:
					if light_candidate.position.is_equal_approx(
						(lens_position as Vector3) + Vector3(0.0, -0.405, 0.0)
					):
						practicals.append(light_candidate)
						break
	if anchors.size() != CEILING_LUMINAIRE_LENS_COPY_COUNT:
		errors.append("ceiling_luminaire_lens_anchor_count_drift")
	if housings.size() != CEILING_LUMINAIRE_LENS_COPY_COUNT \
			or practicals.size() != CEILING_LUMINAIRE_LENS_COPY_COUNT:
		errors.append("ceiling_luminaire_fixture_node_count_drift")
	for index in mini(anchors.size(), expected_transforms.size()):
		var anchor := anchors[index]
		if not anchor.transform.is_equal_approx(expected_transforms[index]) \
				or anchor.get_parent() != lighting \
				or anchor.get_child_count() != 0 \
				or anchor.get_script() != null \
				or not anchor.get_groups().is_empty() \
				or anchor.get_meta_list().size() != 1 \
				or not anchor.get_meta_list().has(&"ceiling_luminaire_lens_anchor") \
				or not bool(anchor.get_meta("ceiling_luminaire_lens_anchor", false)):
			errors.append("ceiling_luminaire_lens_anchor_roster_drift")
	if batch == null or multimesh == null or mesh == null:
		errors.append("ceiling_luminaire_lens_batch_missing")
	else:
		if batch.get_parent() != lighting or str(batch.name) != "CeilingLuminaireLensRenderBatch":
			errors.append("ceiling_luminaire_lens_batch_path_drift")
		if multimesh.transform_format != MultiMesh.TRANSFORM_3D \
				or multimesh.use_colors or multimesh.use_custom_data:
			errors.append("ceiling_luminaire_lens_multimesh_format_drift")
		if multimesh.instance_count != CEILING_LUMINAIRE_LENS_COPY_COUNT \
				or multimesh.visible_instance_count != CEILING_LUMINAIRE_LENS_COPY_COUNT:
			errors.append("ceiling_luminaire_lens_visible_copy_roster_drift")
		if multimesh.buffer != expected_buffer:
			errors.append("ceiling_luminaire_lens_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("ceiling_luminaire_lens_culling_bounds_drift")
		if mesh != _rounded_box_mesh(CEILING_LUMINAIRE_LENS_SIZE) \
				or mesh.get_surface_count() != 1 \
				or mesh.surface_get_material(0) != null \
				or mesh.resource_local_to_scene \
				or not mesh.get_aabb().size.is_equal_approx(CEILING_LUMINAIRE_LENS_SIZE):
			errors.append("ceiling_luminaire_lens_mesh_recipe_drift")
		if not batch.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not batch.visible \
				or batch.layers != 1 \
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or batch.material_override != _materials.get("worklight") \
				or batch.material_overlay != null \
				or not is_zero_approx(batch.transparency):
			errors.append("ceiling_luminaire_lens_render_state_drift")
		var metadata_keys := batch.get_meta_list()
		if batch.get_child_count() != 0 \
				or batch.get_script() != null \
				or not batch.get_groups().is_empty() \
				or metadata_keys.size() != 2 \
				or not metadata_keys.has(&"visual_detail_only") \
				or not metadata_keys.has(&"authored_instance_transforms") \
				or not bool(batch.get_meta("visual_detail_only", false)) \
				or not _transform_arrays_match(
					batch.get_meta("authored_instance_transforms", []) as Array,
					expected_transforms
				):
			errors.append("ceiling_luminaire_lens_batch_gained_semantic_authority")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_ceiling_luminaire_lenses",
		"legacy": {"renderer_nodes": 6, "drawn_copies": 6, "surface_submissions": 6},
		"current": {
			"stable_anchor_nodes": anchors.size(),
			"renderer_nodes": 1 if batch != null else 0,
			"drawn_copies": multimesh.visible_instance_count if multimesh != null else 0,
			"surface_submissions": mesh.get_surface_count() if mesh != null else 0,
		},
		"reductions": {"renderer_nodes": 5, "drawn_copies": 0, "surface_submissions": 5},
		"fixture_housings": housings.size(),
		"fixture_practicals": practicals.size(),
		"authored_transforms": expected_transforms.duplicate(),
		"renderer_buffer": multimesh.buffer if multimesh != null else PackedFloat32Array(),
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"collision_authority_added": false,
		"interaction_authority_added": false,
		"semantic_authority_added": false,
	}.duplicate(true)


## The approach service tubes are untouched non-colliding structure. This audit
## freezes only their six childless brass collars: paths/transforms, material,
## culling and inert renderer state must remain exact while submissions fall 6→1.
func get_approach_edge_collar_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var lower := get_node_or_null(^"Structure/LowerOpenDeck") as Node3D
	var expected := _approach_edge_collar_transforms()
	var anchors: Array[Marker3D] = []
	if lower != null:
		for child in lower.get_children():
			if child is Marker3D and bool(child.get_meta("approach_edge_collar_anchor", false)):
				anchors.append(child as Marker3D)
	if anchors.size() != expected.size():
		errors.append("approach_edge_collar_anchor_count_drift")
	for index in mini(anchors.size(), expected.size()):
		var anchor := anchors[index]
		if not anchor.transform.is_equal_approx(expected[index]) \
				or anchor.get_parent() != lower \
				or anchor.get_child_count() != 0 \
				or anchor.get_script() != null \
				or not anchor.get_groups().is_empty() \
				or anchor.get_meta_list().size() != 1 \
				or not bool(anchor.get_meta("approach_edge_collar_anchor", false)):
			errors.append("approach_edge_collar_anchor_roster_drift")
	var batch := _approach_edge_collar_batch
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh if multimesh != null else null
	var expected_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		APPROACH_EDGE_COLLAR_RADIUS,
		APPROACH_EDGE_COLLAR_RADIUS,
		APPROACH_EDGE_COLLAR_HEIGHT,
		32,
		_chamfered_cylinder_cache
	)
	if batch == null or multimesh == null or mesh == null:
		errors.append("approach_edge_collar_batch_missing")
	else:
		if batch.get_parent() != lower or batch.name != &"ApproachEdgeCollarRenderBatch":
			errors.append("approach_edge_collar_batch_path_drift")
		if mesh != expected_mesh or mesh.get_surface_count() != 1:
			errors.append("approach_edge_collar_mesh_identity_drift")
		if multimesh.instance_count != APPROACH_EDGE_COLLAR_COPY_COUNT \
				or multimesh.visible_instance_count != APPROACH_EDGE_COLLAR_COPY_COUNT:
			errors.append("approach_edge_collar_copy_count_drift")
		if multimesh.buffer != _encode_multimesh_transforms(expected):
			errors.append("approach_edge_collar_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(
			_transformed_mesh_bounds(expected_mesh.get_aabb(), expected)
		):
			errors.append("approach_edge_collar_culling_bounds_drift")
		if batch.material_override != _materials.get("brass") \
				or not batch.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not batch.visible or batch.layers != 1 \
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or batch.get_child_count() != 0 or batch.get_script() != null \
				or not batch.get_groups().is_empty() \
				or not bool(batch.get_meta("visual_detail_only", false)) \
				or not _transform_arrays_match(
					batch.get_meta("authored_instance_transforms", []) as Array, expected
				):
			errors.append("approach_edge_collar_renderer_state_or_authority_drift")
	if lower != null and not lower.find_children(
		"ApproachEdgeCollar*", "MeshInstance3D", false, false
	).is_empty():
		errors.append("approach_edge_collar_legacy_renderer_present")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy_renderer_nodes": APPROACH_EDGE_COLLAR_COPY_COUNT,
		"renderer_nodes": 1 if batch != null else 0,
		"legacy_surface_submissions": APPROACH_EDGE_COLLAR_COPY_COUNT,
		"surface_submissions": mesh.get_surface_count() if mesh != null else 0,
		"drawn_copies": multimesh.visible_instance_count if multimesh != null else 0,
		"stable_anchor_nodes": anchors.size(),
		"renderer_buffer": multimesh.buffer if multimesh != null else PackedFloat32Array(),
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"collision_authority_count": 0,
		"interaction_authority_count": 0,
	}.duplicate(true)


## Renderer-independent, component-local evidence for the first eligible Aft
## visual-resource family. A structural submission is one mesh surface; this
## report deliberately makes no frame-time, GPU draw-call, VRAM, whole-scene or
## pixel-equivalence claim.
func get_pod_corner_collar_visual_allocation_audit() -> Dictionary:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var batch_nodes := find_children("*", "MultiMeshInstance3D", true, false)
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var drawn_copies := 0
	var surface_submissions := 0
	for raw_node in mesh_nodes:
		var instance := raw_node as MeshInstance3D
		if instance.mesh == null:
			continue
		drawn_copies += 1
		surface_submissions += instance.mesh.get_surface_count()
		mesh_resource_ids[instance.mesh.get_instance_id()] = true
		if instance.material_override != null:
			material_resource_ids[instance.material_override.get_instance_id()] = true
	for raw_node in batch_nodes:
		var batch := raw_node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var visible_copies := batch.multimesh.visible_instance_count
		if visible_copies < 0:
			visible_copies = batch.multimesh.instance_count
		drawn_copies += visible_copies
		surface_submissions += batch.multimesh.mesh.get_surface_count()
		mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
		if batch.material_override != null:
			material_resource_ids[batch.material_override.get_instance_id()] = true

	var errors := PackedStringArray()
	var family_nodes: Array[MeshInstance3D] = []
	var family_mesh_ids := {}
	var family_material_ids := {}
	var behavior_rows: Array[Dictionary] = []
	var family_visible_copies := 0
	var family_surface_submissions := 0
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(POD_CORNER_COLLAR_FAMILY_META, &"")) \
				!= POD_CORNER_COLLAR_FAMILY_ID:
			continue
		family_nodes.append(instance)
		family_visible_copies += 1 if instance.visible else 0
		if instance.mesh != null:
			family_mesh_ids[instance.mesh.get_instance_id()] = true
			family_surface_submissions += instance.mesh.get_surface_count()
		if instance.material_override != null:
			family_material_ids[instance.material_override.get_instance_id()] = true
		if instance.mesh != _pod_corner_collar_mesh:
			errors.append("pod_corner_collar_mesh_identity_not_shared")
		if (
			instance.material_override != _materials.get("brass")
			or not instance.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			or instance.scale != Vector3.ONE
			or not instance.visible
			or instance.get_child_count() != 0
			or instance.layers != 1
			or instance.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		):
			errors.append("pod_corner_collar_render_state_drift")
		behavior_rows.append({
			"path": String(get_path_to(instance)),
			"position": instance.position,
			"rotation_degrees": instance.rotation_degrees,
		})

	if family_nodes.size() != POD_CORNER_COLLAR_COPY_COUNT:
		errors.append("pod_corner_collar_visual_node_count_drift")
	var transforms_exact := family_nodes.size() == POD_CORNER_COLLAR_POSITIONS.size()
	for index in mini(family_nodes.size(), POD_CORNER_COLLAR_POSITIONS.size()):
		transforms_exact = (
			transforms_exact
			and family_nodes[index].position.is_equal_approx(
				POD_CORNER_COLLAR_POSITIONS[index] as Vector3
			)
		)
	if not transforms_exact:
		errors.append("pod_corner_collar_transform_roster_drift")
	if family_mesh_ids.size() != 1:
		errors.append("pod_corner_collar_mesh_identity_count_drift")
	if family_material_ids.size() != 1:
		errors.append("pod_corner_collar_material_identity_count_drift")
	var authored_tessellation := Vector2i(
		POD_CORNER_COLLAR_RINGS, POD_CORNER_COLLAR_RING_SEGMENTS
	)
	var retained_authored_tessellation := Vector2i.ZERO
	var normalised := (
		_pod_corner_collar_mesh != null
		and _pod_corner_collar_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	if normalised:
		var authored_value: Variant = _pod_corner_collar_mesh.get_meta(
			TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
		)
		if authored_value is Vector2i:
			retained_authored_tessellation = authored_value
	var expected_tessellation := Vector2i(
		POD_CORNER_COLLAR_BUDGETED_RINGS,
		POD_CORNER_COLLAR_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _pod_corner_collar_mesh == null or (
		not is_equal_approx(
			_pod_corner_collar_mesh.inner_radius,
			POD_CORNER_COLLAR_INNER_RADIUS
		)
		or not is_equal_approx(
			_pod_corner_collar_mesh.outer_radius,
			POD_CORNER_COLLAR_OUTER_RADIUS
		)
		or _pod_corner_collar_mesh.rings != expected_tessellation.x
		or _pod_corner_collar_mesh.ring_segments \
				!= expected_tessellation.y
		or (
			normalised
			and retained_authored_tessellation != authored_tessellation
		)
		or _pod_corner_collar_mesh.get_surface_count() != 1
	):
		errors.append("pod_corner_collar_mesh_recipe_drift")

	# Gameplay interaction markers are not render allocations. Keep this visual
	# census scoped to the nodes that can affect the authored draw roster.
	var descendant_nodes := _render_descendant_count()
	var renderer_nodes := mesh_nodes.size() + batch_nodes.size()
	if (
		descendant_nodes != RENDER_DESCENDANT_NODE_COUNT
		or renderer_nodes != RENDERER_NODE_COUNT
		or drawn_copies != DRAWN_COPY_COUNT
		or surface_submissions != SURFACE_SUBMISSION_COUNT
		or mesh_resource_ids.size() != MESH_RESOURCE_COUNT
		or material_resource_ids.size() != MATERIAL_RESOURCE_COUNT
	):
		errors.append("pod_corner_collar_component_allocation_census_drift")

	var legacy := {
		"descendant_nodes": BASELINE_RENDER_DESCENDANT_NODE_COUNT,
		"renderer_nodes": BASELINE_RENDERER_NODE_COUNT,
		"drawn_copies": BASELINE_DRAWN_COPY_COUNT,
		"surface_submissions": BASELINE_SURFACE_SUBMISSION_COUNT,
		"mesh_resource_allocations": BASELINE_MESH_RESOURCE_COUNT,
		"material_resource_allocations": BASELINE_MATERIAL_RESOURCE_COUNT,
		"family_visual_nodes": POD_CORNER_COLLAR_COPY_COUNT,
		"family_visible_copies": POD_CORNER_COLLAR_COPY_COUNT,
		"family_surface_submissions": POD_CORNER_COLLAR_COPY_COUNT,
		"family_mesh_resource_allocations": POD_CORNER_COLLAR_COPY_COUNT,
	}
	var current := {
		"descendant_nodes": descendant_nodes,
		"renderer_nodes": renderer_nodes,
		"drawn_copies": drawn_copies,
		"surface_submissions": surface_submissions,
		"mesh_resource_allocations": mesh_resource_ids.size(),
		"material_resource_allocations": material_resource_ids.size(),
		"family_visual_nodes": family_nodes.size(),
		"family_visible_copies": family_visible_copies,
		"family_surface_submissions": family_surface_submissions,
		"family_mesh_resource_allocations": family_mesh_ids.size(),
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_pod_corner_collar_visuals",
		"selected_family": POD_CORNER_COLLAR_FAMILY_ID,
		"legacy": legacy,
		"current": current,
		"reductions": {
			"descendant_nodes": 35,
			"renderer_nodes": 114,
			"drawn_copies": -16,
			"surface_submissions": 114,
			"mesh_resource_allocations": 24,
			"material_resource_allocations": 0,
		},
		"mesh_recipe": {
			"inner_radius": (
				_pod_corner_collar_mesh.inner_radius
				if _pod_corner_collar_mesh != null else 0.0
			),
			"outer_radius": (
				_pod_corner_collar_mesh.outer_radius
				if _pod_corner_collar_mesh != null else 0.0
			),
			"rings": (
				_pod_corner_collar_mesh.rings
				if _pod_corner_collar_mesh != null else 0
			),
			"ring_segments": (
				_pod_corner_collar_mesh.ring_segments
				if _pod_corner_collar_mesh != null else 0
			),
			"authored_rings": authored_tessellation.x,
			"authored_ring_segments": authored_tessellation.y,
			"normalised": normalised,
			"surface_count": (
				_pod_corner_collar_mesh.get_surface_count()
				if _pod_corner_collar_mesh != null else 0
			),
		},
		"behavior_rows": behavior_rows,
		"batched": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
		"pixel_equivalence_claimed": false,
	}.duplicate(true)


## Detached component-local proof for the two ordinary RoofVentCollar renderers.
## Sharing changes resource identity only: the named nodes, transforms, graphite
## family material, visibility, and zero collision/semantic authority remain.
func get_roof_vent_collar_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var collars: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var paths := PackedStringArray()
	var submissions := 0
	var collision_nodes := 0
	var expected_parent := get_node_or_null(^"Structure/OperationsRoom/VisualPressureEnvelope") as Node3D
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var collar := raw_node as MeshInstance3D
		if StringName(collar.get_meta(ROOF_VENT_COLLAR_FAMILY_META, &"")) != ROOF_VENT_COLLAR_FAMILY_ID:
			continue
		collars.append(collar)
		paths.append(String(get_path_to(collar)))
		if collar.mesh != null:
			mesh_ids[collar.mesh.get_instance_id()] = true
			submissions += collar.mesh.get_surface_count()
		if collar.material_override != null:
			material_ids[collar.material_override.get_instance_id()] = true
		var index := collars.size() - 1
		if collar.mesh != _roof_vent_collar_mesh:
			errors.append("roof_vent_collar_mesh_identity_not_shared")
		if collar.material_override != _materials.get("mid_grey") \
				or index >= ROOF_VENT_COLLAR_POSITIONS.size() \
				or not collar.position.is_equal_approx(ROOF_VENT_COLLAR_POSITIONS[index] as Vector3) \
				or not collar.rotation_degrees.is_equal_approx(Vector3.ZERO) \
				or collar.scale != Vector3.ONE \
				or not collar.visible \
				or collar.get_parent() != expected_parent \
				or collar.get_child_count() != 0 \
				or collar.get_script() != null:
			errors.append("roof_vent_collar_render_state_drift")
		collision_nodes += collar.find_children("*", "CollisionObject3D", true, false).size()
		collision_nodes += collar.find_children("*", "CollisionShape3D", true, false).size()
	if collars.size() != ROOF_VENT_COLLAR_COPY_COUNT:
		errors.append("roof_vent_collar_visual_node_count_drift")
	if mesh_ids.size() != 1:
		errors.append("roof_vent_collar_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("roof_vent_collar_material_identity_drift")
	if collision_nodes != 0:
		errors.append("roof_vent_collar_gained_collision_authority")
	var normalised := _roof_vent_collar_mesh != null and _roof_vent_collar_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	var live_tessellation := Vector2i(ROOF_VENT_COLLAR_BUDGETED_RINGS, ROOF_VENT_COLLAR_BUDGETED_RING_SEGMENTS) if normalised else Vector2i(ROOF_VENT_COLLAR_RINGS, ROOF_VENT_COLLAR_RING_SEGMENTS)
	var metadata_exact: bool = _roof_vent_collar_mesh != null and (
		(_roof_vent_collar_mesh.get_meta_list().is_empty() if not normalised else (
			_roof_vent_collar_mesh.get_meta_list().size() == 1
			and _roof_vent_collar_mesh.get_meta_list().has(TorusGeometryBudget.AUTHORED_META)
			and _roof_vent_collar_mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) == Vector2i(ROOF_VENT_COLLAR_RINGS, ROOF_VENT_COLLAR_RING_SEGMENTS)
		))
	)
	if _roof_vent_collar_mesh == null \
			or not is_equal_approx(_roof_vent_collar_mesh.inner_radius, ROOF_VENT_COLLAR_INNER_RADIUS) \
			or not is_equal_approx(_roof_vent_collar_mesh.outer_radius, ROOF_VENT_COLLAR_OUTER_RADIUS) \
			or _roof_vent_collar_mesh.rings != live_tessellation.x \
			or _roof_vent_collar_mesh.ring_segments != live_tessellation.y \
			or _roof_vent_collar_mesh.get_surface_count() != 1 \
			or _roof_vent_collar_mesh.material != null \
			or _roof_vent_collar_mesh.resource_local_to_scene \
			or not metadata_exact:
		errors.append("roof_vent_collar_torus_recipe_drift")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(), "errors": errors,
		"scope": &"aft_junction_stack_roof_vent_collar_visuals",
		"legacy": {"visual_nodes": 2, "drawn_copies": 2, "surface_submissions": 2, "mesh_resource_allocations": 2, "material_resource_allocations": 1},
		"current": {"visual_nodes": collars.size(), "drawn_copies": collars.size(), "surface_submissions": submissions, "mesh_resource_allocations": mesh_ids.size(), "material_resource_allocations": material_ids.size()},
		"reductions": {"visual_nodes": 0, "drawn_copies": 0, "surface_submissions": 0, "mesh_resource_allocations": 1, "material_resource_allocations": 0},
		"node_paths": paths, "collision_authority_count": collision_nodes,
		"authored_tessellation": Vector2i(ROOF_VENT_COLLAR_RINGS, ROOF_VENT_COLLAR_RING_SEGMENTS), "live_tessellation": live_tessellation, "normalised": normalised, "metadata_exact": metadata_exact,
		"batched": false, "renderer_values_changed": false,
	}.duplicate(true)


## Detached component-local proof for the five ordinary SpineClamp renderer
## nodes. Sharing changes resource allocation only: node paths, copies,
## submissions, transforms, render state and the global torus-budget seam stay
## exactly as authored.
func get_spine_clamp_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var family_nodes: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var node_paths := PackedStringArray()
	var transforms: Array[Transform3D] = []
	var surface_submissions := 0
	var visible_copies := 0
	var collision_nodes := 0
	var authority_nodes := 0
	var expected_parent := get_node_or_null(
		^"Structure/OperationsRoom/VisualPressureEnvelope"
	) as Node3D
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			TorusGeometryBudget.PROFILE_META, &""
		)) != TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			continue
		if StringName(instance.get_meta(INTERFACE_COLLAR_KIND_META, &"")) \
				!= &"SpineClamp":
			continue
		family_nodes.append(instance)
		node_paths.append(String(get_path_to(instance)))
		transforms.append(instance.transform)
		visible_copies += 1 if instance.visible else 0
		if instance.mesh != null:
			mesh_ids[instance.mesh.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
		if instance.material_override != null:
			material_ids[instance.material_override.get_instance_id()] = true
		if instance.mesh != _spine_clamp_mesh:
			errors.append("spine_clamp_mesh_identity_not_shared")
		if instance.material_override != _materials.get("copper"):
			errors.append("spine_clamp_material_identity_drift")
		var family_index := family_nodes.size() - 1
		if family_index >= SPINE_CLAMP_POSITIONS.size() \
				or not instance.position.is_equal_approx(
					SPINE_CLAMP_POSITIONS[family_index] as Vector3
				) \
				or not instance.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0)) \
				or instance.scale != Vector3.ONE:
			errors.append("spine_clamp_transform_drift")
		if not instance.visible \
				or instance.layers != 1 \
				or instance.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or instance.material_overlay != null \
				or not is_zero_approx(instance.transparency):
			errors.append("spine_clamp_renderer_state_drift")
		var metadata_keys := instance.get_meta_list()
		var exact_metadata := (
			metadata_keys.size() == 2
			and metadata_keys.has(TorusGeometryBudget.PROFILE_META)
			and metadata_keys.has(INTERFACE_COLLAR_KIND_META)
			and StringName(instance.get_meta(
				TorusGeometryBudget.PROFILE_META, &""
			)) == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
			and StringName(instance.get_meta(
				INTERFACE_COLLAR_KIND_META, &""
			)) == &"SpineClamp"
		)
		var gained_authority := (
			instance.get_parent() != expected_parent
			or instance.get_child_count() != 0
			or instance.get_script() != null
			or not instance.get_groups().is_empty()
			or not exact_metadata
		)
		if gained_authority:
			authority_nodes += 1
			errors.append("spine_clamp_gained_authority_or_lifecycle")
		collision_nodes += instance.find_children(
			"*", "CollisionObject3D", true, false
		).size()
		collision_nodes += instance.find_children(
			"*", "CollisionShape3D", true, false
		).size()

	if family_nodes.size() != SPINE_CLAMP_COPY_COUNT:
		errors.append("spine_clamp_visual_node_count_drift")
	var stable_paths := family_nodes.size() == SPINE_CLAMP_COPY_COUNT
	if stable_paths:
		stable_paths = node_paths[0] \
			== "Structure/OperationsRoom/VisualPressureEnvelope/SpineClamp"
		for index in range(1, node_paths.size()):
			stable_paths = stable_paths and String(family_nodes[index].name).begins_with(
				"@MeshInstance3D@"
			)
	if not stable_paths:
		errors.append("spine_clamp_node_path_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("spine_clamp_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("spine_clamp_material_identity_drift")
	if collision_nodes != 0:
		errors.append("spine_clamp_gained_collision_authority")

	var authored_tessellation := Vector2i(
		SPINE_CLAMP_RINGS, SPINE_CLAMP_RING_SEGMENTS
	)
	var normalised := (
		_spine_clamp_mesh != null
		and _spine_clamp_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	var live_tessellation := Vector2i(
		SPINE_CLAMP_BUDGETED_RINGS,
		SPINE_CLAMP_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _spine_clamp_mesh == null \
			or not is_equal_approx(
				_spine_clamp_mesh.inner_radius, SPINE_CLAMP_INNER_RADIUS
			) \
			or not is_equal_approx(
				_spine_clamp_mesh.outer_radius, SPINE_CLAMP_OUTER_RADIUS
			) \
			or _spine_clamp_mesh.rings != live_tessellation.x \
			or _spine_clamp_mesh.ring_segments != live_tessellation.y \
			or _spine_clamp_mesh.get_surface_count() != 1:
		errors.append("spine_clamp_torus_recipe_drift")
	var mesh_metadata: Array[StringName] = []
	if _spine_clamp_mesh != null:
		mesh_metadata = _spine_clamp_mesh.get_meta_list()
	var exact_mesh_metadata: bool = (
		_spine_clamp_mesh != null
		and _spine_clamp_mesh.material == null
		and not _spine_clamp_mesh.resource_local_to_scene
		and (
			(
				not normalised
				and mesh_metadata.is_empty()
			) or (
				normalised
				and mesh_metadata.size() == 1
				and mesh_metadata.has(TorusGeometryBudget.AUTHORED_META)
				and _spine_clamp_mesh.get_meta(
					TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
				) == authored_tessellation
			)
		)
	)
	if not exact_mesh_metadata:
		errors.append("spine_clamp_budget_metadata_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_spine_clamp_visuals",
		"legacy": {
			"visual_nodes": SPINE_CLAMP_COPY_COUNT,
			"drawn_copies": SPINE_CLAMP_COPY_COUNT,
			"surface_submissions": SPINE_CLAMP_COPY_COUNT,
			"mesh_resource_allocations": SPINE_CLAMP_COPY_COUNT,
			"material_resource_allocations": 1,
		},
		"current": {
			"visual_nodes": family_nodes.size(),
			"drawn_copies": visible_copies,
			"surface_submissions": surface_submissions,
			"mesh_resource_allocations": mesh_ids.size(),
			"material_resource_allocations": material_ids.size(),
		},
		"reductions": {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 4,
			"material_resource_allocations": 0,
		},
		"node_paths": node_paths,
		"authored_transforms": transforms,
		"authored_tessellation": authored_tessellation,
		"live_tessellation": Vector2i(
			_spine_clamp_mesh.rings, _spine_clamp_mesh.ring_segments
		) if _spine_clamp_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"material_identity_preserved": material_ids.size() == 1,
		"collision_authority_count": collision_nodes,
		"semantic_authority_count": authority_nodes,
		"batched": false,
		"renderer_values_changed": false,
	}.duplicate(true)


## Detached component-local proof for the four ordinary RackCableTrayClamp
## renderers. Sharing changes resource identity only; all authored nodes,
## submissions, transforms and budget ownership remain unchanged.
func get_rack_cable_tray_clamp_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var family_nodes: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var node_paths := PackedStringArray()
	var transforms: Array[Transform3D] = []
	var surface_submissions := 0
	var visible_copies := 0
	var collision_nodes := 0
	var authority_nodes := 0
	var expected_parent := get_node_or_null(
		^"Structure/OperationsRoom/OperationsContent/WatchRackBank"
	) as Node3D
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			TorusGeometryBudget.PROFILE_META, &""
		)) != TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			continue
		if StringName(instance.get_meta(INTERFACE_COLLAR_KIND_META, &"")) \
				!= &"RackCableTrayClamp":
			continue
		family_nodes.append(instance)
		node_paths.append(String(get_path_to(instance)))
		transforms.append(instance.transform)
		visible_copies += 1 if instance.visible else 0
		if instance.mesh != null:
			mesh_ids[instance.mesh.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
		if instance.material_override != null:
			material_ids[instance.material_override.get_instance_id()] = true
		if instance.mesh != _rack_cable_tray_clamp_mesh:
			errors.append("rack_cable_tray_clamp_mesh_identity_not_shared")
		if instance.material_override != _materials.get("brass"):
			errors.append("rack_cable_tray_clamp_material_identity_drift")
		var family_index := family_nodes.size() - 1
		if family_index >= RACK_CABLE_TRAY_CLAMP_POSITIONS.size() \
				or not instance.position.is_equal_approx(
					RACK_CABLE_TRAY_CLAMP_POSITIONS[family_index] as Vector3
				) \
				or not instance.rotation_degrees.is_equal_approx(Vector3(0.0, 0.0, 90.0)) \
				or instance.scale != Vector3.ONE:
			errors.append("rack_cable_tray_clamp_transform_drift")
		if not instance.visible \
				or instance.layers != 1 \
				or instance.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or instance.material_overlay != null \
				or not is_zero_approx(instance.transparency):
			errors.append("rack_cable_tray_clamp_renderer_state_drift")
		var metadata_keys := instance.get_meta_list()
		var exact_metadata := (
			metadata_keys.size() == 2
			and metadata_keys.has(TorusGeometryBudget.PROFILE_META)
			and metadata_keys.has(INTERFACE_COLLAR_KIND_META)
			and StringName(instance.get_meta(
				TorusGeometryBudget.PROFILE_META, &""
			)) == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
			and StringName(instance.get_meta(
				INTERFACE_COLLAR_KIND_META, &""
			)) == &"RackCableTrayClamp"
		)
		var gained_authority := (
			instance.get_parent() != expected_parent
			or instance.get_child_count() != 0
			or instance.get_script() != null
			or not instance.get_groups().is_empty()
			or not exact_metadata
		)
		if gained_authority:
			authority_nodes += 1
			errors.append("rack_cable_tray_clamp_gained_authority_or_lifecycle")
		collision_nodes += instance.find_children(
			"*", "CollisionObject3D", true, false
		).size()
		collision_nodes += instance.find_children(
			"*", "CollisionShape3D", true, false
		).size()

	if family_nodes.size() != RACK_CABLE_TRAY_CLAMP_COPY_COUNT:
		errors.append("rack_cable_tray_clamp_visual_node_count_drift")
	var stable_paths := family_nodes.size() == RACK_CABLE_TRAY_CLAMP_COPY_COUNT
	if stable_paths:
		stable_paths = node_paths[0] == (
			"Structure/OperationsRoom/OperationsContent/WatchRackBank/"
			+ "RackCableTrayClamp"
		)
		for index in range(1, node_paths.size()):
			stable_paths = stable_paths and String(family_nodes[index].name).begins_with(
				"@MeshInstance3D@"
			)
	if not stable_paths:
		errors.append("rack_cable_tray_clamp_node_path_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("rack_cable_tray_clamp_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("rack_cable_tray_clamp_material_identity_drift")
	if collision_nodes != 0:
		errors.append("rack_cable_tray_clamp_gained_collision_authority")

	var authored_tessellation := Vector2i(
		RACK_CABLE_TRAY_CLAMP_RINGS,
		RACK_CABLE_TRAY_CLAMP_RING_SEGMENTS
	)
	var normalised := (
		_rack_cable_tray_clamp_mesh != null
		and _rack_cable_tray_clamp_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	var live_tessellation := Vector2i(
		RACK_CABLE_TRAY_CLAMP_BUDGETED_RINGS,
		RACK_CABLE_TRAY_CLAMP_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _rack_cable_tray_clamp_mesh == null \
			or not is_equal_approx(
				_rack_cable_tray_clamp_mesh.inner_radius,
				RACK_CABLE_TRAY_CLAMP_INNER_RADIUS
			) \
			or not is_equal_approx(
				_rack_cable_tray_clamp_mesh.outer_radius,
				RACK_CABLE_TRAY_CLAMP_OUTER_RADIUS
			) \
			or _rack_cable_tray_clamp_mesh.rings != live_tessellation.x \
			or _rack_cable_tray_clamp_mesh.ring_segments != live_tessellation.y \
			or _rack_cable_tray_clamp_mesh.get_surface_count() != 1:
		errors.append("rack_cable_tray_clamp_torus_recipe_drift")
	var mesh_metadata: Array[StringName] = []
	if _rack_cable_tray_clamp_mesh != null:
		mesh_metadata = _rack_cable_tray_clamp_mesh.get_meta_list()
	var exact_mesh_metadata: bool = (
		_rack_cable_tray_clamp_mesh != null
		and _rack_cable_tray_clamp_mesh.material == null
		and not _rack_cable_tray_clamp_mesh.resource_local_to_scene
		and (
			(not normalised and mesh_metadata.is_empty())
			or (
				normalised
				and mesh_metadata.size() == 1
				and mesh_metadata.has(TorusGeometryBudget.AUTHORED_META)
				and _rack_cable_tray_clamp_mesh.get_meta(
					TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
				) == authored_tessellation
			)
		)
	)
	if not exact_mesh_metadata:
		errors.append("rack_cable_tray_clamp_budget_metadata_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_rack_cable_tray_clamp_visuals",
		"legacy": {
			"visual_nodes": RACK_CABLE_TRAY_CLAMP_COPY_COUNT,
			"drawn_copies": RACK_CABLE_TRAY_CLAMP_COPY_COUNT,
			"surface_submissions": RACK_CABLE_TRAY_CLAMP_COPY_COUNT,
			"mesh_resource_allocations": RACK_CABLE_TRAY_CLAMP_COPY_COUNT,
			"material_resource_allocations": 1,
		},
		"current": {
			"visual_nodes": family_nodes.size(),
			"drawn_copies": visible_copies,
			"surface_submissions": surface_submissions,
			"mesh_resource_allocations": mesh_ids.size(),
			"material_resource_allocations": material_ids.size(),
		},
		"reductions": {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 0,
		},
		"node_paths": node_paths,
		"authored_transforms": transforms,
		"authored_tessellation": authored_tessellation,
		"live_tessellation": Vector2i(
			_rack_cable_tray_clamp_mesh.rings,
			_rack_cable_tray_clamp_mesh.ring_segments
		) if _rack_cable_tray_clamp_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"material_identity_preserved": material_ids.size() == 1,
		"collision_authority_count": collision_nodes,
		"semantic_authority_count": authority_nodes,
		"batched": false,
		"renderer_values_changed": false,
	}.duplicate(true)


## Detached proof for the twelve decorative service-cabinet fasteners. Stable
## Marker3D anchors preserve paths/poses while one inert renderer owns the copies.
func get_cabinet_fastener_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var service := get_node_or_null(
		^"Structure/OperationsRoom/ServiceWall"
	) as Node3D
	var expected := _cabinet_fastener_transforms()
	var anchors: Array[Marker3D] = []
	if service != null:
		for child in service.get_children():
			if child is Marker3D and str(child.name).begins_with("CabinetFastener"):
				anchors.append(child as Marker3D)
	var anchors_exact := anchors.size() == expected.size()
	for index in mini(anchors.size(), expected.size()):
		anchors_exact = anchors_exact \
			and anchors[index].transform.is_equal_approx(expected[index]) \
			and anchors[index].get_child_count() == 0 \
			and anchors[index].get_script() == null \
			and anchors[index].get_groups().is_empty() \
			and anchors[index].get_meta_list().is_empty()
	if not anchors_exact:
		errors.append("cabinet_fastener_anchor_roster_or_transform_drift")
	var batch := _cabinet_fastener_batch
	var multimesh := batch.multimesh if batch != null else null
	var expected_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.035, 0.035, 0.028, 32, _chamfered_cylinder_cache
	)
	var expected_buffer := _encode_multimesh_transforms(expected)
	if batch == null or multimesh == null:
		errors.append("cabinet_fastener_batch_missing")
	else:
		if batch.get_parent() != service or batch.name != &"CabinetFastenerRenderBatch":
			errors.append("cabinet_fastener_batch_path_drift")
		if multimesh.mesh != expected_mesh:
			errors.append("cabinet_fastener_mesh_identity_drift")
		if multimesh.instance_count != 12 or multimesh.visible_instance_count != 12:
			errors.append("cabinet_fastener_copy_count_drift")
		if multimesh.buffer != expected_buffer:
			errors.append("cabinet_fastener_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(
			_transformed_mesh_bounds(expected_mesh.get_aabb(), expected)
		):
			errors.append("cabinet_fastener_culling_bounds_drift")
		if batch.material_override != _materials.get("brass") \
				or not batch.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not batch.visible or batch.layers != 1 \
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("cabinet_fastener_renderer_state_drift")
		if batch.get_child_count() != 0 or batch.get_script() != null \
				or not batch.get_groups().is_empty() \
				or batch.get_meta_list().size() != 2 \
				or not bool(batch.get_meta("visual_detail_only", false)) \
				or not _transform_arrays_match(
					batch.get_meta("authored_instance_transforms", []) as Array, expected
				):
			errors.append("cabinet_fastener_gained_authority_or_lifecycle")
	if service != null and not service.find_children(
		"CabinetFastener*", "MeshInstance3D", false, false
	).is_empty():
		errors.append("cabinet_fastener_legacy_renderer_present")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy_renderer_nodes": 12,
		"renderer_nodes": 1 if batch != null else 0,
		"legacy_surface_submissions": 12,
		"surface_submissions": 1 if multimesh != null else 0,
		"drawn_copies": multimesh.visible_instance_count if multimesh != null else 0,
		"stable_anchor_nodes": anchors.size(),
		"renderer_buffer": expected_buffer.duplicate(),
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"collision_authority_count": 0,
		"interaction_authority_count": 0,
	}.duplicate(true)


## Detached proof for the six ConsoleShockCollar copies. Bay-local Marker3D
## anchors preserve exact paths/poses while one room-local renderer submits the
## immutable torus family. Adjacent copper mounts retain physical authority.
func get_console_shock_collar_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var room := get_node_or_null(^"Structure/OperationsRoom") as Node3D
	var anchors: Array[Marker3D] = []
	var anchor_paths := PackedStringArray()
	var anchor_local_transforms: Array[Transform3D] = []
	var anchors_exact := room != null
	for bay_index in 3:
		var bay := get_node_or_null(NodePath(
			"Structure/OperationsRoom/ConsoleBay%02d" % (bay_index + 1)
		)) as Node3D
		var bay_anchors: Array[Marker3D] = []
		if bay != null:
			for child in bay.get_children():
				# Godot gives the second same-named internal anchor an @Marker3D@
				# name. Both Marker3D children are this visual family's frozen
				# bay-local anchors; the bay has no semantic Marker3D children.
				if child is Marker3D:
					bay_anchors.append(child as Marker3D)
		anchors_exact = anchors_exact and bay != null and bay_anchors.size() == 2
		for side_index in bay_anchors.size():
			var anchor := bay_anchors[side_index]
			var flat_index := bay_index * 2 + side_index
			anchors.append(anchor)
			anchor_paths.append(String(get_path_to(anchor)))
			anchor_local_transforms.append(anchor.transform)
			anchors_exact = anchors_exact \
				and flat_index < CONSOLE_SHOCK_COLLAR_LOCAL_POSITIONS.size() \
				and anchor.position.is_equal_approx(
					CONSOLE_SHOCK_COLLAR_LOCAL_POSITIONS[flat_index] as Vector3
				) \
				and anchor.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0)) \
				and anchor.scale == Vector3.ONE \
				and anchor.get_child_count() == 0 \
				and anchor.get_script() == null \
				and anchor.get_groups().is_empty() \
				and anchor.get_meta_list().is_empty()
	if not anchors_exact or anchors.size() != CONSOLE_SHOCK_COLLAR_COPY_COUNT:
		errors.append("console_shock_collar_anchor_roster_or_transform_drift")

	var batch := _console_shock_collar_batch
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh as TorusMesh if multimesh != null else null
	var expected_transforms := _console_shock_collar_transforms()
	var expected_buffer := _encode_multimesh_transforms(expected_transforms)
	var expected_bounds := _transformed_mesh_bounds(
		_console_shock_collar_mesh.get_aabb(), expected_transforms
	) if _console_shock_collar_mesh != null else AABB()
	var semantic_authority_count := 0
	if batch == null or multimesh == null or mesh == null:
		errors.append("console_shock_collar_batch_missing")
	else:
		if batch.get_parent() != room or str(batch.name) != "ConsoleShockCollarRenderBatch":
			errors.append("console_shock_collar_batch_path_drift")
		if multimesh.transform_format != MultiMesh.TRANSFORM_3D \
				or multimesh.use_colors or multimesh.use_custom_data:
			errors.append("console_shock_collar_multimesh_format_drift")
		if multimesh.instance_count != CONSOLE_SHOCK_COLLAR_COPY_COUNT \
				or multimesh.visible_instance_count != CONSOLE_SHOCK_COLLAR_COPY_COUNT:
			errors.append("console_shock_collar_visible_copy_roster_drift")
		if multimesh.buffer != expected_buffer:
			errors.append("console_shock_collar_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("console_shock_collar_culling_bounds_drift")
		if mesh != _console_shock_collar_mesh:
			errors.append("console_shock_collar_mesh_identity_not_shared")
		if batch.material_override != _materials.get("rubber"):
			errors.append("console_shock_collar_material_identity_drift")
		if batch.transform != Transform3D.IDENTITY or not batch.visible \
				or batch.layers != 1 \
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or batch.material_overlay != null or not is_zero_approx(batch.transparency):
			errors.append("console_shock_collar_renderer_state_drift")
		var metadata_keys := batch.get_meta_list()
		if batch.get_child_count() != 0 or batch.get_script() != null \
				or not batch.get_groups().is_empty() \
				or metadata_keys.size() != 2 \
				or not metadata_keys.has(&"visual_detail_only") \
				or not metadata_keys.has(&"authored_instance_transforms") \
				or not bool(batch.get_meta("visual_detail_only", false)) \
				or not _transform_arrays_match(
					batch.get_meta("authored_instance_transforms", []) as Array,
					expected_transforms
				):
			semantic_authority_count = 1
			errors.append("console_shock_collar_gained_authority_or_lifecycle")

	var authored_tessellation := Vector2i(
		CONSOLE_SHOCK_COLLAR_RINGS,
		CONSOLE_SHOCK_COLLAR_RING_SEGMENTS
	)
	var normalised := (
		_console_shock_collar_mesh != null
		and _console_shock_collar_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	var live_tessellation := Vector2i(
		CONSOLE_SHOCK_COLLAR_BUDGETED_RINGS,
		CONSOLE_SHOCK_COLLAR_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _console_shock_collar_mesh == null \
			or not is_equal_approx(
				_console_shock_collar_mesh.inner_radius,
				CONSOLE_SHOCK_COLLAR_INNER_RADIUS
			) \
			or not is_equal_approx(
				_console_shock_collar_mesh.outer_radius,
				CONSOLE_SHOCK_COLLAR_OUTER_RADIUS
			) \
			or _console_shock_collar_mesh.rings != live_tessellation.x \
			or _console_shock_collar_mesh.ring_segments != live_tessellation.y \
			or _console_shock_collar_mesh.get_surface_count() != 1:
		errors.append("console_shock_collar_torus_recipe_drift")
	var mesh_metadata: Array[StringName] = []
	if _console_shock_collar_mesh != null:
		mesh_metadata = _console_shock_collar_mesh.get_meta_list()
	var exact_mesh_metadata: bool = (
		_console_shock_collar_mesh != null
		and _console_shock_collar_mesh.material == null
		and not _console_shock_collar_mesh.resource_local_to_scene
		and (
			(not normalised and mesh_metadata.is_empty())
			or (
				normalised
				and mesh_metadata.size() == 1
				and mesh_metadata.has(TorusGeometryBudget.AUTHORED_META)
				and _console_shock_collar_mesh.get_meta(
					TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
				) == authored_tessellation
			)
		)
	)
	if not exact_mesh_metadata:
		errors.append("console_shock_collar_budget_metadata_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_console_shock_collar_visuals",
		"legacy": {
			"visual_nodes": CONSOLE_SHOCK_COLLAR_COPY_COUNT,
			"renderer_nodes": CONSOLE_SHOCK_COLLAR_COPY_COUNT,
			"drawn_copies": CONSOLE_SHOCK_COLLAR_COPY_COUNT,
			"surface_submissions": CONSOLE_SHOCK_COLLAR_COPY_COUNT,
			# The immediately preceding sharing pass already held one immutable
			# recipe. This audit freezes the incremental batching delta honestly.
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		},
		"current": {
			"visual_nodes": anchors.size() + (1 if batch != null else 0),
			"stable_anchor_nodes": anchors.size(),
			"renderer_nodes": 1 if batch != null else 0,
			"drawn_copies": multimesh.visible_instance_count if multimesh != null else 0,
			"surface_submissions": mesh.get_surface_count() if mesh != null else 0,
			"mesh_resource_allocations": 1 if mesh != null else 0,
			"material_resource_allocations": 1 if batch != null and batch.material_override != null else 0,
		},
		"reductions": {
			"visual_nodes": -1,
			"renderer_nodes": 5,
			"drawn_copies": 0,
			"surface_submissions": 5,
			"mesh_resource_allocations": 0,
			"material_resource_allocations": 0,
		},
		"node_paths": anchor_paths,
		"anchor_local_transforms": anchor_local_transforms,
		"authored_transforms": expected_transforms,
		"renderer_buffer": expected_buffer,
		"renderer_buffer_float_count": multimesh.buffer.size() if multimesh != null else 0,
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"authored_tessellation": authored_tessellation,
		"live_tessellation": Vector2i(
			_console_shock_collar_mesh.rings,
			_console_shock_collar_mesh.ring_segments
		) if _console_shock_collar_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"material_identity_preserved": batch != null and batch.material_override == _materials.get("rubber"),
		"collision_authority_count": 0,
		"semantic_authority_count": semantic_authority_count,
		"batched": true,
		"renderer_values_changed": false,
	}.duplicate(true)


## Detached component-local proof for the four ordinary PedestalBearing
## renderers. The visual rings share one mesh; every chair keeps its own
## collision-backed Pedestal sibling and all semantic metadata remains on the
## chair rather than moving onto the presentation-only bearing.
func get_pedestal_bearing_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var family_nodes: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var node_paths := PackedStringArray()
	var transforms: Array[Transform3D] = []
	var surface_submissions := 0
	var visible_copies := 0
	var collision_nodes := 0
	var authority_nodes := 0
	var pedestal_collision_bodies := 0
	var pedestal_collision_shapes := 0
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			TorusGeometryBudget.PROFILE_META, &""
		)) != TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			continue
		if StringName(instance.get_meta(INTERFACE_COLLAR_KIND_META, &"")) \
				!= &"PedestalBearing":
			continue
		family_nodes.append(instance)
		node_paths.append(String(get_path_to(instance)))
		transforms.append(instance.transform)
		visible_copies += 1 if instance.visible else 0
		if instance.mesh != null:
			mesh_ids[instance.mesh.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
		if instance.material_override != null:
			material_ids[instance.material_override.get_instance_id()] = true
		if instance.mesh != _pedestal_bearing_mesh:
			errors.append("pedestal_bearing_mesh_identity_not_shared")
		if instance.material_override != _materials.get("copper"):
			errors.append("pedestal_bearing_material_identity_drift")
		if not instance.position.is_equal_approx(PEDESTAL_BEARING_LOCAL_POSITION) \
				or not instance.rotation_degrees.is_equal_approx(Vector3.ZERO) \
				or instance.scale != Vector3.ONE:
			errors.append("pedestal_bearing_transform_drift")
		if not instance.visible \
				or instance.layers != 1 \
				or instance.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or instance.material_overlay != null \
				or not is_zero_approx(instance.transparency):
			errors.append("pedestal_bearing_renderer_state_drift")

		var family_index := family_nodes.size() - 1
		var chair_path := "Structure/OperationsRoom/OperationsChair%02d" % (
			family_index + 1
		)
		var expected_parent := get_node_or_null(NodePath(chair_path)) as Node3D
		var metadata_keys := instance.get_meta_list()
		var exact_metadata := (
			metadata_keys.size() == 2
			and metadata_keys.has(TorusGeometryBudget.PROFILE_META)
			and metadata_keys.has(INTERFACE_COLLAR_KIND_META)
			and StringName(instance.get_meta(
				TorusGeometryBudget.PROFILE_META, &""
			)) == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
			and StringName(instance.get_meta(
				INTERFACE_COLLAR_KIND_META, &""
			)) == &"PedestalBearing"
		)
		var gained_authority := (
			instance.get_parent() != expected_parent
			or instance.get_child_count() != 0
			or instance.get_script() != null
			or not instance.get_groups().is_empty()
			or not exact_metadata
		)
		if gained_authority:
			authority_nodes += 1
			errors.append("pedestal_bearing_gained_authority_or_lifecycle")
		collision_nodes += instance.find_children(
			"*", "CollisionObject3D", true, false
		).size()
		collision_nodes += instance.find_children(
			"*", "CollisionShape3D", true, false
		).size()

		var pedestal := (
			expected_parent.get_node_or_null(^"Pedestal") as StaticBody3D
			if expected_parent != null else null
		)
		var collision_shapes := (
			pedestal.find_children("*", "CollisionShape3D", true, false)
			if pedestal != null else []
		)
		var pedestal_shape := (
			collision_shapes[0] as CollisionShape3D
			if collision_shapes.size() == 1 else null
		)
		var cylinder_shape := (
			pedestal_shape.shape as CylinderShape3D
			if pedestal_shape != null else null
		)
		var exact_pedestal_collision := (
			pedestal != null
			and pedestal != instance
			and pedestal.get_parent() == expected_parent
			and pedestal.position.is_equal_approx(Vector3(0.0, 0.38, 0.0))
			and pedestal.rotation_degrees.is_equal_approx(Vector3.ZERO)
			and pedestal.scale == Vector3.ONE
			and pedestal.collision_layer == WORLD_LAYER
			and pedestal.collision_mask == 0
			and pedestal_shape != null
			and not pedestal_shape.disabled
			and cylinder_shape != null
			and is_equal_approx(cylinder_shape.radius, 0.18)
			and is_equal_approx(cylinder_shape.height, 0.76)
		)
		if exact_pedestal_collision:
			pedestal_collision_bodies += 1
			pedestal_collision_shapes += 1
		else:
			errors.append("pedestal_bearing_support_collision_drift")

	if family_nodes.size() != PEDESTAL_BEARING_COPY_COUNT:
		errors.append("pedestal_bearing_visual_node_count_drift")
	var stable_paths := family_nodes.size() == PEDESTAL_BEARING_COPY_COUNT
	if stable_paths:
		for index in family_nodes.size():
			stable_paths = (
				stable_paths
				and String(node_paths[index]) == (
					"Structure/OperationsRoom/OperationsChair%02d/PedestalBearing"
					% (index + 1)
				)
			)
	if not stable_paths:
		errors.append("pedestal_bearing_node_path_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("pedestal_bearing_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("pedestal_bearing_material_identity_drift")
	if collision_nodes != 0:
		errors.append("pedestal_bearing_gained_collision_authority")
	if pedestal_collision_bodies != PEDESTAL_BEARING_COPY_COUNT \
			or pedestal_collision_shapes != PEDESTAL_BEARING_COPY_COUNT:
		errors.append("pedestal_bearing_support_collision_roster_drift")

	var authored_tessellation := Vector2i(
		PEDESTAL_BEARING_RINGS,
		PEDESTAL_BEARING_RING_SEGMENTS
	)
	var normalised := (
		_pedestal_bearing_mesh != null
		and _pedestal_bearing_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	var live_tessellation := Vector2i(
		PEDESTAL_BEARING_BUDGETED_RINGS,
		PEDESTAL_BEARING_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _pedestal_bearing_mesh == null \
			or not is_equal_approx(
				_pedestal_bearing_mesh.inner_radius,
				PEDESTAL_BEARING_INNER_RADIUS
			) \
			or not is_equal_approx(
				_pedestal_bearing_mesh.outer_radius,
				PEDESTAL_BEARING_OUTER_RADIUS
			) \
			or _pedestal_bearing_mesh.rings != live_tessellation.x \
			or _pedestal_bearing_mesh.ring_segments != live_tessellation.y \
			or _pedestal_bearing_mesh.get_surface_count() != 1:
		errors.append("pedestal_bearing_torus_recipe_drift")
	var mesh_metadata: Array[StringName] = []
	if _pedestal_bearing_mesh != null:
		mesh_metadata = _pedestal_bearing_mesh.get_meta_list()
	var exact_mesh_metadata: bool = (
		_pedestal_bearing_mesh != null
		and _pedestal_bearing_mesh.material == null
		and not _pedestal_bearing_mesh.resource_local_to_scene
		and (
			(not normalised and mesh_metadata.is_empty())
			or (
				normalised
				and mesh_metadata.size() == 1
				and mesh_metadata.has(TorusGeometryBudget.AUTHORED_META)
				and _pedestal_bearing_mesh.get_meta(
					TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
				) == authored_tessellation
			)
		)
	)
	if not exact_mesh_metadata:
		errors.append("pedestal_bearing_budget_metadata_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_pedestal_bearing_visuals",
		"legacy": {
			"visual_nodes": PEDESTAL_BEARING_COPY_COUNT,
			"drawn_copies": PEDESTAL_BEARING_COPY_COUNT,
			"surface_submissions": PEDESTAL_BEARING_COPY_COUNT,
			"mesh_resource_allocations": PEDESTAL_BEARING_COPY_COUNT,
			"material_resource_allocations": 1,
		},
		"current": {
			"visual_nodes": family_nodes.size(),
			"drawn_copies": visible_copies,
			"surface_submissions": surface_submissions,
			"mesh_resource_allocations": mesh_ids.size(),
			"material_resource_allocations": material_ids.size(),
		},
		"reductions": {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 3,
			"material_resource_allocations": 0,
		},
		"node_paths": node_paths,
		"authored_transforms": transforms,
		"authored_tessellation": authored_tessellation,
		"live_tessellation": Vector2i(
			_pedestal_bearing_mesh.rings,
			_pedestal_bearing_mesh.ring_segments
		) if _pedestal_bearing_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"material_identity_preserved": material_ids.size() == 1,
		"collision_authority_count": collision_nodes,
		"semantic_authority_count": authority_nodes,
		"pedestal_collision_body_count": pedestal_collision_bodies,
		"pedestal_collision_shape_count": pedestal_collision_shapes,
		"batched": false,
		"renderer_values_changed": false,
	}.duplicate(true)


## Detached component-local proof for the three ordinary ConduitCollar
## renderers. Repository eligibility found no path/name consumer beyond the
## generic interface profile; sharing therefore changes resource identity only,
## while all ordinary nodes, submissions and renderer values remain authored.
## Detached allocation proof for the four exterior utility-feed clamps. The
## copper feed remains the authored visual run; these childless collars add no
## collision, interaction, door, traversal, console, or lifecycle authority.
func get_exterior_pipe_clamp_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var clamps: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var collisions := 0
	var expected_parent := get_node_or_null(
		^"Structure/OperationsRoom/VisualPressureEnvelope"
	) as Node3D
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var clamp := raw_node as MeshInstance3D
		if StringName(clamp.get_meta(INTERFACE_COLLAR_KIND_META, &"")) != &"ExteriorPipeClamp":
			continue
		clamps.append(clamp)
		if clamp.mesh != null:
			mesh_ids[clamp.mesh.get_instance_id()] = true
		if clamp.material_override != null:
			material_ids[clamp.material_override.get_instance_id()] = true
		var index := clamps.size() - 1
		if clamp.mesh != _exterior_pipe_clamp_mesh:
			errors.append("exterior_pipe_clamp_mesh_identity_not_shared")
		if index >= EXTERIOR_PIPE_CLAMP_POSITIONS.size() \
				or clamp.material_override != _materials.get("graphite") \
				or not clamp.position.is_equal_approx(EXTERIOR_PIPE_CLAMP_POSITIONS[index] as Vector3) \
				or not clamp.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0)) \
				or clamp.scale != Vector3.ONE \
				or not clamp.visible \
				or clamp.layers != 1 \
				or clamp.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or clamp.material_overlay != null \
				or not is_zero_approx(clamp.transparency) \
				or clamp.get_parent() != expected_parent \
				or clamp.get_child_count() != 0 \
				or clamp.get_script() != null \
				or not clamp.get_groups().is_empty():
			errors.append("exterior_pipe_clamp_render_or_authority_drift")
		collisions += clamp.find_children("*", "CollisionObject3D", true, false).size()
		collisions += clamp.find_children("*", "CollisionShape3D", true, false).size()
	if clamps.size() != EXTERIOR_PIPE_CLAMP_COPY_COUNT:
		errors.append("exterior_pipe_clamp_copy_count_drift")
	if mesh_ids.size() != 1:
		errors.append("exterior_pipe_clamp_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("exterior_pipe_clamp_material_identity_drift")
	if collisions != 0:
		errors.append("exterior_pipe_clamp_gained_collision_authority")
	var normalised := _exterior_pipe_clamp_mesh != null and _exterior_pipe_clamp_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	var expected_tessellation := Vector2i(32, TorusGeometryBudget.AFT_INTERFACE_COLLAR_RING_SEGMENTS) if normalised else Vector2i(EXTERIOR_PIPE_CLAMP_RINGS, EXTERIOR_PIPE_CLAMP_RING_SEGMENTS)
	if _exterior_pipe_clamp_mesh == null \
			or not is_equal_approx(_exterior_pipe_clamp_mesh.inner_radius, EXTERIOR_PIPE_CLAMP_INNER_RADIUS) \
			or not is_equal_approx(_exterior_pipe_clamp_mesh.outer_radius, EXTERIOR_PIPE_CLAMP_OUTER_RADIUS) \
			or _exterior_pipe_clamp_mesh.rings != expected_tessellation.x \
			or _exterior_pipe_clamp_mesh.ring_segments != expected_tessellation.y \
			or _exterior_pipe_clamp_mesh.get_surface_count() != 1:
		errors.append("exterior_pipe_clamp_torus_recipe_drift")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_exterior_pipe_clamps",
		"legacy": {"visual_nodes": 4, "drawn_copies": 4, "surface_submissions": 4, "mesh_resource_allocations": 4, "material_resource_allocations": 1},
		"current": {"visual_nodes": clamps.size(), "drawn_copies": clamps.size(), "surface_submissions": clamps.size(), "mesh_resource_allocations": mesh_ids.size(), "material_resource_allocations": material_ids.size()},
		"reductions": {"visual_nodes": 0, "drawn_copies": 0, "surface_submissions": 0, "mesh_resource_allocations": 3, "material_resource_allocations": 0},
		"authored_tessellation": Vector2i(EXTERIOR_PIPE_CLAMP_RINGS, EXTERIOR_PIPE_CLAMP_RING_SEGMENTS),
		"live_tessellation": Vector2i(_exterior_pipe_clamp_mesh.rings, _exterior_pipe_clamp_mesh.ring_segments) if _exterior_pipe_clamp_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"collision_authority_count": collisions,
		"batched": false,
		"renderer_values_changed": false,
	}.duplicate(true)


func get_conduit_collar_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var family_nodes: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var node_paths := PackedStringArray()
	var transforms: Array[Transform3D] = []
	var surface_submissions := 0
	var visible_copies := 0
	var collision_nodes := 0
	var authority_nodes := 0
	var expected_parent := get_node_or_null(
		^"Structure/OperationsRoom/ServiceWall"
	) as Node3D
	for raw_node in find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if StringName(instance.get_meta(
			TorusGeometryBudget.PROFILE_META, &""
		)) != TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			continue
		if StringName(instance.get_meta(INTERFACE_COLLAR_KIND_META, &"")) \
				!= &"ConduitCollar":
			continue
		family_nodes.append(instance)
		node_paths.append(String(get_path_to(instance)))
		transforms.append(instance.transform)
		visible_copies += 1 if instance.visible else 0
		if instance.mesh != null:
			mesh_ids[instance.mesh.get_instance_id()] = true
			surface_submissions += instance.mesh.get_surface_count()
		if instance.material_override != null:
			material_ids[instance.material_override.get_instance_id()] = true
		if instance.mesh != _conduit_collar_mesh:
			errors.append("conduit_collar_mesh_identity_not_shared")
		if instance.material_override != _materials.get("brass"):
			errors.append("conduit_collar_material_identity_drift")
		var family_index := family_nodes.size() - 1
		if family_index >= CONDUIT_COLLAR_POSITIONS.size() \
				or not instance.position.is_equal_approx(
					CONDUIT_COLLAR_POSITIONS[family_index] as Vector3
				) \
				or not instance.rotation_degrees.is_equal_approx(
					Vector3(90.0, 0.0, 0.0)
				) \
				or instance.scale != Vector3.ONE:
			errors.append("conduit_collar_transform_drift")
		if not instance.visible \
				or instance.layers != 1 \
				or instance.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or instance.material_overlay != null \
				or not is_zero_approx(instance.transparency):
			errors.append("conduit_collar_renderer_state_drift")
		var metadata_keys := instance.get_meta_list()
		var exact_metadata := (
			metadata_keys.size() == 2
			and metadata_keys.has(TorusGeometryBudget.PROFILE_META)
			and metadata_keys.has(INTERFACE_COLLAR_KIND_META)
			and StringName(instance.get_meta(
				TorusGeometryBudget.PROFILE_META, &""
			)) == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
			and StringName(instance.get_meta(
				INTERFACE_COLLAR_KIND_META, &""
			)) == &"ConduitCollar"
		)
		var gained_authority := (
			instance.get_parent() != expected_parent
			or instance.get_child_count() != 0
			or instance.get_script() != null
			or not instance.get_groups().is_empty()
			or not exact_metadata
		)
		if gained_authority:
			authority_nodes += 1
			errors.append("conduit_collar_gained_authority_or_lifecycle")
		collision_nodes += instance.find_children(
			"*", "CollisionObject3D", true, false
		).size()
		collision_nodes += instance.find_children(
			"*", "CollisionShape3D", true, false
		).size()

	if family_nodes.size() != CONDUIT_COLLAR_COPY_COUNT:
		errors.append("conduit_collar_visual_node_count_drift")
	var stable_paths := family_nodes.size() == CONDUIT_COLLAR_COPY_COUNT
	if stable_paths:
		stable_paths = node_paths[0] \
			== "Structure/OperationsRoom/ServiceWall/ConduitCollar"
		for index in range(1, node_paths.size()):
			stable_paths = (
				stable_paths
				and String(family_nodes[index].name).begins_with("@MeshInstance3D@")
				and family_nodes[index].get_parent() == expected_parent
			)
	if not stable_paths:
		errors.append("conduit_collar_node_path_roster_drift")
	if mesh_ids.size() != 1:
		errors.append("conduit_collar_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("conduit_collar_material_identity_drift")
	if collision_nodes != 0:
		errors.append("conduit_collar_gained_collision_authority")

	var authored_tessellation := Vector2i(
		CONDUIT_COLLAR_RINGS,
		CONDUIT_COLLAR_RING_SEGMENTS
	)
	var normalised := (
		_conduit_collar_mesh != null
		and _conduit_collar_mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	)
	var live_tessellation := Vector2i(
		CONDUIT_COLLAR_BUDGETED_RINGS,
		CONDUIT_COLLAR_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if _conduit_collar_mesh == null \
			or not is_equal_approx(
				_conduit_collar_mesh.inner_radius,
				CONDUIT_COLLAR_INNER_RADIUS
			) \
			or not is_equal_approx(
				_conduit_collar_mesh.outer_radius,
				CONDUIT_COLLAR_OUTER_RADIUS
			) \
			or _conduit_collar_mesh.rings != live_tessellation.x \
			or _conduit_collar_mesh.ring_segments != live_tessellation.y \
			or _conduit_collar_mesh.get_surface_count() != 1:
		errors.append("conduit_collar_torus_recipe_drift")
	var mesh_metadata: Array[StringName] = []
	if _conduit_collar_mesh != null:
		mesh_metadata = _conduit_collar_mesh.get_meta_list()
	var exact_mesh_metadata: bool = (
		_conduit_collar_mesh != null
		and _conduit_collar_mesh.material == null
		and not _conduit_collar_mesh.resource_local_to_scene
		and (
			(not normalised and mesh_metadata.is_empty())
			or (
				normalised
				and mesh_metadata.size() == 1
				and mesh_metadata.has(TorusGeometryBudget.AUTHORED_META)
				and _conduit_collar_mesh.get_meta(
					TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
				) == authored_tessellation
			)
		)
	)
	if not exact_mesh_metadata:
		errors.append("conduit_collar_budget_metadata_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_conduit_collar_visuals",
		"legacy": {
			"visual_nodes": CONDUIT_COLLAR_COPY_COUNT,
			"drawn_copies": CONDUIT_COLLAR_COPY_COUNT,
			"surface_submissions": CONDUIT_COLLAR_COPY_COUNT,
			"mesh_resource_allocations": CONDUIT_COLLAR_COPY_COUNT,
			"material_resource_allocations": 1,
		},
		"current": {
			"visual_nodes": family_nodes.size(),
			"drawn_copies": visible_copies,
			"surface_submissions": surface_submissions,
			"mesh_resource_allocations": mesh_ids.size(),
			"material_resource_allocations": material_ids.size(),
		},
		"reductions": {
			"visual_nodes": 0,
			"drawn_copies": 0,
			"surface_submissions": 0,
			"mesh_resource_allocations": 2,
			"material_resource_allocations": 0,
		},
		"node_paths": node_paths,
		"authored_transforms": transforms,
		"authored_tessellation": authored_tessellation,
		"live_tessellation": Vector2i(
			_conduit_collar_mesh.rings,
			_conduit_collar_mesh.ring_segments
		) if _conduit_collar_mesh != null else Vector2i.ZERO,
		"normalised": normalised,
		"material_identity_preserved": material_ids.size() == 1,
		"collision_authority_count": collision_nodes,
		"semantic_authority_count": authority_nodes,
		"batched": false,
		"renderer_values_changed": false,
	}.duplicate(true)


## Detached component-local proof for the fourteen card inserts in the opened
## watch rack. Named childless anchors preserve every authored path while one
## renderer owns the identical rounded-box copies.
func get_rack_card_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var bank := get_node_or_null(
		^"Structure/OperationsRoom/OperationsContent/WatchRackBank"
	) as Node3D
	var batch := _rack_card_batch
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh as ArrayMesh if multimesh != null else null
	var expected_transforms := _rack_card_transforms()
	var expected_buffer := _encode_multimesh_transforms(expected_transforms)
	var expected_bounds := (
		_transformed_mesh_bounds(mesh.get_aabb(), expected_transforms)
		if mesh != null else AABB()
	)
	var anchor_paths := PackedStringArray()
	var anchors_exact := bank != null
	var anchor_count := 0
	for module_index in range(1, 3):
		for card_index in 7:
			var flat_index := (module_index - 1) * 7 + card_index
			var node_name := "RackCard%02d%02d" % [module_index, card_index]
			var anchor := (
				bank.get_node_or_null(NodePath(node_name)) as Marker3D
				if bank != null else null
			)
			anchor_paths.append(
				String(get_path_to(anchor)) if anchor != null else ""
			)
			anchor_count += 1 if anchor != null else 0
			anchors_exact = (
				anchors_exact
				and anchor != null
				and anchor.get_parent() == bank
				and anchor.transform.is_equal_approx(expected_transforms[flat_index])
				and anchor.get_child_count() == 0
				and anchor.get_script() == null
				and anchor.get_groups().is_empty()
				and anchor.get_meta_list().is_empty()
			)
	if not anchors_exact:
		errors.append("rack_card_anchor_roster_or_transform_drift")
	if batch == null or multimesh == null or mesh == null:
		errors.append("rack_card_batch_missing")
	else:
		if batch.get_parent() != bank or str(batch.name) != "RackCardRenderBatch":
			errors.append("rack_card_batch_path_drift")
		if multimesh.transform_format != MultiMesh.TRANSFORM_3D \
				or multimesh.use_colors or multimesh.use_custom_data:
			errors.append("rack_card_multimesh_format_drift")
		if multimesh.instance_count != RACK_CARD_COPY_COUNT \
				or multimesh.visible_instance_count != RACK_CARD_COPY_COUNT:
			errors.append("rack_card_visible_copy_roster_drift")
		if multimesh.buffer != expected_buffer:
			errors.append("rack_card_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("rack_card_culling_bounds_drift")
		if mesh != _rounded_box_mesh(RACK_CARD_SIZE) \
				or mesh.get_surface_count() != 1 \
				or mesh.surface_get_material(0) != null \
				or mesh.resource_local_to_scene \
				or not mesh.get_aabb().size.is_equal_approx(RACK_CARD_SIZE):
			errors.append("rack_card_mesh_recipe_or_identity_drift")
		if not batch.transform.is_equal_approx(Transform3D.IDENTITY) \
				or not batch.visible \
				or batch.layers != 1 \
				or batch.cast_shadow \
					!= GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				or batch.material_override != _materials.get("panel_light") \
				or batch.material_overlay != null \
				or not is_zero_approx(batch.transparency):
			errors.append("rack_card_render_state_drift")
		var metadata_keys := batch.get_meta_list()
		if batch.get_child_count() != 0 \
				or batch.get_script() != null \
				or not batch.get_groups().is_empty() \
				or metadata_keys.size() != 2 \
				or not metadata_keys.has(&"visual_detail_only") \
				or not metadata_keys.has(&"authored_instance_transforms") \
				or not bool(batch.get_meta("visual_detail_only", false)) \
				or not _transform_arrays_match(
					batch.get_meta("authored_instance_transforms", []) as Array,
					expected_transforms
				):
			errors.append("rack_card_batch_gained_semantic_authority")
	if bank == null:
		errors.append("watch_rack_bank_missing")
	else:
		for module_index in range(1, 3):
			var cage := bank.get_node_or_null(
				NodePath("RackCardCage%02d" % module_index)
			) as MeshInstance3D
			if cage == null:
				errors.append("rack_card_cage_readability_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_watch_rack_cards",
		"legacy": {
			"family_nodes": 14,
			"stable_anchor_nodes": 0,
			"renderer_nodes": 14,
			"drawn_copies": 14,
			"surface_submissions": 14,
			"mesh_resource_allocations": 1,
			"material_resource_allocations": 1,
		},
		"current": {
			"family_nodes": anchor_count + (1 if batch != null else 0),
			"stable_anchor_nodes": anchor_count,
			"renderer_nodes": 1 if batch != null else 0,
			"drawn_copies": (
				multimesh.visible_instance_count if multimesh != null else 0
			),
			"surface_submissions": mesh.get_surface_count() if mesh != null else 0,
			"mesh_resource_allocations": 1 if mesh != null else 0,
			"material_resource_allocations": 1 if batch != null \
				and batch.material_override != null else 0,
		},
		"reductions": {
			"family_nodes": -1,
			"renderer_nodes": 13,
			"drawn_copies": 0,
			"surface_submissions": 13,
			"mesh_resource_allocations": 0,
			"material_resource_allocations": 0,
		},
		"anchor_paths": anchor_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"renderer_buffer": expected_buffer.duplicate(),
		"renderer_buffer_float_count": multimesh.buffer.size() \
			if multimesh != null else 0,
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"collision_authority_added": false,
		"interaction_authority_added": false,
		"evidence_authority_added": false,
		"lifecycle_authority_added": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"pixel_equivalence_claimed": false,
	}.duplicate(true)


## Detached component-local proof for the four VIP facade foot/crown copies.
## MultiMesh submissions are counted as one mesh surface for the batch while
## visible copies count every authored transform. This is renderer-allocation
## evidence, not a frame-time, GPU, VRAM, or pixel-equivalence claim.
func get_vip_facade_column_trim_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var batch := _vip_facade_column_trim_batch
	var multimesh := batch.multimesh if batch != null else null
	var mesh := multimesh.mesh as TorusMesh if multimesh != null else null
	var expected_transforms := _vip_facade_column_trim_transforms()
	var expected_buffer := _encode_multimesh_transforms(expected_transforms)
	var expected_bounds := (
		_transformed_mesh_bounds(mesh.get_aabb(), expected_transforms)
		if mesh != null else AABB()
	)
	var vip := get_node_or_null(^"Structure/VIPLandmark") as Node3D
	if batch == null or multimesh == null or mesh == null:
		errors.append("vip_facade_column_trim_batch_missing")
	else:
		if batch.get_parent() != vip or str(batch.name) != "VIPFacadeColumnTrimBatch":
			errors.append("vip_facade_column_trim_batch_path_drift")
		if multimesh.transform_format != MultiMesh.TRANSFORM_3D \
			or multimesh.use_colors \
			or multimesh.use_custom_data:
			errors.append("vip_facade_column_trim_multimesh_format_drift")
		if multimesh.instance_count != VIP_FACADE_COLUMN_TRIM_COPY_COUNT \
			or multimesh.visible_instance_count != VIP_FACADE_COLUMN_TRIM_COPY_COUNT:
			errors.append("vip_facade_column_trim_visible_copy_roster_drift")
		if multimesh.buffer != expected_buffer:
			errors.append("vip_facade_column_trim_renderer_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("vip_facade_column_trim_culling_bounds_drift")
		if not batch.transform.is_equal_approx(Transform3D.IDENTITY) \
			or not batch.visible \
			or batch.layers != 1 \
			or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or batch.material_override != _materials.get("brass") \
			or batch.material_overlay != null \
			or not is_zero_approx(batch.transparency):
			errors.append("vip_facade_column_trim_render_state_drift")
		var metadata_keys := batch.get_meta_list()
		if batch.get_child_count() != 0 \
			or batch.get_script() != null \
			or not batch.get_groups().is_empty() \
			or metadata_keys.size() != 2 \
			or not metadata_keys.has(&"visual_detail_only") \
			or not metadata_keys.has(&"authored_instance_transforms") \
			or not bool(batch.get_meta("visual_detail_only", false)) \
			or not _transform_arrays_match(
				batch.get_meta("authored_instance_transforms", []) as Array,
				expected_transforms
			):
			errors.append("vip_facade_column_trim_gained_semantic_authority")
		if not is_equal_approx(mesh.inner_radius, VIP_FACADE_COLUMN_TRIM_INNER_RADIUS) \
			or not is_equal_approx(mesh.outer_radius, VIP_FACADE_COLUMN_TRIM_OUTER_RADIUS) \
			or mesh.rings != VIP_FACADE_COLUMN_TRIM_BUDGETED_RINGS \
			or mesh.ring_segments != VIP_FACADE_COLUMN_TRIM_BUDGETED_RING_SEGMENTS \
			or mesh.get_surface_count() != 1 \
			or mesh.material != null \
			or mesh.resource_local_to_scene:
			errors.append("vip_facade_column_trim_mesh_recipe_drift")
		var authored_tessellation: Variant = mesh.get_meta(
			TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
		)
		var mesh_metadata := mesh.get_meta_list()
		if authored_tessellation is not Vector2i \
			or authored_tessellation != Vector2i(
				VIP_FACADE_COLUMN_TRIM_RINGS,
				VIP_FACADE_COLUMN_TRIM_RING_SEGMENTS
			) \
			or mesh_metadata.size() != 1 \
			or not mesh_metadata.has(TorusGeometryBudget.AUTHORED_META):
			errors.append("vip_facade_column_trim_budget_metadata_drift")
	if vip == null:
		errors.append("vip_facade_landmark_missing")
	else:
		if not vip.find_children(
			"VIPFacadeColumnFoot", "MeshInstance3D", false, false
		).is_empty() or not vip.find_children(
			"VIPFacadeColumnCrown", "MeshInstance3D", false, false
		).is_empty():
			errors.append("retired_vip_facade_column_trim_renderer_remains")

	var current_visible_copies := (
		multimesh.visible_instance_count if multimesh != null else 0
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"aft_junction_stack_vip_facade_column_trim",
		"batch_path": String(get_path_to(batch)) if batch != null else "",
		"legacy": {
			"renderer_nodes": 4,
			"mesh_instance_nodes": 4,
			"multimesh_instance_nodes": 0,
			"drawn_copies": 4,
			"surface_submissions": 4,
			"mesh_resource_allocations": 4,
		},
		"current": {
			"renderer_nodes": 1 if batch != null else 0,
			"mesh_instance_nodes": 0,
			"multimesh_instance_nodes": 1 if batch != null else 0,
			"drawn_copies": current_visible_copies,
			"surface_submissions": mesh.get_surface_count() if mesh != null else 0,
			"mesh_resource_allocations": 1 if mesh != null else 0,
		},
		"reductions": {
			"renderer_nodes": 3,
			"surface_submissions": 3,
			"mesh_resource_allocations": 3,
			"drawn_copies": 0,
		},
		"authored_transforms": expected_transforms.duplicate(),
		"renderer_buffer": expected_buffer.duplicate(),
		"renderer_buffer_float_count": multimesh.buffer.size() if multimesh != null else 0,
		"culling_bounds": multimesh.custom_aabb if multimesh != null else AABB(),
		"authored_tessellation": Vector2i(
			VIP_FACADE_COLUMN_TRIM_RINGS,
			VIP_FACADE_COLUMN_TRIM_RING_SEGMENTS
		),
		"live_tessellation": Vector2i(
			mesh.rings, mesh.ring_segments
		) if mesh != null else Vector2i.ZERO,
		"material_identity_preserved": (
			batch != null and batch.material_override == _materials.get("brass")
		),
		"collision_authority_added": false,
		"interaction_authority_added": false,
		"evidence_authority_added": false,
		"lifecycle_authority_added": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"pixel_equivalence_claimed": false,
	}.duplicate(true)


## Applied unconditionally once the live module admits the request. A no-op guard
## on the flag made drifted state unrepairable: if the nodes lost their layer or
## visibility while the flag still read `true`, the obvious repair call returned
## immediately and the module stayed unwalkable.
func set_module_enabled(enabled: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_module_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _module_enabled


func get_lifecycle_contract() -> Dictionary:
	# This module hides in place, so its own node is the visibility root.
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _module_enabled, self
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	contract["build_generation"] = 1
	return contract


func _apply_enabled_state() -> void:
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _module_enabled, self
	)
	for seat in find_children("*", "StationSeat", true, false):
		(seat as StationSeat).set_enabled(_module_enabled)
	# The content pass gave this module a frame loop, so the loop has to follow the
	# lifecycle flag too. `build_lifecycle_contract` reports
	# `process_matches_lifecycle` false for any module that keeps advancing behind
	# a hidden shell, and `get_validation_errors` rejects on it — a disabled module
	# whose plot sweep kept turning would snap to a jumped pose when re-enabled.
	set_process(_module_enabled and _built)


func _index_routes() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"lower-junction": _route_lower_junction,
		&"stair-base": _route_stair_base,
		&"stair-top": _route_stair_top,
		&"operations-room": _operations_room_anchor,
		&"upper-floor": _upper_floor_anchor,
		&"vip-landmark": _vip_access_anchor,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	# Only the outward approach face is a station connection slot. Every other
	# marker is an internal waypoint, and the VIP landmark stays out of the graph.
	_route_approach.set_meta(StationModuleContract.CONNECTION_SLOT_META, HUB_CONNECTION_SLOT)
	_operations_room_anchor.set_meta("station_room_marker", true)
	_operations_room_anchor.set_meta("room_id", &"aft-operations")
	_upper_floor_anchor.set_meta("station_upper_floor_marker", true)
	_vip_access_anchor.set_meta("station_vip_landmark", true)


func _render_descendant_count() -> int:
	var count := 0
	for candidate in find_children("*", "Node", true, false):
		var cursor := candidate as Node
		var interaction_owned := false
		while cursor != null and cursor != self:
			if cursor is StationSeat:
				interaction_owned = true
				break
			cursor = cursor.get_parent()
		if not interaction_owned:
			count += 1
	return count


func _create_materials() -> void:
	# Layered PBR values and a project-original lighting-neutral station panel set
	# keep broad pressure surfaces from reading as uniformly shaded primitives.
	_materials["off_white"] = _material(Color("cbd0ce"), 0.38, 0.34)
	_materials["panel_light"] = _material(Color("aeb8b8"), 0.42, 0.29)
	_materials["warm_grey"] = _material(Color("818b8b"), 0.46, 0.39)
	_materials["mid_grey"] = _material(Color("526166"), 0.58, 0.31)
	_materials["hull_dark"] = _material(Color("29363a"), 0.62, 0.28)
	# Floor-role twins of the structural greys. Both halves of each pair now carry
	# the same panel maps, so hue and relief no longer tell a deck from the wall
	# above it; only the material response can. A walked-on deck is a coated,
	# scuffed, trafficked surface, so each floor twin is deliberately less metallic
	# and markedly rougher than the structural member it meets at the skirting.
	# Before this the twins were byte-identical in every PBR value, which is why
	# two surfaces differing only in hue read as painted plastic.
	_materials["off_white_floor"] = _material(Color("cbd0ce"), 0.26, 0.52)
	_materials["warm_grey_floor"] = _material(Color("818b8b"), 0.30, 0.55)
	_materials["mid_grey_floor"] = _material(Color("526166"), 0.38, 0.50)
	_materials["hull_dark_floor"] = _material(Color("29363a"), 0.40, 0.46)
	_materials["graphite"] = _material(Color("141d21"), 0.48, 0.47)
	_materials["rubber"] = _material(Color("101719"), 0.06, 0.86)
	_materials["cyan"] = _material(Color("55dce2"), 0.12, 0.34, Color("3acbd3"), 1.45)
	_materials["cyan_dim"] = _material(Color("3a7479"), 0.34, 0.42, Color("2aa6ae"), 0.35)
	# Emission 0.2 -> 0.62. `gold` is the module's warm cue colour and it was the
	# one cue that never read as lit: at 0.2 the arc tiles, cabinet status strips
	# and the junction legend sat below the tonemapper's shoulder and returned
	# nothing but their albedo. They are now paired with warm practicals (see
	# `_fixture_practical`), and a cue that throws light has to look like it is on.
	_materials["gold"] = _material(Color("d0a350"), 0.54, 0.3, Color("8f5f20"), 0.62)
	# Non-emissive structural twin of `gold`. `gold` carries a faint emission and
	# is the module's *cue* colour: route arc tiles, cabinet status, control lamps
	# and signage. It was also carrying the physical brass furniture — handrails,
	# collars, column feet, fasteners — and those were the only unmapped parts left
	# in a plated frame, so a 0.07 m handrail read as a flat yellow stick bolted to
	# a plated post. `brass` takes the furniture into the panel family and leaves
	# every cue on `gold`, unchanged. Rougher and less metallic than `gold` too:
	# handled brass is worn satin, not the lacquered accent of a lit legend.
	_materials["brass"] = _material(Color("d0a350"), 0.46, 0.44)
	_materials["copper"] = _material(Color("9d6844"), 0.78, 0.26)
	_materials["red"] = _material(Color("d84d47"), 0.18, 0.4, Color("b82c2c"), 1.15)
	# Emission 1.25 -> 1.0, for the same reason as the habitat's twin: the console
	# displays clipped white while the console body under them stayed at structure
	# value. `ConsoleGlow` now lights the console, so the panel does not have to be
	# blown to read as a live display.
	_materials["screen"] = _material(Color("b9f2ef"), 0.08, 0.24, Color("68dde2"), 1.0)
	_materials["screen_dark"] = _material(Color("16363b"), 0.22, 0.36, Color("2b9aa3"), 0.22)
	# Lens emission comes down where a practical now carries the difference. These
	# two were the brightest surfaces in the module and the reason its histogram
	# was bimodal: a 2.5-energy lens clips well past the AgX shoulder, blooms, and
	# still leaves the ceiling plate it is recessed into at structure value,
	# because emission does not illuminate anything. Energy moved out of the lens
	# and into `OperationsPoolLight` / `ExteriorCowlSpill`; the fixture reads
	# slightly less blown and its mount reads lit, which is the trade this pass
	# exists to make. worklight 2.5 -> 1.65, amber_light 1.8 -> 1.2.
	_materials["worklight"] = _material(Color("edf8f5"), 0.02, 0.2, Color("d7ffff"), 1.65)
	_materials["amber_light"] = _material(Color("ffdba0"), 0.02, 0.24, Color("f1a84e"), 1.2)
	# Glazing response re-frozen, metallic 0.03 -> 0.06 and roughness 0.08 -> 0.12,
	# which is the habitat's exact pair. The lighting pass recorded that these panes
	# "read slightly flatter than the habitat's because the room behind the camera
	# is brighter and the glass returns it" and left it for an owner. That reading
	# is real and the cause is here rather than in the room: at roughness 0.08 the
	# specular lobe is narrow enough to return the room as a *sheet*, so a bright
	# interior comes back as one even wash across a 3.05 x 3.25 m pane and buries
	# the star field behind it. The habitat's 0.12 spreads the same return into a
	# gradient that falls off across the pane, which is why its windows read as
	# glass and these read as tinted panels. Only the response moves; the tint,
	# alpha, pane sizes and mullions are untouched, so the aft room keeps its own
	# colour and the two rooms now agree on what glass *is*. Verified by render:
	# the operations panes gain a visible falloff and more of the exterior.
	_materials["glass"] = _transparent_material(Color(0.38, 0.68, 0.72, 0.18), 0.06, 0.12)
	_materials["chair"] = _material(Color("4a5557"), 0.14, 0.7)
	_materials["chair_pad"] = _material(Color("273236"), 0.04, 0.92)
	# Soft goods and paper stock, for the content pass. Both are deliberately
	# outside the world-triplanar plate family for the same reason the module's
	# seating fabric and lit cues are: a duty log, a chart roll, a notice sheet and
	# a coverall draped over a chair are not plate, and stamping a 0.30 m panel
	# field across them would read as printed steel.
	_materials["fabric"] = _material(Color("5d6b63"), 0.0, 0.94)
	_materials["paper"] = _material(Color("d9d7cd"), 0.0, 0.88)
	# Keep the operations room's authored cool pressure shell and warm handled
	# metal palette, but separate the response of the physical roles a player can
	# read at walking distance. These are the same ten material resources that
	# already feed every mesh and MultiMesh: only their shared-kit finish changes,
	# so layout, collision, navigation, labels, lights and render allocations stay
	# outside this pass.
	var finish_by_key := {
		# Deck slabs, stair treads and dark pressure/grip plates share the worn top
		# layer expected of trafficked surfaces.
		"off_white_floor": StationSurfaceKit.PanelFinish.WALKED_DECK,
		"warm_grey_floor": StationSurfaceKit.PanelFinish.WALKED_DECK,
		"mid_grey_floor": StationSurfaceKit.PanelFinish.WALKED_DECK,
		"hull_dark_floor": StationSurfaceKit.PanelFinish.WALKED_DECK,
		# Bright frame stock plus the darker load-bearing lattice remain alloy.
		"off_white": StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
		"mid_grey": StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
		"hull_dark": StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
		# Light pressure panels, walls and machinery housings retain a painted read.
		"panel_light": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		"warm_grey": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		# Warm handrails, collars and furniture stay distinct close metal trim.
		"brass": StationSurfaceKit.PanelFinish.METAL_TRIM,
	}
	# The recipe includes the published normal depth and the module's frozen 0.30
	# m scale; the finish profile owns clearcoat only and cannot rewrite hue or PBR
	# scalar values declared above.
	for key: String in finish_by_key:
		StationSurfaceKit.apply_panel_triplanar(
			_materials[key] as StandardMaterial3D,
			PANEL_SURFACE_SCALE,
			finish_by_key[key]
		)


func _build_structure() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)

	_build_open_lower_deck(structure)
	_build_stair_and_upper_deck(structure)
	_build_operations_room(structure)
	_build_vip_landmark(structure)
	_build_open_structure_details(structure)


func _build_open_lower_deck(structure: Node3D) -> void:
	var lower := Node3D.new()
	lower.name = "LowerOpenDeck"
	structure.add_child(lower)

	_box(lower, "ConnectionDeck", Vector3(0.0, -0.32, 2.5), Vector3(7.0, 0.64, 5.0), _materials["off_white_floor"])
	# Stop exactly at the operations-room floor instead of extending 0.9 m under
	# it. The old slabs occupied the same full-depth volume from z=9.1 to 10.0,
	# so their different floor materials fought for the top face immediately
	# behind Operations Access. A butt seam preserves continuous collision and
	# removes the coplanar render surfaces.
	_box(lower, "JunctionDeck", Vector3(0.0, -0.32, 7.05), Vector3(11.0, 0.64, 4.1), _materials["warm_grey_floor"])
	# Retain the old junction footprint west of the operations-room shell. This
	# apron owns only x=-5.5..0.4 where OperationsFloor does not exist, so the
	# outside route stays supported without reintroducing the doorway overlap.
	_box(lower, "JunctionDeckWestApron", Vector3(-2.55, -0.32, 9.55), Vector3(5.9, 0.64, 0.9), _materials["warm_grey_floor"])
	# The stair begins west of ConnectionDeck. Its former first tread and ramp
	# floated across a 0.8 m physics gap, so this compact landing gives a
	# straight, level run onto the unchanged ramp. It shares its whole eastern
	# strip with ConnectionDeck: the two are coplanar, and that strip is the gate
	# onto the stair, so no rail may stand in it (MAP-001).
	_box(lower, "StairBaseLanding", STAIR_BASE_LANDING_CENTRE, STAIR_BASE_LANDING_SIZE, _materials["off_white_floor"])
	_box(lower, "JunctionInset", Vector3(0.0, 0.025, 7.35), Vector3(5.8, 0.05, 3.5), _materials["off_white_floor"], false)
	# Turn the cyan ribbon across the supported junction/landing overlap, directly
	# between the published lower-junction and stair-base markers. The previous
	# north/south strip ran into the Operations Access frame while never showing
	# the 5.7 m west turn a player actually has to make.
	var lower_route_start := Vector3(
		_route_lower_junction.position.x, 0.06, _route_lower_junction.position.z
	)
	var lower_route_finish := Vector3(
		_route_stair_base.position.x, 0.06, _route_stair_base.position.z
	)
	var lower_route_delta := lower_route_finish - lower_route_start
	_box(
		lower,
		"RouteStripe",
		(lower_route_start + lower_route_finish) * 0.5,
		Vector3(ROUTE_STRIPE_WIDTH, 0.055, lower_route_delta.length()),
		_materials["cyan"],
		false,
		Vector3(0.0, rad_to_deg(atan2(lower_route_delta.x, lower_route_delta.z)), 0.0)
	)

	# The incomplete ring makes the junction readable without becoming another
	# monumental runway gate. Its open west quadrant points toward the stair.
	#
	# Two of the eight tiles carry a warm practical. Not eight: the ring is a
	# 7.5 m ellipse of touching tiles, one light per tile would be seven redundant
	# copies of the same pool, and two placed on opposite arcs already put a warm
	# gradient across the whole inset. This is the module's only warm light at
	# deck level and it is what keeps the junction floor from being the same cyan
	# as the wall above it.
	var junction_arc_transforms: Array[Transform3D] = []
	var junction_arc_index := 0
	for angle in [-70.0, -35.0, 0.0, 35.0, 70.0, 105.0, 140.0, 175.0]:
		var radians := deg_to_rad(angle)
		var ring_position := Vector3(cos(radians) * 3.75, 0.11, 7.45 + sin(radians) * 1.75)
		var arc_transform := Transform3D(
			Basis.from_euler(Vector3(0.0, deg_to_rad(-angle + 90.0), 0.0)),
			ring_position
		)
		var arc_anchor := Marker3D.new()
		arc_anchor.name = "JunctionArcTile%02d" % (junction_arc_index + 1)
		arc_anchor.transform = arc_transform
		arc_anchor.set_meta("presentation_only", true)
		arc_anchor.set_meta("collision_free", true)
		arc_anchor.set_meta("detail_role", &"junction_arc_tile")
		lower.add_child(arc_anchor)
		junction_arc_transforms.append(arc_transform)
		junction_arc_index += 1
		if is_equal_approx(angle, -35.0) or is_equal_approx(angle, 140.0):
			_fixture_practical(
				lower,
				"JunctionArcSpill",
				ring_position + Vector3(0.0, 0.24, 0.0),
				Color("f0be7c"),
				0.46,
				4.2
			)
	_junction_arc_tile_batch = _multimesh_rounded_box(
		lower,
		"JunctionArcTileBatch",
		Vector3(1.25, 0.08, 0.24),
		_materials["gold"],
		junction_arc_transforms
	)
	_junction_arc_tile_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Sparse rails leave the approach and circulation branches genuinely open.
	# The port rail guards only the stretch of the connection deck's west edge that
	# actually overhangs a drop. It stops at the stair-base landing's southern edge,
	# because beyond that the landing *is* the floor and the rail would fence the
	# only lateral mount onto the stair (MAP-001).
	_add_rail(
		lower,
		Vector3(-3.35, 0.0, 0.25),
		Vector3(-3.35, 0.0, _stair_base_landing_south_edge() - 0.05),
		"ApproachPortRail"
	)
	# Opening the stair gate exposes the landing's own outboard edges, which
	# previously nothing could walk to. Guard them, and leave the whole eastern
	# side of the landing open as the gate itself.
	var landing_south := _stair_base_landing_south_edge()
	var landing_west := STAIR_BASE_LANDING_CENTRE.x - STAIR_BASE_LANDING_SIZE.x * 0.5
	_add_rail(
		lower,
		Vector3(landing_west + 0.06, 0.0, landing_south + 0.06),
		Vector3(-3.4, 0.0, landing_south + 0.06),
		"StairBaseSouthRail"
	)
	_add_rail(
		lower,
		Vector3(landing_west + 0.06, 0.0, landing_south + 0.06),
		Vector3(landing_west + 0.06, 0.0, 2.85),
		"StairBaseWestRail"
	)
	# Continue the starboard guard to the junction corner. The former run ended
	# at z = 3.3 while the ConnectionDeck continues to z = 5.0, leaving its last
	# exposed stretch beside OPERATIONS ACCESS unprotected. It still stops short
	# of the widening JunctionDeck, so the operations approach remains open.
	_add_rail(lower, Vector3(3.35, 0.0, 0.25), Vector3(3.35, 0.0, 4.95), "ApproachStarboardRail")
	_add_rail(lower, Vector3(5.35, 0.0, 5.15), Vector3(5.35, 0.0, 8.8), "JunctionEastRail")
	# The two outer guard runs meet at a stepped deck corner beside Operations
	# Access. Bridge their endpoints: the diagonal is entirely outside the
	# walkable floor, so it closes the fall hazard without closing a route.
	_add_rail(
		lower,
		Vector3(3.35, 0.0, 4.95),
		Vector3(5.35, 0.0, 5.15),
		"JunctionCornerRail"
	)

	# A separate, non-colliding service envelope breaks up the slab while leaving
	# the tested floor plane and open circulation samples completely unchanged.
	var approach_edge_collar_transforms := _approach_edge_collar_transforms()
	var approach_edge_collar_index := 0
	for side in [-1.0, 1.0]:
		var edge_x := float(side) * 3.5
		_beam_between(lower, "ApproachEdgeTube", Vector3(edge_x, -0.38, 0.1), Vector3(edge_x, -0.38, 5.0), 0.105, _materials["mid_grey"], false)
		for z_position in [0.65, 2.5, 4.35]:
			var collar_anchor := Marker3D.new()
			collar_anchor.name = "ApproachEdgeCollar"
			collar_anchor.transform = approach_edge_collar_transforms[approach_edge_collar_index]
			collar_anchor.set_meta("approach_edge_collar_anchor", true)
			lower.add_child(collar_anchor)
			approach_edge_collar_index += 1
		var junction_edge_x := float(side) * 5.5
		_beam_between(lower, "JunctionEdgeTube", Vector3(junction_edge_x, -0.42, 5.0), Vector3(junction_edge_x, -0.42, 10.0), 0.13, _materials["hull_dark"], false)
		_beam_between(lower, "LowerLongitudinalTruss", Vector3(float(side) * 3.9, -0.86, 5.15), Vector3(float(side) * 4.9, -0.86, 9.85), 0.11, _materials["mid_grey"], false)
		for z_position in [5.3, 7.5, 9.7]:
			_beam_between(
				lower,
				"LowerTrussStrut",
				Vector3(float(side) * 3.75, -0.28, z_position - 0.72),
				Vector3(float(side) * 4.75, -0.9, z_position + 0.72),
				0.085,
				_materials["warm_grey"],
				false
			)
	_approach_edge_collar_batch = _multimesh_mesh(
		lower,
		"ApproachEdgeCollarRenderBatch",
		StationSurfaceKit.chamfered_cylinder_mesh_cached(
			APPROACH_EDGE_COLLAR_RADIUS,
			APPROACH_EDGE_COLLAR_RADIUS,
			APPROACH_EDGE_COLLAR_HEIGHT,
			32,
			_chamfered_cylinder_cache
		),
		_materials["brass"],
		approach_edge_collar_transforms
	)

	for z_position in [1.15, 2.65, 4.15, 6.15, 8.55]:
		_box(lower, "DeckExpansionJoint", Vector3(0, 0.072, z_position), Vector3(6.1 if z_position < 5.0 else 9.8, 0.018, 0.045), _materials["graphite"], false)
	for side in [-1.0, 1.0]:
		_box(
			lower,
			"RecessedServiceHatch",
			Vector3(float(side) * 2.65, 0.071, 7.4),
			Vector3(1.55, 0.025, 1.15),
			_materials["hull_dark"],
			false
		)
		for corner_x in [-0.58, 0.58]:
			for corner_z in [-0.39, 0.39]:
				_cylinder(
					lower,
					"HatchFastener",
					Vector3(float(side) * 2.65 + corner_x, 0.09, 7.4 + corner_z),
					0.035,
					0.025,
					_materials["brass"],
					false
				)
	var low_route_light_transforms: Array[Transform3D] = []
	for light_index in LOW_ROUTE_LIGHT_COPY_COUNT:
		var light_transform := Transform3D(
			Basis.IDENTITY,
			LOW_ROUTE_LIGHT_POSITIONS[light_index] as Vector3
		)
		var light_anchor := Marker3D.new()
		light_anchor.name = "LowRouteLight" if light_index == 0 \
			else "LowRouteLight%d" % (light_index + 1)
		light_anchor.transform = light_transform
		lower.add_child(light_anchor, true)
		low_route_light_transforms.append(light_transform)
	_multimesh_rounded_box(
		lower,
		"LowRouteLightRenderBatch",
		LOW_ROUTE_LIGHT_SIZE,
		_materials["cyan"],
		low_route_light_transforms
	)


func _build_stair_and_upper_deck(structure: Node3D) -> void:
	var circulation := Node3D.new()
	circulation.name = "Circulation"
	structure.add_child(circulation)

	var start := Vector3(-5.7, LOWER_FLOOR_ELEVATION, 3.0)
	var finish := Vector3(-5.7, UPPER_FLOOR_ELEVATION, 12.8)
	var direction := finish - start
	var ramp_length := direction.length()
	var ramp_angle := -atan2(direction.y, direction.z)
	var ramp := StaticBody3D.new()
	ramp.name = "ContinuousStairRamp"
	ramp.collision_layer = WORLD_LAYER
	ramp.collision_mask = 0
	ramp.position = (start + finish) * 0.5
	ramp.rotation.x = ramp_angle
	circulation.add_child(ramp)
	var ramp_mesh_instance := MeshInstance3D.new()
	ramp_mesh_instance.name = "RampMesh"
	# This skin is continuously visible between the tread gaps on the principal
	# lower-to-upper route. Keep the snag-resistant BoxShape3D as sole physics
	# authority, but give its formerly raw 90-degree render box the same cached
	# chamfer treatment as the surrounding deck and tread structure. The surface
	# kit preserves the requested AABB exactly, so the stair pose, footprint and
	# usable clearance do not move.
	var ramp_size := Vector3(STAIR_CLEAR_WIDTH, 0.22, ramp_length)
	ramp_mesh_instance.mesh = _rounded_box_mesh(ramp_size)
	ramp_mesh_instance.material_override = _materials["mid_grey_floor"]
	ramp.add_child(ramp_mesh_instance)
	var ramp_collision := CollisionShape3D.new()
	ramp_collision.name = "RampCollision"
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = ramp_size
	ramp_collision.shape = ramp_shape
	ramp.add_child(ramp_collision)

	var tread_transforms := _stair_tread_transforms()
	for index in STAIR_STEP_COUNT:
		var tread_transform := tread_transforms[index]
		var tread_position := tread_transform.origin
		var tread_anchor := Marker3D.new()
		tread_anchor.name = "VisibleTread%02d" % index
		tread_anchor.transform = tread_transform
		circulation.add_child(tread_anchor)
		_box(
			circulation,
			"TreadNosing%02d" % index,
			tread_position + Vector3(0, 0.075, -0.32),
			Vector3(2.76, 0.045, 0.075),
			_materials["graphite"] if index % 3 else _materials["cyan_dim"],
			false
		)
	_stair_tread_batch = _multimesh_rounded_box(
		circulation,
		"VisibleTreadRenderBatch",
		STAIR_TREAD_SIZE,
		_materials["off_white_floor"],
		tread_transforms
	)

	# Twin tubular stringers make the climb read as an engineered assembly rather
	# than fifteen floating boxes. They sit beneath the unchanged navigation ramp.
	for stringer_side in [-1.0, 1.0]:
		var stringer_x := -5.7 + float(stringer_side) * 1.28
		_beam_between(
			circulation,
			"StairStringer",
			Vector3(stringer_x, start.y - 0.16, start.z),
			Vector3(stringer_x, finish.y - 0.16, finish.z),
			0.13,
			_materials["hull_dark"],
			false
		)
		for support_progress in [0.0, 0.33, 0.66, 1.0]:
			var route_support: Vector3 = start.lerp(finish, float(support_progress))
			_cylinder(
				circulation,
				"StringerCollar",
				Vector3(stringer_x, route_support.y - 0.16, route_support.z),
				0.145,
				0.16,
				_materials["copper"],
				false,
				Vector3(90, 0, 0)
			)

	for side in [-1.0, 1.0]:
		var rail_x: float = -5.7 + float(side) * 1.7
		# A stair rail that stands on the stair-base landing is a fence across a
		# walking surface, not a guard over a drop. Where the rail line crosses the
		# landing footprint it starts where the ramp has climbed clear of it; the
		# outboard line, which overhangs the void, still runs the full length.
		var rail_start_progress := _stair_rail_start_progress(rail_x, start, finish)
		var rail_start: Vector3 = start.lerp(finish, rail_start_progress)
		for raw_progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var progress := float(raw_progress)
			if progress < rail_start_progress:
				continue
			var route_point: Vector3 = start.lerp(finish, progress)
			_cylinder(circulation, "StairRailPost", Vector3(rail_x, route_point.y + 0.7, route_point.z), 0.055, 1.4, _materials["warm_grey"], true)
		_beam_between(
			circulation,
			"StairHandrail",
			Vector3(rail_x, rail_start.y + 1.38, rail_start.z),
			Vector3(rail_x, finish.y + 1.38, finish.z),
			0.075,
			_materials["brass"],
			true
		)
		_beam_between(
			circulation,
			"StairMidRail",
			Vector3(rail_x, rail_start.y + 0.76, rail_start.z),
			Vector3(rail_x, finish.y + 0.76, finish.z),
			0.045,
			_materials["mid_grey"],
			false
		)

	_build_stair_handoff_cue(circulation)

	for light_progress in [0.18, 0.5, 0.82]:
		var stair_light_position: Vector3 = start.lerp(finish, float(light_progress))
		_box(
			circulation,
			"StairCourtesyLight",
			stair_light_position + Vector3(-1.47, 0.36, 0),
			Vector3(0.035, 0.22, 0.38),
			_materials["amber_light"],
			false
		)
		_omni_light(
			circulation,
			"StairPoolLight",
			stair_light_position + Vector3(-1.25, 0.55, 0),
			Color("e9b66e"),
			0.32,
			3.2
		)

	var upper := Node3D.new()
	upper.name = "UpperOpenDeck"
	structure.add_child(upper)
	# Carry the public upper-deck route past the relocated VIP facade. Keeping this
	# as a full-width deck, rather than a narrow threshold slab, leaves the route
	# visibly open beside the reception entrance.
	_box(upper, "UpperFloor", Vector3(-5.15, 3.88, 17.55), Vector3(10.3, 0.64, 10.1), _materials["off_white_floor"])
	_box(upper, "UpperFloorInset", Vector3(-5.15, 4.225, 16.4), Vector3(7.7, 0.05, 5.8), _materials["warm_grey_floor"], false)
	_box(upper, "VIPAccessApronInset", Vector3(-5.15, 4.225, 20.95), Vector3(7.7, 0.05, 3.3), _materials["warm_grey_floor"], false)
	_box(upper, "UpperRouteStripe", Vector3(-5.15, 4.26, 17.2), Vector3(ROUTE_STRIPE_WIDTH, 0.05, 8.5), _materials["red"], false)
	_build_upper_transfer_gate(upper)
	# The former rail began at z=12.7 and joined UpperSouthRail into a sealed
	# corner. Start it at z=14.5 to preserve the guarded edge while exposing a
	# 1.8 m player-clear gate onto the Cinder south access transition.
	_add_rail(upper, Vector3(-10.1, 4.2, 14.5), Vector3(-10.1, 4.2, 22.25), "UpperWestRail")
	_add_rail(upper, Vector3(-9.8, 4.2, 12.55), Vector3(-7.45, 4.2, 12.55), "UpperSouthRail")
	_add_rail(upper, Vector3(-3.9, 4.2, 12.55), Vector3(-0.25, 4.2, 12.55), "UpperSouthReturnRail")
	for z_position in [13.25, 16.5, 19.75]:
		_box(upper, "UpperDeckSeam", Vector3(-5.15, 4.247, z_position), Vector3(8.8, 0.018, 0.05), _materials["graphite"], false)
		_beam_between(
			upper,
			"UpperUndersideCrossMember",
			Vector3(-9.8, 3.45, z_position),
			Vector3(-0.5, 3.45, z_position),
			0.12,
			_materials["hull_dark"],
			false
		)
	for support_x in [-9.4, -5.15, -0.9]:
		_beam_between(upper, "UpperDiagonalBrace", Vector3(support_x, 3.5, 13.0), Vector3(support_x, 2.35, 15.1), 0.1, _materials["mid_grey"], false)
		_beam_between(upper, "UpperDiagonalBraceReturn", Vector3(support_x, 3.5, 20.0), Vector3(support_x, 2.35, 17.9), 0.1, _materials["mid_grey"], false)

	_build_stair_head_muster(upper)


## The cyan deck ribbon ends at the stair-base marker, but from the lower
## junction the ramp reads edge-on against open space. A small overhead datum
## now names that turn before the player reaches it. Both mounts bear on the
## existing rail lines outside the 2.8 m clear lane, while the plate's lower edge
## stays above 2.0 m. Every leaf is non-colliding and uses only the module's
## non-emissive structural/brass materials: this adds no route, door, light,
## interaction, traversal, or lifecycle authority.
func _build_stair_handoff_cue(circulation: Node3D) -> void:
	var cue := Node3D.new()
	cue.name = "StairHandoffCue"
	cue.position = Vector3(-5.7, LOWER_FLOOR_ELEVATION, 3.0)
	cue.set_meta("presentation_only", true)
	cue.set_meta("detail_role", &"stair_handoff_navigation_cue")
	circulation.add_child(cue)

	_box(
		cue,
		"BackingPlate",
		Vector3(0.0, 2.42, 0.05),
		Vector3(3.05, 0.54, 0.08),
		_materials["hull_dark"],
		false
	)
	for side in [-1.0, 1.0]:
		_box(
			cue,
			"PortMount" if side < 0.0 else "StarboardMount",
			Vector3(float(side) * 1.7, 1.075, 0.0),
			Vector3(0.08, 2.15, 0.08),
			_materials["brass"],
			false
		)
	_box(
		cue,
		"TopDatum",
		Vector3(0.0, 2.72, 0.05),
		Vector3(3.17, 0.06, 0.10),
		_materials["brass"],
		false
	)
	# Raised twin strokes form an upward chevron without relying on colour.
	_box(
		cue,
		"PortArrowStroke",
		Vector3(1.13, 2.42, 0.105),
		Vector3(0.08, 0.30, 0.04),
		_materials["brass"],
		false,
		Vector3(0.0, 0.0, -38.0)
	)
	_box(
		cue,
		"StarboardArrowStroke",
		Vector3(1.29, 2.42, 0.105),
		Vector3(0.08, 0.30, 0.04),
		_materials["brass"],
		false,
		Vector3(0.0, 0.0, 38.0)
	)
	# This is the one sign read directly from the connector/stair handoff. Name
	# the destination rather than its elevation: the lower deck's plaque claims
	# the transit/berth flow, while this warm header reserves the rising route for
	# Operations. The plate, arrow, mounts, materials and clear stair lane remain
	# exactly as authored.
	_text_sign(
		cue,
		"UPPER OPERATIONS",
		Vector3(-0.30, 2.42, 0.105),
		Vector3.ZERO,
		0.21,
		_materials["brass"]
	)


func _build_upper_transfer_gate(upper: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "UpperTransferGate"
	upper.add_child(gate)

	var rib_transforms: Array[Transform3D] = []
	var band_transforms: Array[Transform3D] = []
	for rib_x in UPPER_TRANSFER_RIB_X_POSITIONS:
		for rib_z in UPPER_TRANSFER_RIB_Z_POSITIONS:
			var rib_position := Vector3(
				float(rib_x),
				UPPER_FLOOR_ELEVATION + 0.05 + UPPER_TRANSFER_RIB_SIZE.y * 0.5,
				float(rib_z)
			)
			var rib_transform := Transform3D(Basis.IDENTITY, rib_position)
			rib_transforms.append(rib_transform)
			band_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(float(rib_x), UPPER_FLOOR_ELEVATION + 1.48, float(rib_z))
			))

	var rib_batch := _multimesh_rounded_box(
		gate,
		"TransferRibRenderBatch",
		UPPER_TRANSFER_RIB_SIZE,
		_materials["red"],
		rib_transforms
	)
	rib_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var band_batch := _multimesh_rounded_box(
		gate,
		"TransferBandRenderBatch",
		UPPER_TRANSFER_BAND_SIZE,
		_materials["brass"],
		band_transforms
	)
	band_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_operations_room(structure: Node3D) -> void:
	var room := Node3D.new()
	room.name = "OperationsRoom"
	structure.add_child(room)

	_box(room, "OperationsFloor", Vector3(5.6, -0.32, 13.2), Vector3(10.4, 0.64, 8.2), _materials["off_white_floor"])
	_box(room, "OperationsCeiling", Vector3(5.6, 4.75, 13.2), Vector3(10.4, 0.48, 8.2), _materials["warm_grey"])
	_box(room, "WestWall", Vector3(0.4, 2.38, 13.25), Vector3(0.38, 4.75, 7.8), _materials["warm_grey"])
	_box(room, "SouthWallLeft", Vector3(0.5, 2.1, 9.1), Vector3(0.6, 4.2, 0.42), _materials["warm_grey"])
	_box(room, "SouthWallDoorPocket", Vector3(7.4, 2.1, 9.1), Vector3(6.6, 4.2, 0.42), _materials["warm_grey"])
	for floor_x in [1.75, 5.6, 9.45]:
		for floor_z in [10.55, 13.15, 15.75]:
			_box(
				room,
				"FloorPressurePlate",
				Vector3(float(floor_x), 0.015, float(floor_z)),
				Vector3(3.45, 0.025, 2.25),
				_materials["hull_dark_floor"] if int(floor_x * 10.0 + floor_z * 10.0) % 2 else _materials["mid_grey_floor"],
				false
			)
		for seam_z in [11.85, 14.45]:
			_box(room, "FloorSeam", Vector3(float(floor_x), 0.042, float(seam_z)), Vector3(3.25, 0.018, 0.035), _materials["rubber"], false)
	# Rounded guards and a tubular roof rail soften the pod silhouette while its
	# dependable box colliders retain a clean, testable room envelope.
	_pod_corner_collar_mesh = _torus_mesh(
		POD_CORNER_COLLAR_INNER_RADIUS,
		POD_CORNER_COLLAR_OUTER_RADIUS,
		POD_CORNER_COLLAR_RINGS,
		POD_CORNER_COLLAR_RING_SEGMENTS
	)
	_pod_corner_collar_mesh.resource_name = "AftPodCornerCollarMesh"
	for corner in [
		Vector3(0.4, 2.4, 9.18),
		Vector3(10.8, 2.4, 9.18),
		Vector3(0.4, 2.4, 17.24),
		Vector3(10.8, 2.4, 17.24),
	]:
		_cylinder(room, "RoundedPodCorner", corner, 0.24, 4.8, _materials["mid_grey"], false)
		var collar := _torus(
			room,
			"PodCornerCollar",
			corner + Vector3.UP * 2.05,
			POD_CORNER_COLLAR_INNER_RADIUS,
			POD_CORNER_COLLAR_OUTER_RADIUS,
			_materials["brass"],
			Vector3(90, 0, 0),
			_pod_corner_collar_mesh
		)
		collar.set_meta(
			POD_CORNER_COLLAR_FAMILY_META,
			POD_CORNER_COLLAR_FAMILY_ID
		)
	_beam_between(room, "WindowRoofRail", Vector3(0.7, 5.08, 17.15), Vector3(10.5, 5.08, 17.15), 0.11, _materials["off_white"], false)

	# A wide north-facing window dominates the room. Transparent panes remain
	# physical barriers, while narrow structure preserves the sightline.
	_box(room, "WindowSill", Vector3(5.6, 0.38, 17.3), Vector3(10.4, 0.76, 0.42), _materials["warm_grey"])
	_box(room, "WindowHeader", Vector3(5.6, 4.38, 17.3), Vector3(10.4, 0.74, 0.42), _materials["warm_grey"])
	for x_position in [0.55, 4.0, 7.2, 10.65]:
		_box(room, "WindowMullion", Vector3(x_position, 2.4, 17.3), Vector3(0.22, 3.35, 0.44), _materials["mid_grey"])
	for pane_index in 3:
		var pane_x := 2.25 + float(pane_index) * 3.3
		_box(room, "WindowPane%02d" % pane_index, Vector3(pane_x, 2.42, 17.29), Vector3(3.05, 3.25, 0.12), _materials["glass"])
		_box(room, "WindowLowerFrame%02d" % pane_index, Vector3(pane_x, 0.83, 17.08), Vector3(3.0, 0.12, 0.18), _materials["hull_dark"], false)
		_box(room, "WindowUpperFrame%02d" % pane_index, Vector3(pane_x, 4.0, 17.08), Vector3(3.0, 0.12, 0.18), _materials["hull_dark"], false)

	_build_operations_shell_detail(room)

	# Three operator stations face the broad exterior sightline.
	_console_shock_collar_mesh = _torus_mesh(
		CONSOLE_SHOCK_COLLAR_INNER_RADIUS,
		CONSOLE_SHOCK_COLLAR_OUTER_RADIUS,
		CONSOLE_SHOCK_COLLAR_RINGS,
		CONSOLE_SHOCK_COLLAR_RING_SEGMENTS
	)
	_console_shock_collar_mesh.resource_name = "AftConsoleShockCollarMesh"
	# MultiMesh renderers are intentionally outside TorusGeometryBudget's
	# MeshInstance3D traversal. Apply the same narrowly reviewed interface-collar
	# profile once to the shared recipe so batching preserves the production
	# 32x8 silhouette that the six former renderers received at startup.
	TorusGeometryBudget.apply_profile(
		_console_shock_collar_mesh,
		1.0,
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
	)
	for bay_index in 3:
		var bay := Node3D.new()
		bay.name = "ConsoleBay%02d" % (bay_index + 1)
		bay.position = Vector3(3.15 + float(bay_index) * 2.85, 0.0, 15.7)
		bay.set_meta("station_console_bay", true)
		bay.set_meta("console_index", bay_index)
		room.add_child(bay)
		_console_nodes.append(bay)
		_box(bay, "ConsolePlinth", Vector3(0, 0.66, 0), Vector3(2.25, 1.32, 0.9), _materials["mid_grey"])
		_box(bay, "PlinthKick", Vector3(0, 0.18, -0.47), Vector3(1.82, 0.28, 0.12), _materials["rubber"], false)
		_box(bay, "PlinthInset", Vector3(0, 0.7, -0.47), Vector3(1.72, 0.48, 0.08), _materials["hull_dark"], false)
		for support_x in [-0.86, 0.86]:
			_cylinder(bay, "ConsoleShockMount", Vector3(float(support_x), 0.23, 0.34), 0.085, 0.38, _materials["copper"], false)
			var collar_anchor := Marker3D.new()
			collar_anchor.name = "ConsoleShockCollar"
			collar_anchor.position = Vector3(float(support_x), 0.08, 0.34)
			collar_anchor.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			bay.add_child(collar_anchor)
		_box(bay, "AngledConsole", Vector3(0, 1.26, -0.1), Vector3(2.18, 0.28, 1.0), _materials["graphite"], true, Vector3(-12, 0, 0))
		_box(bay, "ConsoleEdgeRail", Vector3(0, 1.43, -0.56), Vector3(2.18, 0.09, 0.09), _materials["panel_light"], false, Vector3(-12, 0, 0))
		_box(bay, "PrimaryDisplay", Vector3(0, 1.43, -0.18), Vector3(1.55, 0.035, 0.56), _materials["screen"], false, Vector3(-12, 0, 0))
		for display_index in 3:
			_box(
				bay,
				"DisplayDataBand",
				Vector3(0, 1.454 + float(display_index) * 0.005, -0.33 + float(display_index) * 0.16),
				Vector3(1.25 - float(display_index) * 0.15, 0.012, 0.035),
				_materials["screen_dark"],
				false,
				Vector3(-12, 0, 0)
			)
		for lamp_index in 3:
			var accent: Material = _materials["cyan"] if lamp_index < 2 else _materials["gold"]
			_cylinder(bay, "ControlLamp", Vector3(-0.56 + float(lamp_index) * 0.56, 1.5, -0.03), 0.06, 0.04, accent, false, Vector3(90, 0, 0))
		# One practical per bay, not one per lamp. The display, its three data
		# bands and the three control lamps are a single luminaire from any
		# distance a player reads this room from; three lights per bay would be
		# three copies of one pool over a 2.2 m console. Placed just above and in
		# front of the glass so it washes the console top, the edge rail and the
		# operator's chair back rather than the ceiling.
		#
		# Range 2.6 -> 3.4, energy unchanged. This is the only light in the room in
		# front of a seated operator's face, and the face is 1.83 m away, where a
		# 2.6 m range window was cutting 43% of it. Widening the window leaves the
		# console top — 0.4 m away, where the window reads 1.00 either way —
		# exactly as lit as it was, which is why this is a range change and not an
		# energy change: the panel is what an energy raise would have blown first.
		_fixture_practical(
			bay,
			"ConsoleGlow",
			Vector3(0.0, 1.74, -0.36),
			Color("93e4ea"),
			0.42,
			3.4
		)
		# One existing console is an embodied entry point to the Activity Board.
		# The adapter adds only proximity discovery; GameFlow and HUD retain the
		# selection and activity lifecycle authority.
		if bay_index == 1:
			var activity_board_console := ActivityBoardConsole.new()
			activity_board_console.name = "ActivityBoardConsole"
			bay.add_child(activity_board_console)
		# The adjacent authored workstation is the physical return point for the
		# finite engineer-kit loop. It owns only proximity and presentation;
		# GameFlow selects the last active craft and that craft's existing repair
		# authority owns the actual restock.
		elif bay_index == 2:
			var ship_service_console = ShipServiceConsoleType.new()
			ship_service_console.name = "ShipServiceConsole"
			bay.add_child(ship_service_console)
		# The bay's one warm lamp gets its own tiny pool. It is the only warm
		# source on the console line and it is what stops three identical cyan
		# consoles reading as one extruded strip.
		_fixture_practical(
			bay,
			"ControlLampSpill",
			Vector3(0.56, 1.58, -0.1),
			Color("f2c07f"),
			0.24,
			1.25
		)
	_console_shock_collar_batch = _multimesh_torus(
		room,
		"ConsoleShockCollarRenderBatch",
		_console_shock_collar_mesh,
		_materials["rubber"],
		_console_shock_collar_transforms()
	)

	# Three operator chairs plus a side-facing coordinator chair.
	#
	# The three operator chairs are yawed 180, which is a fix rather than a
	# restyle. `_build_chair` puts `BackFrame` at local +Z, so a chair authored at
	# yaw 0 seats its occupant facing local -Z — and the console bay it belongs to
	# stands at z = 15.7 with its display, edge rail and control lamps all on the
	# -Z face, i.e. at +Z of the chair. Every operator was therefore sitting with
	# their back to their own console, facing the door. It read as three armchairs
	# parked in front of some machinery rather than as three working positions, and
	# it also contradicted the lighting that was built for it: `ConsoleGlow` is
	# documented as "the only light in the room in front of a seated operator's
	# face", sited 1.83 m from a face at z = 13.55, which is only true of a chair
	# looking at +Z. Nothing moves; only the chairs turn.
	#
	# The coordinator keeps -72. That chair faces (0.951, 0, -0.309) — out across
	# the room toward the plot table and the status board, which is where a watch
	# coordinator looks — and its own task wash at (2.0, 1.05, 12.4) was sited for
	# exactly that pose.
	_pedestal_bearing_mesh = _torus_mesh(
		PEDESTAL_BEARING_INNER_RADIUS,
		PEDESTAL_BEARING_OUTER_RADIUS,
		PEDESTAL_BEARING_RINGS,
		PEDESTAL_BEARING_RING_SEGMENTS
	)
	_pedestal_bearing_mesh.resource_name = "AftPedestalBearingMesh"
	for chair_index in 4:
		var chair_position: Vector3
		var chair_yaw := 180.0
		if chair_index < 3:
			chair_position = Vector3(3.15 + float(chair_index) * 2.85, 0.0, 13.55)
		else:
			chair_position = Vector3(1.7, 0.0, 12.0)
			chair_yaw = -72.0
		_build_chair(room, chair_index, chair_position, chair_yaw)

	_build_service_wall(room)
	_build_operations_lighting(room)
	_build_operations_content(room)
	_text_sign(room, "AFT OPERATIONS", Vector3(7.2, 3.7, 9.31), Vector3(0, 180, 0), 0.29, _materials["cyan"])
	# A lit sign that does not light the wall it hangs on is a sticker. This is a
	# wide, weak wash placed a little in front of and below the legend, so the
	# bulkhead behind it carries a gradient the sign sits inside.
	_fixture_practical(room, "OperationsSignWash", Vector3(7.2, 3.45, 9.62), Color("7fe0e6"), 0.34, 3.0)


func _build_operations_shell_detail(room: Node3D) -> void:
	var envelope := Node3D.new()
	envelope.name = "VisualPressureEnvelope"
	envelope.set_meta("visual_detail_only", true)
	room.add_child(envelope)

	# Narrow roof cassettes and raised ribs replace the single-box silhouette with
	# a pressure-shell rhythm. The underlying roof remains the sole collider.
	for panel_index in 5:
		var panel_x := 1.25 + float(panel_index) * 2.18
		_box(
			envelope,
			"RoofCassette%02d" % panel_index,
			Vector3(panel_x, 5.015 + (0.025 if panel_index % 2 else 0.0), 13.2),
			Vector3(1.82, 0.11, 7.35),
			_materials["panel_light"] if panel_index % 2 else _materials["warm_grey"],
			false
		)
	_build_pressure_rib_batches(envelope)
	_beam_between(envelope, "RoofServiceSpine", Vector3(5.6, 5.62, 9.25), Vector3(5.6, 5.62, 17.22), 0.15, _materials["hull_dark"], false)
	_spine_clamp_mesh = _torus_mesh(
		SPINE_CLAMP_INNER_RADIUS,
		SPINE_CLAMP_OUTER_RADIUS,
		SPINE_CLAMP_RINGS,
		SPINE_CLAMP_RING_SEGMENTS
	)
	for spine_position in SPINE_CLAMP_POSITIONS:
		_interface_collar(
			envelope,
			"SpineClamp",
			spine_position as Vector3,
			SPINE_CLAMP_INNER_RADIUS,
			SPINE_CLAMP_OUTER_RADIUS,
			_materials["copper"],
			Vector3(90, 0, 0),
			_spine_clamp_mesh
		)

	# Low-profile environmental hardware gives the roof a credible service layer
	# without implying a source-authenticated room function.
	_roof_vent_collar_mesh = _torus_mesh(
		ROOF_VENT_COLLAR_INNER_RADIUS,
		ROOF_VENT_COLLAR_OUTER_RADIUS,
		ROOF_VENT_COLLAR_RINGS,
		ROOF_VENT_COLLAR_RING_SEGMENTS
	)
	for vent_index in 2:
		var vent_x := 3.05 + float(vent_index) * 5.05
		_cylinder(envelope, "RoofVent", Vector3(vent_x, 5.18, 13.0), 0.42, 0.28, _materials["hull_dark"], false)
		var collar := _torus(envelope, "RoofVentCollar", Vector3(vent_x, 5.31, 13.0), ROOF_VENT_COLLAR_INNER_RADIUS, ROOF_VENT_COLLAR_OUTER_RADIUS, _materials["mid_grey"], Vector3.ZERO, _roof_vent_collar_mesh)
		collar.set_meta(ROOF_VENT_COLLAR_FAMILY_META, ROOF_VENT_COLLAR_FAMILY_ID)
		for louvre_index in 3:
			var anchor := Marker3D.new()
			anchor.name = "VentLouvre%02d" % (vent_index * 3 + louvre_index)
			anchor.position = Vector3(
				vent_x - 0.24 + float(louvre_index) * 0.24,
				5.34,
				13.0
			)
			anchor.set_meta("presentation_only", true)
			anchor.set_meta("collision_free", true)
			anchor.set_meta("detail_role", &"roof_vent_louvre")
			envelope.add_child(anchor)
	var louvre_transforms: Array[Transform3D] = []
	for louvre_position in ROOF_VENT_LOUVRE_POSITIONS:
		louvre_transforms.append(Transform3D(Basis.IDENTITY, louvre_position as Vector3))
	_roof_vent_louvre_batch = _multimesh_rounded_box(
		envelope,
		"RoofVentLouvreBatch",
		ROOF_VENT_LOUVRE_SIZE,
		_materials["graphite"],
		louvre_transforms
	)

	# Layered side cladding is offset just beyond the physical room shell. Dark
	# reveal channels make each plate legible under oblique exterior lighting.
	for wall_x in [0.16, 11.02]:
		for panel_index in 4:
			var panel_z := 10.2 + float(panel_index) * 2.02
			_box(
				envelope,
				"SideCladding",
				Vector3(float(wall_x), 2.42, panel_z),
				Vector3(0.12, 3.7, 1.68),
				_materials["panel_light"] if panel_index % 2 else _materials["mid_grey"],
				false
			)
			_box(
				envelope,
				"SideReveal",
				Vector3(float(wall_x) + (0.065 if wall_x < 1.0 else -0.065), 2.42, panel_z + 0.9),
				Vector3(0.035, 3.5, 0.065),
				_materials["rubber"],
				false
			)
		for rail_y in [0.55, 4.28]:
			_beam_between(
				envelope,
				"SideShellRail",
				Vector3(float(wall_x), float(rail_y), 9.4),
				Vector3(float(wall_x), float(rail_y), 17.02),
				0.085,
				_materials["hull_dark"],
				false
			)

	# The occupied south facade is kept clear of the real doorway at x=2.2.
	for panel_x in [5.0, 7.25, 9.5]:
		_box(
			envelope,
			"EntryFacadePanel",
			Vector3(float(panel_x), 2.42, 8.85),
			Vector3(1.82, 3.55, 0.12),
			_materials["warm_grey"] if panel_x < 7.0 else _materials["panel_light"],
			false
		)
		_box(envelope, "FacadeReveal", Vector3(float(panel_x), 2.42, 8.775), Vector3(1.5, 2.95, 0.035), _materials["hull_dark"], false)
	_beam_between(envelope, "EntryHeaderTube", Vector3(0.25, 4.55, 8.78), Vector3(10.9, 4.55, 8.78), 0.11, _materials["off_white"], false)
	_beam_between(envelope, "WindowEyebrow", Vector3(0.35, 4.72, 17.55), Vector3(10.85, 4.72, 17.55), 0.14, _materials["hull_dark"], false)
	for mullion_x in [0.45, 4.0, 7.2, 10.75]:
		_beam_between(
			envelope,
			"WindowOuterFrame",
			Vector3(float(mullion_x), 0.6, 17.52),
			Vector3(float(mullion_x), 4.45, 17.52),
			0.12,
			_materials["off_white"],
			false
		)

	# Underside keels and diagonal outriggers are deliberately visual-only. They
	# are prominent in the exterior evidence camera and retain the exact floor hit.
	for keel_x in [1.3, 5.6, 9.9]:
		_beam_between(envelope, "UndersideKeel", Vector3(float(keel_x), -0.72, 9.25), Vector3(float(keel_x), -0.72, 17.1), 0.15, _materials["hull_dark"], false)
	for z_position in [9.55, 11.45, 13.35, 15.25, 17.0]:
		_beam_between(envelope, "UnderfloorCrossMember", Vector3(0.45, -0.68, float(z_position)), Vector3(10.75, -0.68, float(z_position)), 0.12, _materials["mid_grey"], false)
		_beam_between(envelope, "UnderfloorBracePort", Vector3(0.55, -0.5, float(z_position) - 0.65), Vector3(3.15, -1.05, float(z_position) + 0.65), 0.085, _materials["warm_grey"], false)
		_beam_between(envelope, "UnderfloorBraceStarboard", Vector3(10.65, -0.5, float(z_position) - 0.65), Vector3(8.05, -1.05, float(z_position) + 0.65), 0.085, _materials["warm_grey"], false)

	# A restrained exterior utility run adds scale and material contrast.
	_beam_between(envelope, "ExteriorCopperFeed", Vector3(11.18, 0.82, 10.0), Vector3(11.18, 0.82, 16.25), 0.06, _materials["copper"], false)
	_exterior_pipe_clamp_mesh = _torus_mesh(
		EXTERIOR_PIPE_CLAMP_INNER_RADIUS,
		EXTERIOR_PIPE_CLAMP_OUTER_RADIUS,
		EXTERIOR_PIPE_CLAMP_RINGS,
		EXTERIOR_PIPE_CLAMP_RING_SEGMENTS
	)
	for pipe_position in EXTERIOR_PIPE_CLAMP_POSITIONS:
		_interface_collar(
			envelope,
			"ExteriorPipeClamp",
			pipe_position as Vector3,
			EXTERIOR_PIPE_CLAMP_INNER_RADIUS,
			EXTERIOR_PIPE_CLAMP_OUTER_RADIUS,
			_materials["graphite"],
			Vector3(90, 0, 0),
			_exterior_pipe_clamp_mesh
		)
	# Four cowled amber worklights on the operations envelope. The cowl and lens
	# geometry was already here; what was missing is that none of them lit the
	# plate they are bolted to, so from outside the module read as cool plating
	# with four orange stickers on it. Each now throws a short warm pool onto its
	# own housing and the surrounding wall, and together they are the warm half of
	# the aft module's exterior colour temperature.
	for lamp_position in [Vector3(0.1, 3.9, 9.45), Vector3(11.1, 3.9, 9.45), Vector3(0.1, 3.9, 16.9), Vector3(11.1, 3.9, 16.9)]:
		_box(envelope, "ExteriorWorklightHousing", lamp_position, Vector3(0.22, 0.4, 0.52), _materials["hull_dark"], false)
		_box(envelope, "ExteriorWorklightLens", lamp_position + Vector3(0, 0, -0.27), Vector3(0.13, 0.22, 0.035), _materials["amber_light"], false)
		_fixture_practical(
			envelope,
			"ExteriorCowlSpill",
			lamp_position + Vector3(0.0, -0.1, -0.42),
			Color("f7bb70"),
			0.62,
			3.6
		)


## Operations-room lighting.
##
## This room was the clearest case of the two defects this pass exists to fix.
## Every surface in it — plate, deck, console, cove, sign — returned one cyan
## hue, because the only warm light anywhere in the station is a directional
## bounce aimed up from the open decks, and an enclosed room cannot see it. And
## its three ceiling luminaires were 2.5-energy lenses over a plate that received
## 0.62 of cool omni, so the frame was a pair of spikes with nothing between.
##
## The fix is colour temperature, not level. Real rooms are lit by more than one
## kind of lamp and that is most of what makes them read as built: the overheads
## here stay the station's cool service white and stay dominant, so the cool
## identity is untouched, but the room now also carries warm light from two
## sources that belong to it — an under-console task wash at working height, and
## the warm end of the cove. The overheads lost the emission that was blowing
## out and gained the room brightness that emission was never providing:
## `worklight` 2.5 -> 1.65 in the palette, `OperationsPoolLight` 0.62 -> 0.94.
##
## The functional cue colours are deliberately not touched. Cyan route/status,
## amber gold and red keep their exact hues and their shape channel; the warm
## light added here is a low, broad, sub-1.0-energy wash at knee-to-waist height,
## which lands on floor and plinth and never on a cue face hard enough to shift
## what it reads as.
##
## ## The regrade follow-up: why this room "barely moved"
##
## The colour-temperature work above was right and is kept unchanged in kind. It
## did not make the room legible, and the reason turned out to be arithmetic in
## `omni_range` rather than anything about hue or level.
##
## Godot 4's omni falloff is a *windowed* inverse power, not a plain one:
## `(1 - (d/range)^4)^2 * d^(-attenuation)`. The window term is the trap. A
## luminaire 4.0 m above the deck with `omni_range = 5.6` sits at d/range = 0.71
## for the floor directly beneath it, where the window has already removed 45% of
## what the distance term left — and every wall, every corner and every chair
## back is further away than that, so the pool was being cut off at exactly the
## distances a person occupies. The room was three bright discs on the ceiling
## plate and a deck that received 0.07. That is the "pair of spikes with nothing
## between" the note above describes, and raising energy could not fix it: energy
## scales the ceiling disc and the deck by the same factor, so it moves the
## already-blown end up faster than the dark end.
##
## The fix is to widen the window, not the gain. `OperationsPoolLight` goes
## 5.6 -> 9.0 m of range while its energy comes *down* 0.94 -> 0.82. Widening the
## range does not touch the near field at all — at 0.5 m the window term is
## 1.00 either way — so the bright disc on the ceiling plate does not get
## brighter; only the tail that was being clipped comes back. Measured on the
## deck beneath a luminaire that is 0.069 -> 0.101, and in the room's corners,
## which were receiving a literal zero because they lay outside 5.6 m, it is zero
## -> a small but nonzero value. Corners that are dark are fine; corners that are
## algebraically excluded are a hole.
##
## Second, the ceiling was one row of three luminaires down the middle of a
## 10.4 m-wide room, so the two side thirds had no overhead at all and the side
## walls were lit only by one cove lamp each at the cove's midpoint — a 7.3 m
## linear fixture represented by a single point at its centre. The overheads
## become two rows of three (x = 3.2 and x = 8.0, the rows the console line and
## the chair line actually sit under) and each cove gets three lamps down its
## length instead of one. That is six overheads and six cove lamps where there
## were three and two.
##
## More lights is the opposite of more fill here, and the distinction is the
## whole point: a *uniform* lift is one term added to every surface regardless of
## where it is, which is what the flat ambient the global pass removed used to
## do. Six discrete pools with real falloff between them put a gradient across
## the deck and let a player tell where the light is coming from. The total lens
## area is deliberately held roughly constant while their number doubles — each
## lens goes 2.85 x 0.24 -> 1.85 x 0.20, so 2.05 m^2 becomes 2.22 m^2 — because
## `worklight` emission is what sets the blown top of this room's histogram and
## doubling the emissive area would have paid for the added structure with a
## wider bloom.
##
## Third, faces. An operator sits at z = 13.55 facing the window, so the only
## thing in the room in front of their face is `ConsoleGlow`, and at 1.83 m the
## 2.6 m range window was removing 43% of it — 0.067 arriving at a face. Range
## 2.6 -> 3.4 at unchanged 0.42 energy leaves the console top exactly as lit as
## it was and delivers 0.093 to the face. Range, again, not energy: the console
## panel is 0.4 m from that light and any energy raise lands there first.
func _build_operations_lighting(room: Node3D) -> void:
	var lighting := Node3D.new()
	lighting.name = "LocalizedLighting"
	lighting.set_meta("forward_plus_local_lighting", true)
	room.add_child(lighting)
	var lens_transforms: Array[Transform3D] = []
	for luminaire_x in [3.2, 8.0]:
		for z_position in [11.15, 14.15, 16.15]:
			_box(lighting, "CeilingLuminaireBody", Vector3(float(luminaire_x), 4.47, float(z_position)), Vector3(2.15, 0.11, 0.44), _materials["hull_dark"], false)
			var lens_transform := Transform3D(
				Basis.IDENTITY,
				Vector3(float(luminaire_x), 4.405, float(z_position))
			)
			var lens_anchor := Marker3D.new()
			lens_anchor.name = "CeilingLuminaireLens"
			lens_anchor.transform = lens_transform
			lens_anchor.set_meta("ceiling_luminaire_lens_anchor", true)
			lighting.add_child(lens_anchor)
			lens_transforms.append(lens_transform)
			_omni_light(lighting, "OperationsPoolLight", Vector3(float(luminaire_x), 4.0, float(z_position)), Color("d9f6f3"), 0.82, 9.0)
	_ceiling_luminaire_lens_batch = _multimesh_rounded_box(
		lighting,
		"CeilingLuminaireLensRenderBatch",
		CEILING_LUMINAIRE_LENS_SIZE,
		_materials["worklight"],
		lens_transforms
	)
	for cove_x in [0.86, 10.34]:
		var warm_side := float(cove_x) > 5.6
		var cove_rail := _beam_between(
			lighting,
			"WarmCeilingCoveRail" if warm_side else "CoolCeilingCoveRail",
			Vector3(float(cove_x), 4.3, 9.55),
			Vector3(float(cove_x), 4.3, 16.85),
			0.055,
			_materials["amber_light"] if warm_side else _materials["cyan_dim"],
			false
		)
		if warm_side:
			_mark_authored_interior_warmth(cove_rail, &"operations_cove_source")
	# The two coves are the room's own fixtures and were lighting nothing. Giving
	# the starboard cove a warm lamp and the port cove a cool one is the cheapest
	# honest way to get two colour temperatures across a room: the walls now
	# gradate from warm on one side to cool on the other instead of sitting at
	# one value, and a viewer reads that as two luminaires rather than as tint.
	#
	# Three lamps per cove rather than one. A cove is a 7.3 m line of light and it
	# was standing in for itself with a single point at its midpoint, so the two
	# ends of both side walls — which is where this room goes to black first —
	# were outside the lamp entirely. Energy per lamp comes down with the count
	# (warm 0.5 -> 0.34, cool 0.42 -> 0.29) so the midpoint is not brighter than
	# it was; what changes is that the fixture now lights its own length.
	for cove_z in [10.7, 13.2, 15.7]:
		_mark_authored_interior_warmth(
			_fixture_practical(
				lighting,
				"CoveSpillWarm",
				Vector3(10.1, 4.05, float(cove_z)),
				OPERATIONS_WARM_COVE_COLOR,
				0.34,
				6.4
			),
			&"operations_cove_spill"
		)
		_fixture_practical(lighting, "CoveSpillCool", Vector3(1.1, 4.05, float(cove_z)), Color("bfeef2"), 0.29, 6.4)
	# Under-console task light. Three consoles standing on a deck with nothing
	# below waist height meant the plinths, kick strips and chair bases were the
	# darkest band in the room. This is a tungsten-temperature wash at working
	# height, which is what a real operations floor has and what gives the room a
	# second hue where a player actually stands.
	#
	# The third one is for the coordinator chair. That chair sits alone at
	# (1.7, 12.0), yawed off the console line, and it was the one seat in the room
	# with no fixture within range of it in any direction — the two washes at
	# z = 14.4 start 2.4 m away and the nearest overhead was 4 m up and 3.9 m
	# across. It is the same lamp as the other two, sited at that chair's own
	# working position.
	for task_position in [Vector3(4.1, 1.05, 14.4), Vector3(8.7, 1.05, 14.4), Vector3(2.0, 1.05, 12.4)]:
		_fixture_practical(lighting, "ConsoleTaskWash", task_position, Color("f6c98c"), 0.44, 5.2)
	_box(lighting, "DoorThresholdLight", Vector3(2.2, 0.065, 9.36), Vector3(2.35, 0.04, 0.09), _materials["cyan"], false)
	# Same range correction as the overheads and for the same reason: at 3.8 m
	# range from 2.6 m up, the threshold this lamp exists to light was sitting at
	# 0.68 of the window and receiving 0.053. Range 3.8 -> 5.6, energy unchanged.
	_omni_light(lighting, "DoorPoolLight", Vector3(2.2, 2.6, 10.0), Color("72d9d9"), 0.35, 5.6)


## Operations-room content.
##
## The look pass recorded that this room "barely moved", and the lighting pass
## that followed it fixed the illumination — plated walls read across their full
## height, chair forms are legible, deck plates and floor seams are back. What was
## left is that there is nothing in here to light. Measured on the built room, the
## whole southern third — x = 4.6 … 10.0, z = 9.5 … 12.6, about 17 square metres
## between the door and the chair line — was bare deck, and the west strip and the
## north-west corner were bare with it. Three consoles, four chairs and a service
## wall is the furniture of a room; it is not the apparatus of an operations room,
## and a player walking in read an empty box with some seating in it.
##
## What this adds is the apparatus, sited where the room already had space for it:
##
##   A **watch rack bank** of three floor-standing equipment racks along the south
##   wall, under a cable tray that runs to the service wall — the room's plant.
##   A **module status board** above them, carrying the aft module's own route
##   schematic in relief with an annunciator row under it.
##   A **traffic plot table** in the middle of the cleared third: a chart table
##   with a lit plot disc, a graticule, ship tokens, an indexing sweep arm, chart
##   rolls stowed underneath, and the things people leave on a table.
##   A **coordinator desk** in front of the one chair that had nothing to work at.
##   A **chart press and notice board** down the west wall.
##   A **refreshment stand** in the dead north-west corner.
##   Personal traces on the console line and the coordinator's chair.
##
## Three rules this pass holds itself to, all of them learned elsewhere in the
## station today:
##
##   **Nothing floats.** Every piece either stands on the deck with its lowest
##   drawn face at y = 0.00 … 0.02, or shares volume with the piece it is mounted
##   on. The mounted ones are on the seated roster in
##   `tests/station_presentation_defect_witness_test.gd` so the class cannot come
##   back silently.
##   **Anything solid a player can reach is solid.** Every rack, table, desk,
##   chest, counter and bin carries World collision at its drawn size, so nothing
##   here is a hologram you can walk through — and equally, no collider exists
##   without geometry drawn at it.
##   **Structure is chamfered kit stock on the registered panel recipe.** Nothing
##   below is a raw `BoxMesh` with a flat scalar colour; the plate family carries
##   every structural surface, and only cues, glass, paper and cloth stay out of
##   it, exactly as they already did.
##
## ## State is carried by hardware
##
## The rack bank is the room's worked example of the rule the dock arms
## established: which rack is in service is told by what the hardware is *doing*,
## not by what colour it is painted. Racks 1 and 3 are made up — fascia on,
## breaker lever thrown up, status lens lit, a practical throwing that lens's own
## colour onto the plate around it. Rack 2 is isolated for work: its fascia is
## physically off and leaning against the neighbouring rack where somebody put it,
## its card cages are open to the room, its breaker lever is thrown down, a
## lockout hasp and tag hang off the open bay, its lens is dead and it throws no
## light at all. Turn every material in the room to greyscale and you can still
## tell at a glance which rack is out. The same idea runs the annunciator row on
## the status board — flags stand up or hang down — and the plot tokens, whose
## pins stand proud for inbound traffic and sit flush for a berthed hull.
func _build_operations_content(room: Node3D) -> void:
	var content := Node3D.new()
	content.name = "OperationsContent"
	room.add_child(content)
	_build_watch_rack_bank(content)
	_build_module_status_board(content)
	_build_traffic_plot_table(content)
	_build_coordinator_desk(content)
	_build_chart_press(content)
	_build_refreshment_stand(content)
	_build_console_line_traces(content)


## Three equipment racks on the south wall, and the tray that feeds them.
##
## The bank stands from the deck to 2.10 m against the wall face at z = 9.31, so
## it is a solid mass a player walks around rather than a decal on the bulkhead.
## Each rack is four plug-in modules behind a fascia; the middle one is opened up
## for work. See the hardware-state note on `_build_operations_content`.
func _build_watch_rack_bank(content: Node3D) -> void:
	var bank := Node3D.new()
	bank.name = "WatchRackBank"
	content.add_child(bank)
	var rack_card_transforms: Array[Transform3D] = []

	# The tray is what makes three boxes read as installed plant rather than as
	# three boxes. It runs the length of the bank and turns east into the service
	# wall, which is where this room's cabling already goes.
	_beam_between(bank, "RackCableTray", Vector3(4.05, 2.44, 9.58), Vector3(10.15, 2.44, 9.58), 0.085, _materials["hull_dark"], false)
	_beam_between(bank, "RackCableTrayRiser", Vector3(10.15, 2.44, 9.58), Vector3(10.15, 2.44, 10.35), 0.075, _materials["hull_dark"], false)
	_rack_cable_tray_clamp_mesh = _torus_mesh(
		RACK_CABLE_TRAY_CLAMP_INNER_RADIUS,
		RACK_CABLE_TRAY_CLAMP_OUTER_RADIUS,
		RACK_CABLE_TRAY_CLAMP_RINGS,
		RACK_CABLE_TRAY_CLAMP_RING_SEGMENTS
	)
	for clamp_position in RACK_CABLE_TRAY_CLAMP_POSITIONS:
		_interface_collar(
			bank,
			"RackCableTrayClamp",
			clamp_position as Vector3,
			RACK_CABLE_TRAY_CLAMP_INNER_RADIUS,
			RACK_CABLE_TRAY_CLAMP_OUTER_RADIUS,
			_materials["brass"],
			Vector3(0, 0, 90),
			_rack_cable_tray_clamp_mesh
		)

	for rack_index in 3:
		var rack_x := 5.15 + float(rack_index) * 1.75
		var in_service := rack_index != 1
		_box(bank, "WatchRackFrame%02d" % rack_index, Vector3(rack_x, 1.05, 9.61), Vector3(1.62, 2.10, 0.60), _materials["mid_grey"])
		_box(bank, "WatchRackKick%02d" % rack_index, Vector3(rack_x, 0.06, 9.90), Vector3(1.50, 0.12, 0.05), _materials["rubber"], false)
		_box(bank, "WatchRackCap%02d" % rack_index, Vector3(rack_x, 2.13, 9.61), Vector3(1.70, 0.06, 0.66), _materials["hull_dark"], false)
		# Cable drops from the tray into each rack head.
		_beam_between(
			bank,
			"RackCableDrop%02d" % rack_index,
			Vector3(rack_x - 0.34, 2.40, 9.58),
			Vector3(rack_x - 0.34, 2.16, 9.62),
			0.035,
			_materials["copper"],
			false
		)
		_beam_between(
			bank,
			"RackCableDropReturn%02d" % rack_index,
			Vector3(rack_x + 0.34, 2.40, 9.58),
			Vector3(rack_x + 0.34, 2.16, 9.62),
			0.035,
			_materials["copper"],
			false
		)

		if in_service:
			_box(bank, "RackFascia%02d" % rack_index, Vector3(rack_x, 1.12, 9.915), Vector3(1.44, 1.90, 0.05), _materials["hull_dark"], false)
		else:
			# The opened rack. Its fascia is not hidden, it is somewhere: leaned
			# against the next rack along, bottom edge on the deck, top edge resting
			# on that rack's front face.
			_box(bank, "RackRemovedFascia", Vector3(rack_x + 1.75, 0.925, 10.135), Vector3(1.44, 1.90, 0.05), _materials["hull_dark"], false, Vector3(13, 0, 0))
			# The opened rack shows its card cages standing at the face the fascia came
			# off, not sunk inside a solid box. Built inside first, where every one of
			# them was buried in the 0.60 m frame and the "open" rack read as a plain
			# grey slab with a red tag hanging on it.
			_box(bank, "RackOpenBackplane", Vector3(rack_x, 1.12, 9.925), Vector3(1.44, 1.90, 0.03), _materials["graphite"], false)
			for loom_index in 3:
				_beam_between(
					bank,
					"RackOpenLoom%02d" % loom_index,
					Vector3(rack_x - 0.55 + float(loom_index) * 0.55, 1.94, 9.945),
					Vector3(rack_x - 0.40 + float(loom_index) * 0.55, 0.34, 9.945),
					0.028,
					_materials["copper"],
					false
				)
			# Lockout hasp and its tag, hung off the open bay's edge.
			_torus(bank, "RackLockoutHasp", Vector3(rack_x - 0.66, 1.62, 9.955), 0.035, 0.055, _materials["brass"], Vector3(0, 0, 90))
			# Chain radius 0.008 -> 0.018. Photographed first at 0.008, where it was
			# thinner than a pixel at any distance a player reads this bank from and
			# the tag under it read as a red card floating in front of the rack —
			# which is the exact defect class this module is under orders to keep out.
			_beam_between(bank, "RackLockoutChain", Vector3(rack_x - 0.66, 1.60, 9.955), Vector3(rack_x - 0.66, 1.47, 9.955), 0.018, _materials["brass"], false)
			_box(bank, "RackLockoutTag", Vector3(rack_x - 0.66, 1.38, 9.955), Vector3(0.15, 0.23, 0.008), _materials["red"], false, Vector3(0, 0, -6))

		for module_index in 4:
			var module_y := 0.46 + float(module_index) * 0.44
			# The opened rack keeps its card cages but loses the two modules that
			# were pulled; that empty pair is what the fascia came off for.
			if not in_service and module_index != 0 and module_index != 3:
				_box(bank, "RackCardCage%02d" % module_index, Vector3(rack_x, module_y, 9.955), Vector3(1.24, 0.30, 0.05), _materials["graphite"], false)
				for card_index in 7:
					var card_position := Vector3(
						rack_x - 0.54 + float(card_index) * 0.18,
						module_y,
						10.000
					)
					var card_anchor := Marker3D.new()
					card_anchor.name = "RackCard%02d%02d" % [module_index, card_index]
					card_anchor.position = card_position
					bank.add_child(card_anchor)
					rack_card_transforms.append(Transform3D(Basis.IDENTITY, card_position))
				continue
			_box(
				bank,
				"RackModule%02d%02d" % [rack_index, module_index],
				Vector3(rack_x, module_y, 9.945),
				Vector3(1.30, 0.32, 0.07),
				_materials["panel_light"] if module_index % 2 else _materials["off_white"],
				false
			)
			_box(bank, "RackModuleVent", Vector3(rack_x - 0.36, module_y, 9.985), Vector3(0.46, 0.17, 0.02), _materials["graphite"], false)
			_box(bank, "RackModuleReadout", Vector3(rack_x + 0.30, module_y + 0.03, 9.985), Vector3(0.40, 0.10, 0.015), _materials["screen_dark"], false)
			for knob_index in 2:
				_cylinder(
					bank,
					"RackModuleKnob",
					Vector3(rack_x + 0.16 + float(knob_index) * 0.20, module_y - 0.08, 9.995),
					0.032,
					0.03,
					_materials["brass"],
					false,
					Vector3(90, 0, 0)
				)

		# Status lens and breaker. Both read the same state two different ways, and
		# neither of them is a repaint: the lit lens throws a real practical, the
		# dead one throws nothing, and the lever is physically in a different place.
		_box(
			bank,
			"RackStatusLens%02d" % rack_index,
			Vector3(rack_x - 0.30, 2.02, 9.985),
			Vector3(0.52, 0.07, 0.02),
			_materials["cyan"] if in_service else _materials["screen_dark"],
			false
		)
		if in_service:
			_fixture_practical(
				bank,
				"WatchRackStatusSpill",
				Vector3(rack_x - 0.30, 1.94, 10.12),
				Color("7fe0e6"),
				0.30,
				2.0
			)
		_box(bank, "RackBreakerBody%02d" % rack_index, Vector3(rack_x + 0.56, 2.02, 9.965), Vector3(0.26, 0.30, 0.10), _materials["hull_dark"], false)
		_box(
			bank,
			"RackBreakerLever%02d" % rack_index,
			Vector3(rack_x + 0.56, 2.11 if in_service else 1.93, 10.005),
			Vector3(0.06, 0.20, 0.06),
			_materials["brass"],
			false,
			Vector3(-26 if in_service else 26, 0, 0)
		)

	_rack_card_batch = _multimesh_rounded_box(
		bank,
		"RackCardRenderBatch",
		RACK_CARD_SIZE,
		_materials["panel_light"],
		rack_card_transforms
	)


## The room's own status board, above the rack bank.
##
## Deliberately not a copy of the registry pod's dispatch board: that one is a
## berth register and lights one tile per registered berth. This is the *aft
## module's* board, and what it draws is this module's route graph — approach,
## junction, stair, upper deck, operations, and the deferred VIP branch that dead
## ends. It is the one place in the station where a player can see the shape of
## the building they are standing in.
func _build_module_status_board(content: Node3D) -> void:
	var board := Node3D.new()
	board.name = "ModuleStatusBoard"
	content.add_child(board)

	# Every z below is measured off the board's *room-facing* face at z = 9.41, not
	# off the wall at 9.31. The first build had the whole board authored on the
	# wrong side of that plane — schematic, annunciators, frame and legend all at
	# z < 9.31 — so the board was buried inside the bulkhead and rendered to nobody.
	# Photographed as a bare plated wall with a brass rectangle drawn on it before
	# this was found, which is exactly the way that class of mistake hides: the one
	# piece thick enough to poke through was the frame.
	#
	# The body is `mid_grey` plate standing 0.10 m proud of the wall, and the chart
	# field on it is `graphite`, which is the module's matte non-plate trim. A board
	# built from the wall's own plate at the wall's own depth is invisible under
	# world triplanar, because the panel field runs straight through it.
	_box(board, "StatusBoardBody", Vector3(6.90, 3.20, 9.36), Vector3(5.40, 1.30, 0.10), _materials["mid_grey"], false)
	_box(board, "StatusBoardField", Vector3(6.90, 3.20, 9.425), Vector3(5.08, 1.02, 0.03), _materials["graphite"], false)
	for rail_y in [2.53, 3.87]:
		_beam_between(board, "StatusBoardRail", Vector3(4.16, float(rail_y), 9.43), Vector3(9.64, float(rail_y), 9.43), 0.042, _materials["brass"], false)
	for rail_x in [4.16, 9.64]:
		_beam_between(board, "StatusBoardStile", Vector3(float(rail_x), 2.53, 9.43), Vector3(float(rail_x), 3.87, 9.43), 0.042, _materials["brass"], false)

	# Route schematic in relief: approach, junction, stair, upper deck, operations,
	# and the deferred branch that dead ends. Board-space X/Y, then the links.
	var schematic_nodes := [
		[4.95, 3.36, "cyan"],
		[6.05, 3.36, "cyan"],
		[7.15, 3.36, "cyan"],
		[7.15, 2.98, "cyan"],
		[8.35, 3.36, "gold"],
		[8.90, 2.98, "screen_dark"],
	]
	var schematic_links := [[0, 1], [1, 2], [2, 3], [2, 4], [4, 5]]
	for link in schematic_links:
		var from_node: Array = schematic_nodes[int(link[0])]
		var to_node: Array = schematic_nodes[int(link[1])]
		var from_point := Vector2(float(from_node[0]), float(from_node[1]))
		var to_point := Vector2(float(to_node[0]), float(to_node[1]))
		var span := to_point - from_point
		var midpoint := (from_point + to_point) * 0.5
		_box(
			board,
			"StatusBoardLink",
			Vector3(midpoint.x, midpoint.y, 9.448),
			Vector3(span.length(), 0.055, 0.018),
			_materials["off_white"],
			false,
			Vector3(0, 0, rad_to_deg(atan2(span.y, span.x)))
		)
	for node_index in schematic_nodes.size():
		var schematic_node: Array = schematic_nodes[node_index]
		var node_x := float(schematic_node[0])
		var node_y := float(schematic_node[1])
		_box(board, "StatusBoardNode%02d" % node_index, Vector3(node_x, node_y, 9.452), Vector3(0.30, 0.30, 0.03), _materials["off_white"], false)
		_box(
			board,
			"StatusBoardNodeLens%02d" % node_index,
			Vector3(node_x, node_y, 9.472),
			Vector3(0.18, 0.18, 0.014),
			_materials[str(schematic_node[2])],
			false
		)

	# Annunciator row. Six units; four made up and lit, one warm and pulsing for
	# working traffic, one dropped and dark. The flag position is the state: a
	# dropped flag hangs clear of the board's bottom edge, so the row still reads
	# as five up and one down with every lamp in the room switched off.
	var annunciator_states := ["up", "up", "pulse", "up", "up", "down"]
	for annunciator_index in annunciator_states.size():
		var annunciator_x := 4.75 + float(annunciator_index) * 0.86
		var state := str(annunciator_states[annunciator_index])
		_box(board, "AnnunciatorBody%02d" % annunciator_index, Vector3(annunciator_x, 2.72, 9.46), Vector3(0.62, 0.24, 0.06), _materials["mid_grey"], false)
		var lens_material: Material = _materials["screen_dark"]
		if state == "up":
			lens_material = _materials["cyan"]
		elif state == "pulse":
			lens_material = _materials["gold"]
		var lens := _box(
			board,
			"AnnunciatorLens%02d" % annunciator_index,
			Vector3(annunciator_x, 2.72, 9.494),
			Vector3(0.48, 0.14, 0.014),
			lens_material,
			false
		) as MeshInstance3D
		if state == "pulse":
			_register_content_lens(lens, "screen_dark", "gold", 2.4, 1.5, 0.0)
		_box(
			board,
			"AnnunciatorFlag%02d" % annunciator_index,
			Vector3(annunciator_x, 2.89 if state != "down" else 2.55, 9.47),
			Vector3(0.46, 0.10, 0.04),
			_materials["off_white"] if state != "down" else _materials["graphite"],
			false
		)

	_text_sign(board, "AFT MODULE STATUS", Vector3(6.90, 3.78, 9.42), Vector3.ZERO, 0.16, _materials["cyan"])
	# Two washes rather than one, for the same reason the coves went from one lamp
	# to three: this board is 5.4 m wide and a single point at its centre lit the
	# middle metre and left both ends outside the range that matters. Sited at the
	# two schematic clusters, 0.42 m proud of the board face, angled at nothing —
	# they are omnis, so what they do is put a gradient across the panel rather than
	# a disc in the middle of it. Photographed dark first at one 0.34 lamp; this is
	# the fix, and it is placement rather than gain, since per-lamp energy is
	# unchanged.
	for wash_x in [5.45, 8.35]:
		_fixture_practical(content, "StatusBoardWash", Vector3(float(wash_x), 3.05, 9.78), Color("9fe6ea"), 0.34, 3.8)


## The room's centrepiece: a traffic plot table in the cleared southern third.
##
## Sited at (6.90, 11.60) so it stands between the rack bank behind it and the
## chair line in front, with 1.0 m of walkway either side. The table is solid at
## its drawn size — base, both pedestals and the top all carry World collision —
## because a chart table a player walks through is worse than no chart table.
func _build_traffic_plot_table(content: Node3D) -> void:
	var table := Node3D.new()
	table.name = "TrafficPlotTable"
	content.add_child(table)

	_box(table, "PlotTableBase", Vector3(6.90, 0.05, 11.60), Vector3(2.10, 0.10, 1.10), _materials["graphite"])
	for pedestal_side in [-1.0, 1.0]:
		_box(table, "PlotTablePedestal", Vector3(6.90 + float(pedestal_side) * 0.72, 0.50, 11.60), Vector3(0.34, 0.80, 0.94), _materials["hull_dark"])
	_box(table, "PlotTableTop", Vector3(6.90, 0.95, 11.60), Vector3(2.50, 0.10, 1.45), _materials["panel_light"])
	_box(table, "PlotTableApron", Vector3(6.90, 0.84, 11.60), Vector3(2.36, 0.12, 1.32), _materials["mid_grey"], false)
	# Working surface either side of the plot: a bordered chart laid out flat under
	# a dark edge trim. Photographed first without them, where the 2.5 x 1.45 m top
	# read as one unbroken white slab with a lit disc dropped into it.
	for chart_side in [-1.0, 1.0]:
		var chart_x := 6.90 + float(chart_side) * 0.98
		_box(table, "PlotChartBorder", Vector3(chart_x, 1.003, 11.60), Vector3(0.54, 0.008, 1.12), _materials["graphite"], false)
		_box(table, "PlotChartSheet", Vector3(chart_x, 1.010, 11.60), Vector3(0.48, 0.008, 1.04), _materials["paper"], false, Vector3(0, float(chart_side) * 1.5, 0))
		_box(table, "PlotTableEdgeTrim", Vector3(6.90, 0.999, 11.60 + float(chart_side) * 0.695), Vector3(2.48, 0.014, 0.055), _materials["graphite"], false)

	# Stowage in the knee space between the pedestals: rolled charts in a cradle.
	_box(table, "ChartCradle", Vector3(6.90, 0.34, 11.60), Vector3(1.00, 0.32, 0.90), _materials["hull_dark"], false)
	for roll_index in 4:
		_cylinder(
			table,
			"StowedChartRoll%02d" % roll_index,
			Vector3(6.62 + float(roll_index % 3) * 0.28, 0.38 + (0.10 if roll_index == 3 else 0.0), 11.60),
			0.046,
			0.84,
			_materials["paper"],
			false,
			Vector3(90, 0, 0)
		)

	# The plot itself. A recessed disc with a lit graticule, ringed in brass.
	_cylinder(table, "PlotDisc", Vector3(6.90, 1.012, 11.60), 0.60, 0.03, _materials["screen_dark"], false)
	_torus(table, "PlotDiscRim", Vector3(6.90, 1.015, 11.60), 0.60, 0.665, _materials["brass"])
	for ring_radius in [0.20, 0.38, 0.56]:
		_torus(table, "PlotGraticuleRing", Vector3(6.90, 1.030, 11.60), float(ring_radius), float(ring_radius) + 0.011, _materials["cyan_dim"])
	for bearing in [0.0, 45.0, 90.0, 135.0]:
		_box(table, "PlotGraticuleBearing", Vector3(6.90, 1.029, 11.60), Vector3(0.012, 0.006, 1.14), _materials["cyan_dim"], false, Vector3(0, float(bearing), 0))
	_cylinder(table, "PlotHub", Vector3(6.90, 1.055, 11.60), 0.075, 0.09, _materials["hull_dark"], false)

	# Traffic tokens. Bearing/range on the plot is where the hull is; the pin is
	# whether it is still inbound. Berthed hulls sit flush, inbound stand proud.
	var tokens := [
		[18.0, 0.50, true],
		[104.0, 0.34, false],
		[168.0, 0.52, false],
		[238.0, 0.26, false],
		[302.0, 0.47, true],
	]
	for token_index in tokens.size():
		var token: Array = tokens[token_index]
		var bearing_radians := deg_to_rad(float(token[0]))
		var token_range := float(token[1])
		var inbound := bool(token[2])
		var token_position := Vector3(
			6.90 + cos(bearing_radians) * token_range,
			1.039,
			11.60 + sin(bearing_radians) * token_range
		)
		_cylinder(table, "PlotToken%02d" % token_index, token_position, 0.055, 0.028, _materials["panel_light"], false)
		_cylinder(
			table,
			"PlotTokenPin%02d" % token_index,
			token_position + Vector3(0.0, 0.09 if inbound else 0.018, 0.0),
			0.011 if inbound else 0.03,
			0.16 if inbound else 0.014,
			_materials["gold"] if inbound else _materials["cyan"],
			false
		)

	# Rim rail. A chart table on a station gets one, and it gives the top an edge
	# that catches the ceiling rows instead of reading as a flat slab.
	for rail_side in [-1.0, 1.0]:
		var rail_z := 11.60 + float(rail_side) * 0.70
		for post_x in [5.78, 8.02]:
			_cylinder(table, "PlotRimPost", Vector3(float(post_x), 1.06, rail_z), 0.022, 0.20, _materials["brass"], false)
		_beam_between(table, "PlotRimRail", Vector3(5.78, 1.15, rail_z), Vector3(8.02, 1.15, rail_z), 0.024, _materials["brass"], false)

	# The indexing sweep. One assembly, driven from `_process`; see
	# `_update_operations_content`.
	var sweep := Node3D.new()
	sweep.name = "PlotSweepArm"
	sweep.position = Vector3(6.90, 1.075, 11.60)
	table.add_child(sweep)
	_sweep_arm = sweep
	_box(sweep, "SweepBeam", Vector3(0.0, 0.0, 0.30), Vector3(0.045, 0.022, 0.60), _materials["brass"], false)
	_box(sweep, "SweepHead", Vector3(0.0, -0.005, 0.575), Vector3(0.11, 0.05, 0.11), _materials["hull_dark"], false)
	_box(sweep, "SweepLens", Vector3(0.0, -0.032, 0.575), Vector3(0.06, 0.014, 0.06), _materials["worklight"], false)
	_fixture_practical(sweep, "PlotSweepLamp", Vector3(0.0, -0.07, 0.575), Color("bfeef2"), 0.22, 1.5)

	# What a working table has on it.
	_box(table, "PlotLogbookCover", Vector3(5.98, 1.012, 12.06), Vector3(0.32, 0.024, 0.24), _materials["graphite"], false, Vector3(0, 14, 0))
	_box(table, "PlotLogbookPages", Vector3(5.98, 1.031, 12.06), Vector3(0.29, 0.016, 0.21), _materials["paper"], false, Vector3(0, 14, 0))
	_cylinder(table, "PlotDutyMug", Vector3(7.92, 1.052, 12.12), 0.045, 0.105, _materials["off_white"], false)
	_torus(table, "PlotDutyMugHandle", Vector3(7.985, 1.055, 12.12), 0.022, 0.042, _materials["off_white"], Vector3(0, 0, 90))
	_box(table, "PlotGlove", Vector3(6.06, 1.022, 11.12), Vector3(0.10, 0.044, 0.23), _materials["fabric"], false, Vector3(0, -24, 0))
	_box(table, "PlotGloveSecond", Vector3(6.22, 1.021, 11.02), Vector3(0.10, 0.042, 0.23), _materials["fabric"], false, Vector3(0, -6, 0))
	_box(table, "PlotDividers", Vector3(7.72, 1.008, 11.10), Vector3(0.20, 0.016, 0.03), _materials["brass"], false, Vector3(0, 32, 0))
	# The plot glass is the only lit surface on the table, and in this renderer a
	# lit surface illuminates nothing, so without this the table's own light landed
	# on nobody's face and it read as a printed disc. Sited above the plot so it
	# washes the rim, the tokens and whoever is leaning over them.
	_fixture_practical(table, "PlotTableGlow", Vector3(6.90, 1.24, 11.60), Color("93e4ea"), 0.30, 2.6)


## The coordinator's working position.
##
## The fourth chair sat alone at (1.7, 12.0), yawed off the console line, with
## nothing in front of it — a chair facing a bare deck. The desk goes exactly
## where that chair is already looking, 1.09 m out along its own facing, and is
## kept east of x = 2.54 so it never stands in the doorway walk line at x = 2.2.
func _build_coordinator_desk(content: Node3D) -> void:
	var desk := Node3D.new()
	desk.name = "CoordinatorDesk"
	desk.position = Vector3(3.10, 0.0, 11.65)
	desk.rotation_degrees.y = -72.0
	content.add_child(desk)

	_box(desk, "CoordinatorDeskBody", Vector3(0.0, 0.36, 0.0), Vector3(1.50, 0.72, 0.68), _materials["mid_grey"])
	_box(desk, "CoordinatorDeskTop", Vector3(0.0, 0.76, 0.0), Vector3(1.66, 0.08, 0.82), _materials["panel_light"])
	_box(desk, "CoordinatorDeskKick", Vector3(0.0, 0.06, -0.35), Vector3(1.32, 0.11, 0.05), _materials["rubber"], false)
	for drawer_side in [-1.0, 1.0]:
		var drawer_x := float(drawer_side) * 0.36
		_box(desk, "CoordinatorDeskDrawer", Vector3(drawer_x, 0.52, -0.35), Vector3(0.62, 0.22, 0.04), _materials["off_white"], false)
		_beam_between(desk, "CoordinatorDeskPull", Vector3(drawer_x - 0.19, 0.52, -0.38), Vector3(drawer_x + 0.19, 0.52, -0.38), 0.018, _materials["brass"], false)

	# Task lamp. The room's overheads are 4 m up and 3 m away from this corner.
	_cylinder(desk, "CoordinatorLampStalk", Vector3(-0.62, 1.02, 0.16), 0.022, 0.44, _materials["hull_dark"], false)
	_box(desk, "CoordinatorLampHead", Vector3(-0.62, 1.255, 0.055), Vector3(0.20, 0.09, 0.15), _materials["hull_dark"], false, Vector3(24, 0, 0))
	_box(desk, "CoordinatorLampLens", Vector3(-0.62, 1.208, 0.038), Vector3(0.15, 0.02, 0.10), _materials["amber_light"], false, Vector3(24, 0, 0))
	_fixture_practical(desk, "CoordinatorLampSpill", Vector3(-0.62, 1.10, -0.02), Color("f6c98c"), 0.34, 2.2)

	# The duty log, open, because somebody is on watch.
	_box(desk, "DutyLogCover", Vector3(-0.08, 0.812, -0.02), Vector3(0.54, 0.026, 0.34), _materials["graphite"], false, Vector3(0, 6, 0))
	_box(desk, "DutyLogLeaf", Vector3(-0.21, 0.831, -0.02), Vector3(0.26, 0.014, 0.31), _materials["paper"], false, Vector3(0, 6, -3))
	_box(desk, "DutyLogLeafFacing", Vector3(0.05, 0.831, -0.02), Vector3(0.26, 0.014, 0.31), _materials["paper"], false, Vector3(0, 6, 3))
	_cylinder(desk, "DutyLogPen", Vector3(-0.06, 0.846, 0.14), 0.008, 0.16, _materials["brass"], false, Vector3(0, 74, 90))

	# Handset and its cord, which is what an operations desk actually is.
	_box(desk, "DeskHandsetCradle", Vector3(0.52, 0.834, 0.12), Vector3(0.17, 0.07, 0.24), _materials["hull_dark"], false)
	_box(desk, "DeskHandset", Vector3(0.52, 0.897, 0.12), Vector3(0.10, 0.07, 0.25), _materials["graphite"], false)
	_beam_between(desk, "DeskHandsetCord", Vector3(0.52, 0.83, 0.24), Vector3(0.62, 0.60, 0.34), 0.012, _materials["copper"], false)
	_box(desk, "DeskManualStack", Vector3(0.34, 0.826, -0.22), Vector3(0.24, 0.05, 0.32), _materials["paper"], false, Vector3(0, -9, 0))
	_box(desk, "DeskManualStackUpper", Vector3(0.33, 0.868, -0.21), Vector3(0.23, 0.04, 0.30), _materials["graphite"], false, Vector3(0, 4, 0))

	# Headset on a hook on the desk end, where a watch-keeper leaves it.
	_cylinder(desk, "DeskHeadsetHook", Vector3(0.83, 0.70, 0.02), 0.016, 0.09, _materials["brass"], false, Vector3(0, 0, 90))
	_torus(desk, "DeskHeadsetBand", Vector3(0.855, 0.605, 0.02), 0.065, 0.095, _materials["graphite"], Vector3(0, 0, 90))
	for cup_side in [-1.0, 1.0]:
		_cylinder(desk, "DeskHeadsetCup", Vector3(0.855, 0.545, 0.02 + float(cup_side) * 0.078), 0.036, 0.03, _materials["fabric"], false, Vector3(90, 0, 0))


## Chart press and notice board down the bare west wall.
func _build_chart_press(content: Node3D) -> void:
	var press := Node3D.new()
	press.name = "ChartPress"
	press.position = Vector3(0.95, 0.0, 14.60)
	content.add_child(press)

	_box(press, "ChartPressBody", Vector3(0.0, 0.47, 0.0), Vector3(0.68, 0.94, 1.76), _materials["mid_grey"])
	_box(press, "ChartPressTop", Vector3(0.0, 0.975, 0.0), Vector3(0.76, 0.07, 1.86), _materials["panel_light"])
	_box(press, "ChartPressKick", Vector3(0.05, 0.06, 0.0), Vector3(0.60, 0.12, 1.80), _materials["rubber"], false)
	for drawer_index in 5:
		var drawer_y := 0.17 + float(drawer_index) * 0.16
		_box(press, "ChartPressDrawer%02d" % drawer_index, Vector3(-0.345, drawer_y, 0.0), Vector3(0.04, 0.13, 1.62), _materials["off_white"], false)
		_beam_between(
			press,
			"ChartPressPull%02d" % drawer_index,
			Vector3(-0.375, drawer_y, -0.30),
			Vector3(-0.375, drawer_y, 0.30),
			0.017,
			_materials["brass"],
			false
		)
	# Rolls stacked on the press top, in a shallow pyramid so they read as stock.
	for roll_index in 4:
		var roll_offset := [-0.24, -0.12, 0.0, -0.18][roll_index] as float
		_cylinder(
			press,
			"ChartPressRoll%02d" % roll_index,
			Vector3(roll_offset, 1.055 if roll_index < 3 else 1.142, 0.0),
			0.05,
			1.46,
			_materials["paper"],
			false,
			Vector3(90, 0, 0)
		)
	_box(press, "ChartPressStrap", Vector3(-0.12, 1.10, 0.44), Vector3(0.40, 0.11, 0.05), _materials["fabric"], false)

	# Notice board, bolted flat to the west wall face at x = 0.59.
	_box(press, "NoticeBoard", Vector3(-0.335, 2.35, 0.0), Vector3(0.05, 1.05, 1.50), _materials["graphite"], false)
	for sheet_index in 7:
		var sheet_row := int(sheet_index / 4)
		var sheet_column := sheet_index % 4
		_box(
			press,
			"NoticeSheet%02d" % sheet_index,
			Vector3(-0.306, 2.62 - float(sheet_row) * 0.44, -0.54 + float(sheet_column) * 0.36),
			Vector3(0.012, 0.28, 0.21),
			_materials["paper"],
			false,
			Vector3(float(sheet_index % 3) * 2.5 - 2.5, 0, 0)
		)
	for pin_index in 2:
		_cylinder(
			press,
			"NoticePin%02d" % pin_index,
			Vector3(-0.292, 2.72, -0.54 + float(pin_index) * 1.08),
			0.012,
			0.02,
			_materials["gold"],
			false,
			Vector3(0, 0, 90)
		)
	_cylinder(press, "ClipboardHook", Vector3(-0.315, 1.615, -0.65), 0.02, 0.11, _materials["brass"], false, Vector3(0, 0, 90))
	_box(press, "Clipboard", Vector3(-0.295, 1.43, -0.65), Vector3(0.02, 0.36, 0.25), _materials["graphite"], false, Vector3(0, 0, -4))
	_box(press, "ClipboardSheet", Vector3(-0.283, 1.44, -0.65), Vector3(0.008, 0.30, 0.21), _materials["paper"], false, Vector3(0, 0, -4))
	_fixture_practical(press, "NoticeBoardWash", Vector3(0.12, 2.30, 0.0), Color("f0c48c"), 0.28, 2.4)


## Hot drinks in the dead north-west corner.
##
## Every crewed watch room has one and this corner had nothing in it: the console
## line stops at x = 2.03 and the window sill starts at z = 17.09, leaving a
## 1.4 x 0.9 m pocket that no fixture, route or piece of furniture used.
func _build_refreshment_stand(content: Node3D) -> void:
	var stand := Node3D.new()
	stand.name = "RefreshmentStand"
	stand.position = Vector3(1.32, 0.0, 16.52)
	content.add_child(stand)

	_box(stand, "RefreshmentCounter", Vector3(0.0, 0.44, 0.0), Vector3(1.34, 0.88, 0.60), _materials["mid_grey"])
	_box(stand, "RefreshmentTop", Vector3(0.0, 0.92, 0.0), Vector3(1.48, 0.08, 0.70), _materials["panel_light"])
	_box(stand, "RefreshmentKick", Vector3(0.0, 0.06, -0.31), Vector3(1.22, 0.11, 0.05), _materials["rubber"], false)
	for door_side in [-1.0, 1.0]:
		_box(stand, "RefreshmentDoor", Vector3(float(door_side) * 0.32, 0.50, -0.315), Vector3(0.58, 0.62, 0.04), _materials["off_white"], false)
		_beam_between(
			stand,
			"RefreshmentDoorPull",
			Vector3(float(door_side) * 0.32, 0.74, -0.345),
			Vector3(float(door_side) * 0.32, 0.60, -0.345),
			0.016,
			_materials["brass"],
			false
		)

	_cylinder(stand, "WaterUrn", Vector3(-0.36, 1.175, 0.0), 0.155, 0.44, _materials["off_white"], false)
	_torus(stand, "WaterUrnCollar", Vector3(-0.36, 0.985, 0.0), 0.155, 0.19, _materials["brass"])
	_cylinder(stand, "WaterUrnLid", Vector3(-0.36, 1.425, 0.0), 0.17, 0.05, _materials["mid_grey"], false)
	_box(stand, "WaterUrnSightGlass", Vector3(-0.235, 1.16, -0.10), Vector3(0.03, 0.24, 0.03), _materials["cyan_dim"], false)
	_beam_between(stand, "WaterUrnTap", Vector3(-0.36, 1.03, -0.14), Vector3(-0.36, 1.03, -0.25), 0.018, _materials["brass"], false)
	_cylinder(stand, "WaterUrnTapHandle", Vector3(-0.36, 1.10, -0.24), 0.012, 0.10, _materials["brass"], false)
	_box(stand, "MugTray", Vector3(0.28, 0.975, 0.0), Vector3(0.48, 0.03, 0.32), _materials["graphite"], false)
	for mug_index in 4:
		_cylinder(
			stand,
			"StowedMug%02d" % mug_index,
			Vector3(0.16 + float(mug_index / 2) * 0.24, 1.035, -0.08 + float(mug_index % 2) * 0.16),
			0.045,
			0.10,
			_materials["off_white"],
			false
		)
	_fixture_practical(stand, "RefreshmentSpill", Vector3(0.0, 1.52, -0.14), Color("f6c98c"), 0.26, 2.0)

	_cylinder(content, "WasteBin", Vector3(1.75, 0.26, 15.75), 0.185, 0.52, _materials["hull_dark"], true)
	_torus(content, "WasteBinRim", Vector3(1.75, 0.51, 15.75), 0.185, 0.215, _materials["rubber"])


## The traces that say people work here rather than that a room was furnished.
func _build_console_line_traces(content: Node3D) -> void:
	var traces := Node3D.new()
	traces.name = "CrewTraces"
	content.add_child(traces)

	# A headset hung over the middle console's edge rail, which is at world
	# (6.0, 1.43, 15.14) with a 2.18 m span, so this hangs on real geometry.
	_torus(traces, "ConsoleHeadsetBand", Vector3(6.78, 1.33, 15.14), 0.065, 0.098, _materials["graphite"], Vector3(0, 0, 90))
	for cup_side in [-1.0, 1.0]:
		_cylinder(traces, "ConsoleHeadsetCup", Vector3(6.78 + float(cup_side) * 0.078, 1.29, 15.14), 0.036, 0.03, _materials["fabric"], false, Vector3(0, 0, 90))
	# A stack of manuals left on the deck behind the third console plinth.
	_box(traces, "StowedManualBase", Vector3(9.62, 0.035, 16.42), Vector3(0.30, 0.07, 0.40), _materials["graphite"], false, Vector3(0, 8, 0))
	_box(traces, "StowedManualUpper", Vector3(9.60, 0.095, 16.44), Vector3(0.29, 0.05, 0.38), _materials["paper"], false, Vector3(0, -5, 0))
	_box(traces, "StowedManualTop", Vector3(9.63, 0.142, 16.40), Vector3(0.28, 0.04, 0.37), _materials["paper"], false, Vector3(0, 14, 0))


## Aft-module content at the head of its own stair.
##
## The upper landing carries a crew workpost, but that post is a
## `StationOperationsActivity` placement the hub drops onto this deck — it is not
## the aft module's own content, and the module contributed nothing at the point
## where a player finishes the climb. This is the module's piece: the muster
## locker every pressurised station puts at the top of its only vertical route,
## with the aft route board on its head so the climb ends at something that tells
## you where you are.
##
## Sited at (-2.55, 13.55) on the east half of the upper deck — inboard of
## `UpperSouthReturnRail`, 4.5 m clear of the workpost, and well off the stair
## mouth at x = -5.7, so nothing here narrows the route the traversal sweep walks.
func _build_stair_head_muster(upper: Node3D) -> void:
	var muster := Node3D.new()
	muster.name = "StairHeadMuster"
	muster.position = Vector3(-2.55, 4.2, 13.55)
	upper.add_child(muster)

	# The carcass is deliberately two bodies rather than one solid block, because a
	# locker with an open door has to have something behind that door. Built solid
	# first: the door swung wide onto the flat face of a 0.58 m box, and the reel
	# and kit cases authored "inside" it were buried in it and rendered to nobody.
	# `MusterLockerBody` is the rear 0.30 m across the full width;
	# `MusterLockerRightBay` fills the front 0.28 m of the sealed half only. What is
	# left is a real 0.28 m recess behind the open door, with its own side, top and
	# floor, and the collision follows that shape — a player can step into the open
	# bay exactly as far as the drawn recess goes.
	#
	# `warm_grey` rather than the rack bank's `mid_grey`. Photographed both: this
	# locker stands on the open upper deck, which is the module's brightest
	# `off_white_floor` plate under a directional key, and the darker structural
	# grey read as a black monolith dropped on a white deck. The rack bank keeps
	# `mid_grey` because it is indoors under six cool overheads.
	_box(muster, "MusterLockerBody", Vector3(0.0, 0.975, 0.14), Vector3(1.50, 1.95, 0.30), _materials["warm_grey"])
	_box(muster, "MusterLockerRightBay", Vector3(0.37, 0.975, -0.15), Vector3(0.74, 1.95, 0.28), _materials["warm_grey"])
	_box(muster, "MusterLockerBaySide", Vector3(-0.7225, 0.975, -0.15), Vector3(0.055, 1.95, 0.28), _materials["warm_grey"], false)
	_box(muster, "MusterLockerBayTop", Vector3(-0.37, 1.925, -0.15), Vector3(0.75, 0.05, 0.28), _materials["warm_grey"], false)
	_box(muster, "MusterLockerBayFloor", Vector3(-0.37, 0.025, -0.15), Vector3(0.75, 0.05, 0.28), _materials["graphite"], false)
	_box(muster, "MusterLockerCap", Vector3(0.0, 1.98, 0.0), Vector3(1.58, 0.06, 0.64), _materials["hull_dark"], false)
	# Right-hand door closed and sealed; left-hand door standing open, because a
	# muster locker that has never been opened is a painted box.
	_box(muster, "MusterDoorClosed", Vector3(0.36, 1.02, -0.30), Vector3(0.70, 1.72, 0.05), _materials["panel_light"], false)
	_cylinder(muster, "MusterDoorLatch", Vector3(0.68, 1.02, -0.34), 0.028, 0.16, _materials["brass"], false)
	_box(muster, "MusterSealTag", Vector3(0.68, 0.88, -0.35), Vector3(0.10, 0.16, 0.008), _materials["red"], false, Vector3(0, 0, -8))
	var open_door := Node3D.new()
	open_door.name = "MusterDoorOpenHinge"
	open_door.position = Vector3(-0.72, 1.02, -0.29)
	open_door.rotation_degrees.y = -46.0
	muster.add_child(open_door)
	_box(open_door, "MusterDoorOpen", Vector3(0.35, 0.0, 0.0), Vector3(0.70, 1.72, 0.05), _materials["panel_light"], false)
	_cylinder(open_door, "MusterDoorOpenPull", Vector3(0.64, 0.0, -0.05), 0.022, 0.16, _materials["brass"], false)
	# What is in the open bay. A hose reel bracketed to the carcass back, and three
	# kit cases stacked off the bay floor.
	_box(muster, "MusterLockerBayBack", Vector3(-0.37, 1.00, -0.008), Vector3(0.73, 1.85, 0.03), _materials["graphite"], false)
	_torus(muster, "MusterHoseReel", Vector3(-0.37, 1.32, -0.14), 0.12, 0.24, _materials["copper"], Vector3(90, 0, 0))
	_cylinder(muster, "MusterHoseHub", Vector3(-0.37, 1.32, -0.13), 0.07, 0.26, _materials["hull_dark"], false, Vector3(90, 0, 0))
	for kit_index in 3:
		_box(
			muster,
			"MusterKitCase%02d" % kit_index,
			Vector3(-0.37, 0.16 + float(kit_index) * 0.19, -0.14),
			Vector3(0.58, 0.18, 0.24),
			_materials["off_white"] if kit_index % 2 else _materials["panel_light"],
			false
		)
	# Route headboard, on two posts standing on the locker cap. Mounting it on the
	# locker's own front face was tried first and there is no room there — the
	# doors run to within 0.07 m of the top — so it would have been a panel hanging
	# in front of a door with nothing behind it. Posts stand on the cap at
	# y = 2.01 and the board bears on the posts, so the whole assembly is carried.
	for post_side in [-1.0, 1.0]:
		_cylinder(muster, "MusterHeadboardPost", Vector3(float(post_side) * 0.50, 2.11, -0.20), 0.03, 0.20, _materials["mid_grey"], false)
	_box(muster, "MusterRouteBoard", Vector3(0.0, 2.36, -0.20), Vector3(1.34, 0.42, 0.06), _materials["hull_dark"], false)
	for bar_index in 3:
		_box(
			muster,
			"MusterRouteBar%02d" % bar_index,
			Vector3(-0.36 + float(bar_index) * 0.36, 2.28, -0.238),
			Vector3(0.30, 0.026, 0.014),
			_materials["cyan"],
			false
		)
	_box(muster, "MusterRouteHere", Vector3(0.36, 2.28, -0.240), Vector3(0.07, 0.07, 0.014), _materials["gold"], false)
	_text_sign(muster, "MUSTER POINT", Vector3(0.0, 2.47, -0.240), Vector3(0, 180, 0), 0.15, _materials["gold"])
	_box(muster, "MusterLampLens", Vector3(0.0, 2.59, -0.20), Vector3(0.34, 0.05, 0.07), _materials["amber_light"], false)
	_fixture_practical(muster, "MusterLockerLamp", Vector3(0.0, 2.46, -0.40), Color("f0c48c"), 0.30, 2.4)


## Register a lens that alternates between two of this module's materials.
##
## The same mechanism the station-life pass uses on the workpost's weld arc, and
## for the same reason: a swap between two pre-built materials is a closed-form
## function of the clock, so a 120 Hz frame and one 30 Hz step land on the same
## state and nothing accumulates across frames.
func _register_content_lens(
		lens: MeshInstance3D,
		dim_key: String,
		lit_key: String,
		period: float,
		duty: float,
		offset: float
	) -> void:
	_content_lenses.append(lens)
	_content_lens_specs.append({
		"dim": dim_key,
		"lit": lit_key,
		"period": period,
		"duty": duty,
		"offset": offset,
	})


## The module's one frame loop.
##
## Two things move and one blinks, all of them closed-form in `_content_clock`:
## the plot table's sweep arm indexes round its disc, the annunciator that stands
## for working traffic pulses, and that is the whole loop. It is budgeted as the
## module's single `process_loops` and it stops with the module — see
## `_apply_enabled_state`, which is what keeps `process_matches_lifecycle` true.
func _process(delta: float) -> void:
	# Wrapped rather than free-running so a long session cannot walk the float
	# into a range where `fmod` on the lens period starts to quantise.
	_content_clock = fmod(_content_clock + delta, 3600.0)
	_update_operations_content()


func _update_operations_content() -> void:
	if _sweep_arm != null:
		# 0.42 rad/s: about fifteen seconds a revolution, slow enough to read as an
		# instrument sweeping rather than a fan.
		_sweep_arm.rotation.y = fmod(_content_clock * 0.42, TAU)
	for lens_index in _content_lenses.size():
		var spec: Dictionary = _content_lens_specs[lens_index]
		var pulse := fmod(_content_clock + float(spec["offset"]), float(spec["period"]))
		_content_lenses[lens_index].material_override = (
			_materials[str(spec["lit"])] if pulse < float(spec["duty"]) else _materials[str(spec["dim"])]
		)


func _build_chair(parent: Node3D, chair_index: int, chair_position: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "OperationsChair%02d" % (chair_index + 1)
	chair.position = chair_position
	chair.rotation_degrees.y = yaw
	chair.set_meta("station_chair", true)
	chair.set_meta("chair_index", chair_index)
	parent.add_child(chair)
	_chair_nodes.append(chair)
	# Cushion top 0.99 minus the pilot rig's 0.72 m hip height. BackFrame is on
	# local +Z, so the native -Z player-forward convention already faces the desk.
	StationSeat.install(chair, 0.27, 0.0, 1.2, 0.0, "OPERATIONS CHAIR %02d" % (chair_index + 1))
	_cylinder(chair, "Pedestal", Vector3(0, 0.38, 0), 0.18, 0.76, _materials["mid_grey"], true)
	_cylinder(chair, "Foot", Vector3(0, 0.08, 0), 0.52, 0.12, _materials["graphite"], true)
	_interface_collar(
		chair,
		"PedestalBearing",
		PEDESTAL_BEARING_LOCAL_POSITION,
		PEDESTAL_BEARING_INNER_RADIUS,
		PEDESTAL_BEARING_OUTER_RADIUS,
		_materials["copper"],
		Vector3.ZERO,
		_pedestal_bearing_mesh
	)
	_box(chair, "SeatShell", Vector3(0, 0.8, 0), Vector3(1.03, 0.19, 0.98), _materials["chair"], true)
	_box(chair, "SeatCushion", Vector3(0, 0.93, -0.06), Vector3(0.83, 0.12, 0.74), _materials["chair_pad"], false, Vector3(-3, 0, 0))
	_box(chair, "BackFrame", Vector3(0, 1.48, 0.43), Vector3(1.0, 1.32, 0.18), _materials["chair"], true, Vector3(-7, 0, 0))
	_box(chair, "BackCushion", Vector3(0, 1.51, 0.3), Vector3(0.78, 0.92, 0.1), _materials["chair_pad"], false, Vector3(-7, 0, 0))
	_box(chair, "Headrest", Vector3(0, 2.12, 0.5), Vector3(0.68, 0.31, 0.16), _materials["warm_grey"], false, Vector3(-7, 0, 0))
	for side in [-1.0, 1.0]:
		var arm_x := float(side) * 0.58
		_beam_between(chair, "ArmSupport", Vector3(arm_x, 0.82, 0.12), Vector3(arm_x, 1.2, 0.12), 0.055, _materials["mid_grey"], false)
		_box(chair, "ArmPad", Vector3(arm_x, 1.24, -0.05), Vector3(0.16, 0.11, 0.62), _materials["chair_pad"], false)
		_beam_between(chair, "BackSideRail", Vector3(arm_x * 0.78, 1.0, 0.45), Vector3(arm_x * 0.78, 2.0, 0.52), 0.055, _materials["mid_grey"], false)
	# The coordinator's coverall, left over the back of their own chair. One trace,
	# on the one seat the room is arranged around, draped across the back frame it
	# hangs on so it is bearing on drawn geometry rather than hovering behind it.
	if chair_index == 3:
		_box(chair, "StowedCoverall", Vector3(0.0, 1.66, 0.50), Vector3(0.84, 0.62, 0.11), _materials["fabric"], false, Vector3(-9, 0, 0))
		_box(chair, "StowedCoverallCollar", Vector3(0.0, 1.98, 0.47), Vector3(0.52, 0.14, 0.15), _materials["fabric"], false, Vector3(-9, 0, 0))
		_box(chair, "StowedCoverallSleeve", Vector3(-0.40, 1.34, 0.46), Vector3(0.16, 0.52, 0.12), _materials["fabric"], false, Vector3(-6, 0, 7))


func _build_service_wall(room: Node3D) -> void:
	var service := Node3D.new()
	service.name = "ServiceWall"
	service.position = Vector3(10.65, 0.0, 12.55)
	service.set_meta("station_service_wall", true)
	room.add_child(service)

	_box(service, "ServiceWallBody", Vector3(0, 2.35, 0), Vector3(0.42, 4.7, 6.2), _materials["warm_grey"])
	var fastener_transforms := _cabinet_fastener_transforms()
	var fastener_index := 0
	for cabinet_index in 3:
		var z_position := -2.05 + float(cabinet_index) * 2.05
		_box(service, "ServiceCabinet%02d" % cabinet_index, Vector3(-0.3, 1.72, z_position), Vector3(0.35, 2.75, 1.55), _materials["off_white"], false)
		_box(service, "CabinetRecess", Vector3(-0.5, 1.72, z_position), Vector3(0.035, 2.28, 1.18), _materials["hull_dark"], false)
		_box(service, "CabinetStatus", Vector3(-0.49, 2.38, z_position), Vector3(0.04, 0.18, 0.8), _materials["cyan"] if cabinet_index != 1 else _materials["gold"], false)
		for fastener_y in [0.67, 2.77]:
			for fastener_z in [-0.53, 0.53]:
				var anchor := Marker3D.new()
				anchor.name = "CabinetFastener" if fastener_index == 0 \
					else "CabinetFastener%02d" % (fastener_index + 1)
				anchor.transform = fastener_transforms[fastener_index]
				service.add_child(anchor, true)
				fastener_index += 1
	_cabinet_fastener_batch = _multimesh_mesh(
		service,
		"CabinetFastenerRenderBatch",
		StationSurfaceKit.chamfered_cylinder_mesh_cached(
			0.035, 0.035, 0.028, 32, _chamfered_cylinder_cache
		),
		_materials["brass"],
		fastener_transforms
	)
	_conduit_collar_mesh = _torus_mesh(
		CONDUIT_COLLAR_INNER_RADIUS,
		CONDUIT_COLLAR_OUTER_RADIUS,
		CONDUIT_COLLAR_RINGS,
		CONDUIT_COLLAR_RING_SEGMENTS
	)
	_conduit_collar_mesh.resource_name = "AftConduitCollarMesh"
	for pipe_index in 3:
		var pipe_z := -2.05 + float(pipe_index) * 2.05
		_cylinder(service, "ServiceConduit", Vector3(-0.55, 3.65, pipe_z), 0.09, 1.9, _materials["mid_grey"], false)
		_interface_collar(
			service,
			"ConduitCollar",
			Vector3(-0.55, 2.95, pipe_z),
			CONDUIT_COLLAR_INNER_RADIUS,
			CONDUIT_COLLAR_OUTER_RADIUS,
			_materials["brass"],
			Vector3(90, 0, 0),
			_conduit_collar_mesh
		)
	_beam_between(service, "ServiceBus", Vector3(-0.66, 4.15, -2.85), Vector3(-0.66, 4.15, 2.85), 0.065, _materials["copper"], false)
	# Three status strips in a recessed cabinet face, none of which lit the recess
	# they sit in — the exact "glowing decal" reading. One practical per strip,
	# tinted to that strip's own cue colour, so the middle cabinet's warm strip and
	# the two flanking cool ones are told apart by the light they throw as well as
	# by the strip itself. Range is 1.4 m: this washes the cabinet recess and
	# stops, rather than spilling across the room and diluting the cue.
	for cabinet_index in 3:
		var status_z := -2.05 + float(cabinet_index) * 2.05
		_fixture_practical(
			service,
			"CabinetStatusSpill",
			Vector3(-0.72, 2.38, status_z),
			Color("f2c07f") if cabinet_index == 1 else Color("7fe0e6"),
			0.3,
			1.4
		)


func _build_vip_landmark(structure: Node3D) -> void:
	var vip := Node3D.new()
	vip.name = "VIPLandmark"
	# The VIP frontage sits beyond the widened upper deck, freeing the route that
	# previously terminated against the reception facade.
	vip.position.z = 2.0
	structure.add_child(vip)
	# The facade is split around the real door so its red panel remains visible.
	#
	# `VIPShallowBackstop` used to close the opening 0.14 m behind the leaf: a
	# solid plate that made "no unsupported VIP interior" true in geometry rather
	# than only in a label. It is deliberately gone. The doorway now opens into
	# `VipReceptionSuite`, whose threshold shell laps this facade, and the evidence
	# statement it used to carry has moved to that module's own metadata and to the
	# legend on the plinth two metres beyond this frame — which says the same thing
	# to a player standing in the room rather than to a reader of this file.
	_box(vip, "VIPFacadeLeft", Vector3(-8.9, 6.25, 20.38), Vector3(2.8, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeRight", Vector3(-1.45, 6.25, 20.38), Vector3(2.5, 4.1, 0.52), _materials["warm_grey"])
	_box(vip, "VIPFacadeHeader", Vector3(-5.15, 8.12, 20.38), Vector3(10.3, 0.76, 0.52), _materials["warm_grey"])
	for side in [-1.0, 1.0]:
		var frame_x := -5.15 + float(side) * 3.85
		_cylinder(vip, "VIPFacadeColumn", Vector3(frame_x, 6.25, 20.02), 0.18, 4.15, _materials["hull_dark"], false)
	var trim_mesh := _torus_mesh(
		VIP_FACADE_COLUMN_TRIM_INNER_RADIUS,
		VIP_FACADE_COLUMN_TRIM_OUTER_RADIUS,
		VIP_FACADE_COLUMN_TRIM_RINGS,
		VIP_FACADE_COLUMN_TRIM_RING_SEGMENTS
	)
	# MultiMesh resources are not visited by the global MeshInstance3D sweep.
	# Apply the same budget eagerly and retain its authored metadata so this batch
	# has the exact live recipe the four retired ordinary renderers had.
	TorusGeometryBudget.apply(trim_mesh, 1.0)
	_vip_facade_column_trim_batch = _multimesh_torus(
		vip,
		"VIPFacadeColumnTrimBatch",
		trim_mesh,
		_materials["brass"],
		_vip_facade_column_trim_transforms()
	)
	_arch_across_x(vip, "VIPFacadeArch", 20.04, -9.0, -1.3, 8.05, 8.72, 0.12, _materials["hull_dark"])
	_box(vip, "VIPRedCrown", Vector3(-5.15, 8.15, 20.03), Vector3(6.2, 0.18, 0.12), _materials["red"], false)
	for side in [-1.0, 1.0]:
		_box(vip, "VIPRedMarker", Vector3(-5.15 + side * 2.35, 6.25, 20.02), Vector3(0.12, 3.4, 0.12), _materials["red"], false)
	# MAP-004 family. The legend sits at z = 19.96, in front of the facade panels
	# (z = 20.12 …) on the -Z side of the landmark, and was authored with
	# `Vector3.ZERO`, so it read backwards to anyone walking aft towards it. Yawed
	# to the reader; `AFT OPERATIONS` in the same module already does this.
	# MAP-004 family, plus a second defect found only by photographing it. The
	# legend was authored with `Vector3.ZERO`, so it read backwards; and it stood
	# at z = 19.96 while `VIPAccess/FrameVisuals/Header` — the door frame added
	# later — occupies world z = 67.72 … 68.44 at exactly this height, so the sign
	# was buried inside the frame and rendered to nobody from either side. Five
	# camera positions from 1.06 m to 6.0 m photographed blank frame header. It is
	# now yawed to the reader and pulled to z = 19.64 (world 67.64), 0.08 m proud
	# of the frame's front face, where it reads as the header's legend.
	#
	# Retitled with the interior. `DEFERRED` was the honest word while the doorway
	# was a plate; it is a false one now that a player can walk through it, and the
	# legend that replaces it says exactly what is on the other side.
	_text_sign(vip, "VIP RECEPTION  //  MODERN INTERPRETATION", Vector3(-5.15, 7.75, 19.64), Vector3(0, 180, 0), 0.22, _materials["red"])


func _build_open_structure_details(structure: Node3D) -> void:
	var details := Node3D.new()
	details.name = "OpenStructureDetails"
	structure.add_child(details)
	for side in [-1.0, 1.0]:
		var x_position: float = float(side) * 4.75
		_cylinder(details, "JunctionSupport", Vector3(x_position, -0.95, 7.4), 0.24, 1.9, _materials["mid_grey"], true)
		_torus(details, "SupportCollar", Vector3(x_position, -0.15, 7.4), 0.26, 0.39, _materials["brass"], Vector3(90, 0, 0))
	_beam_between(details, "LowerCrossBrace", Vector3(-4.7, -1.2, 6.1), Vector3(4.7, -1.2, 8.7), 0.16, _materials["mid_grey"], false)
	_beam_between(details, "LowerCrossBraceReturn", Vector3(4.7, -1.2, 6.1), Vector3(-4.7, -1.2, 8.7), 0.16, _materials["mid_grey"], false)
	for side in [-1.0, 1.0]:
		var support_x := float(side) * 4.75
		_beam_between(details, "SupportOutrigger", Vector3(support_x, -1.15, 7.4), Vector3(support_x + float(side) * 2.0, -1.75, 7.4), 0.13, _materials["hull_dark"], false)
		_cylinder(details, "OutriggerEndCap", Vector3(support_x + float(side) * 2.0, -1.75, 7.4), 0.26, 0.24, _materials["brass"], false, Vector3(0, 0, 90))
		for z_position in [5.55, 9.25]:
			_omni_light(details, "ExteriorMarkerLight", Vector3(support_x, -0.05, float(z_position)), Color("66d7dc"), 0.28, 2.4)
	# MAP-004 family. `bugs.md` filed this under "floor decals rendered mirrored";
	# it is not a floor decal, it is a vertical identity plaque, and it genuinely
	# did read backwards. Rendered from the aft connection deck at world
	# `(0, 2.4, 52)` — the only place a player stands to see it — the legend was
	# reversed. Yawed to that reader. It remains deliberately unbacked, like the
	# rest of this open-lattice exterior dressing.
	# The connector-facing plaque and stair handoff now form a paired, legible
	# choice: remain on the lower transit/berth flow, or take the rise to upper
	# Operations. This is a relabel of the existing non-authoritative plaque only;
	# the route markers, doors, activity ownership and evidence metadata do not
	# change.
	_text_sign(details, "AFT JUNCTION  //  TRANSIT / BERTHS", Vector3(0, 1.25, 9.82), Vector3(0, 180, 0), 0.2, _materials["gold"])
	# Warm wash on the identity plaque, matching its gold legend. The plaque is
	# deliberately unbacked, so this lights the envelope wall a metre behind it and
	# the plaque reads as standing off a lit surface rather than floating.
	_fixture_practical(details, "JunctionLegendWash", Vector3(0.0, 1.05, 10.1), Color("f0be7c"), 0.32, 2.8)


func _style_access_landmarks() -> void:
	if _operations_entrance != null:
		_apply_door_material(_operations_entrance, _materials["cyan"], _materials["cyan"])
	if _vip_access != null:
		_apply_door_material(_vip_access, _materials["red"], _materials["red"])
	# StationDoor defers this binding because production hosts apply their accent
	# material from the parent's `_ready`. Aft's exact material/resource census is
	# itself consumed synchronously by ShipyardWorld later in that same ready
	# cascade, so both host-coloured leaves must finish their idempotent binding
	# here rather than exist as two deferred allocations during parent validation.
	for door in [_operations_entrance, _vip_access]:
		if door != null:
			door.call(&"_bind_panel_surface_family")


## Give only Aft Operations' retained access header a true curved pressure-frame
## silhouette. StationDoor keeps the frame collision, moving leaf, interaction
## and renderer node; this swaps the header's one mesh after the child component
## has applied its standard manufactured-edge and panel-family treatment.
func _apply_operations_entrance_header_curve() -> void:
	if _operations_entrance == null:
		return
	var header := _operations_entrance.get_node_or_null(
		^"FrameVisuals/Header"
	) as MeshInstance3D
	var collision := _operations_entrance.get_node_or_null(
		^"FrameBody/HeaderCollision"
	) as CollisionShape3D
	if header == null or collision == null or not collision.shape is BoxShape3D:
		push_error("Aft Operations entrance lost its retained header render/collision pair")
		return
	var shape := collision.shape as BoxShape3D
	if not shape.size.is_equal_approx(OPERATIONS_ENTRANCE_HEADER_SIZE):
		push_error("Aft Operations entrance header collision drifted before curve treatment")
		return
	header.mesh = _xy_extruded_capsule_mesh(
		OPERATIONS_ENTRANCE_HEADER_SIZE,
		OPERATIONS_ENTRANCE_HEADER_END_RADIUS,
		OPERATIONS_ENTRANCE_HEADER_CURVE_SEGMENTS
	)
	header.set_meta("geometry_profile", &"xy_extruded_capsule_header")
	header.set_meta("end_radius_m", OPERATIONS_ENTRANCE_HEADER_END_RADIUS)
	header.set_meta("curve_segments_per_end", OPERATIONS_ENTRANCE_HEADER_CURVE_SEGMENTS)
	header.set_meta("evidence_status", EVIDENCE_STATUS)
	header.set_meta("authenticated_original_geometry", false)


func _apply_door_material(door: StationDoor, panel_material: Material, indicator_material: Material) -> void:
	var panel := door.get_node_or_null("SlidingPanel/PanelMesh") as MeshInstance3D
	if panel != null:
		panel.material_override = panel_material
	var left_indicator := door.get_node_or_null("SlidingPanel/LeftIndicator") as MeshInstance3D
	var right_indicator := door.get_node_or_null("SlidingPanel/RightIndicator") as MeshInstance3D
	if left_indicator != null:
		left_indicator.material_override = indicator_material
	if right_indicator != null:
		right_indicator.material_override = indicator_material
	# StationDoor creates this renderer from the scene-authored indicator material
	# before its host applies the cyan/red access language. The authored paths are
	# deliberately layer-zero anchors after batching, so the batch must receive the
	# same host colour or the visible strips retain the stale scene material.
	var indicator_batch := door.get_node_or_null(
		^"SlidingPanel/IndicatorRenderBatch"
	) as MultiMeshInstance3D
	if indicator_batch != null:
		indicator_batch.material_override = indicator_material


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", true)
	set_meta("content_note", CONTENT_NOTE)
	set_meta("open_to_space_ratio", get_open_to_space_ratio())
	set_meta("integration_footprint_min", FOOTPRINT_MIN)
	set_meta("integration_footprint_max", FOOTPRINT_MAX)
	add_to_group("station_modules")


func _material(
		color: Color,
		metallic: float,
		roughness: float,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.clearcoat_enabled = true
	result.clearcoat = 0.18
	result.clearcoat_roughness = 0.48
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
	result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
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

	var mesh := _rounded_box_mesh(size)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
	return container


## Box with softly chamfered edges, at this module's frozen bevel rule.
##
## The rule stays `clamp(shortest_side * 0.22, 0.003, 0.18)` and is *not* the
## kit's own `bevel_for_size`. Measured over every live chamfered box in this
## module, adopting the kit rule would move 23 of 65 distinct sizes by up
## to 0.0058 m, so the shared code is the builder, not the rule. The outer extent
## along each axis is preserved exactly, so `get_aabb()` still returns the
## requested size and no footprint, collider or published envelope moves.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.18),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.UNIT_PER_QUAD
	)


## Capsule outline in local X/Y with constant Z extrusion. Eighteen boundary
## points emit four triangles each: 72 triangles versus the prior chamfered
## box's 108, while preserving the authored AABB exactly.
func _xy_extruded_capsule_mesh(
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
		# Approach cap, outward toward local -Z.
		_emit_operations_header_vertex(surface, Vector3(0.0, 0.0, -half_depth), Vector3.FORWARD, Vector2(0.5, 0.5))
		_emit_operations_header_vertex(surface, Vector3(next.x, next.y, -half_depth), Vector3.FORWARD, next_uv)
		_emit_operations_header_vertex(surface, Vector3(current.x, current.y, -half_depth), Vector3.FORWARD, current_uv)
		# Room-side cap, outward toward local +Z.
		_emit_operations_header_vertex(surface, Vector3(0.0, 0.0, half_depth), Vector3.BACK, Vector2(0.5, 0.5))
		_emit_operations_header_vertex(surface, Vector3(current.x, current.y, half_depth), Vector3.BACK, current_uv)
		_emit_operations_header_vertex(surface, Vector3(next.x, next.y, half_depth), Vector3.BACK, next_uv)
		# Constant-depth rim following the capsule outline.
		var rim_normal := Vector3(next.y - current.y, current.x - next.x, 0.0).normalized()
		var rim_u := float(index) / float(boundary.size())
		var rim_next_u := float(index + 1) / float(boundary.size())
		_emit_operations_header_vertex(surface, Vector3(current.x, current.y, -half_depth), rim_normal, Vector2(rim_u, 0.0))
		_emit_operations_header_vertex(surface, Vector3(next.x, next.y, -half_depth), rim_normal, Vector2(rim_next_u, 0.0))
		_emit_operations_header_vertex(surface, Vector3(next.x, next.y, half_depth), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_operations_header_vertex(surface, Vector3(current.x, current.y, -half_depth), rim_normal, Vector2(rim_u, 0.0))
		_emit_operations_header_vertex(surface, Vector3(next.x, next.y, half_depth), rim_normal, Vector2(rim_next_u, 1.0))
		_emit_operations_header_vertex(surface, Vector3(current.x, current.y, half_depth), rim_normal, Vector2(rim_u, 1.0))
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_name = "aft_operations_capsule_access_header_v1"
	return mesh


func _emit_operations_header_vertex(
		surface: SurfaceTool,
		position_value: Vector3,
		normal: Vector3,
		uv: Vector2,
	) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(position_value)


func _cylinder(
		parent: Node3D,
		node_name: String,
		cylinder_position: Vector3,
		radius: float,
		height: float,
		material: Material,
		collidable: bool,
		rotation_degrees_value: Vector3 = Vector3.ZERO
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
	container.rotation_degrees = rotation_degrees_value
	parent.add_child(container)
	# Chamfered rims at the module's frozen 32 radial segments. Outer radius and
	# overall height are unchanged, so no footprint moves and the collision
	# cylinder below is built from the same untouched arguments.
	var cylinder_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 32, _chamfered_cylinder_cache
	)
	if collidable:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
		container.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		container.add_child(collision)
	else:
		var mesh_instance := container as MeshInstance3D
		mesh_instance.mesh = cylinder_mesh
		mesh_instance.material_override = material
	return container


func _beam_between(
		parent: Node3D,
		node_name: String,
		from: Vector3,
		to: Vector3,
		radius: float,
		material: Material,
		collidable: bool
	) -> Node3D:
	var direction := to - from
	var beam := _cylinder(parent, node_name, (from + to) * 0.5, radius, direction.length(), material, collidable)
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return beam


func _arch_across_x(
		parent: Node3D,
		node_name: String,
		z_position: float,
		x_minimum: float,
		x_maximum: float,
		spring_height: float,
		crown_height: float,
		radius: float,
		material: Material
	) -> Node3D:
	var arch := Node3D.new()
	arch.name = node_name
	arch.set_meta("visual_detail_only", true)
	parent.add_child(arch)
	var half_width := (x_maximum - x_minimum) * 0.5
	var center_x := (x_minimum + x_maximum) * 0.5
	var segment_count := 14
	var previous := Vector3(x_minimum, spring_height, z_position)
	for segment_index in segment_count:
		var progress := float(segment_index + 1) / float(segment_count)
		var x_position := lerpf(x_minimum, x_maximum, progress)
		var normalized_x := (x_position - center_x) / half_width
		var curve_height := spring_height + (crown_height - spring_height) * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		var current := Vector3(x_position, curve_height, z_position)
		_beam_between(arch, "TubeSegment%02d" % segment_index, previous, current, radius, material, false)
		previous = current
	return arch


## Batch the five collision-free pressure-rib copies by segment recipe. A tube
## at a given segment index has the same mesh and orientation on every rib; only
## its Z origin differs. This turns 70 renderer nodes/submissions into 14 while
## retaining all 70 visible tube copies and the five named visual anchors.
func _build_pressure_rib_batches(envelope: Node3D) -> void:
	for rib_index in PRESSURE_RIB_COPY_COUNT:
		var anchor := Node3D.new()
		anchor.name = "PressureRib%02d" % rib_index
		anchor.set_meta("visual_detail_only", true)
		anchor.set_meta("presentation_only", true)
		envelope.add_child(anchor)

	var half_width := (PRESSURE_RIB_X_MAX - PRESSURE_RIB_X_MIN) * 0.5
	var center_x := (PRESSURE_RIB_X_MAX + PRESSURE_RIB_X_MIN) * 0.5
	var previous_points: Array[Vector3] = []
	for rib_index in PRESSURE_RIB_COPY_COUNT:
		previous_points.append(Vector3(
			PRESSURE_RIB_X_MIN,
			PRESSURE_RIB_SPRING_HEIGHT,
			PRESSURE_RIB_Z_START + float(rib_index) * PRESSURE_RIB_Z_STEP
		))

	for segment_index in PRESSURE_RIB_SEGMENT_COUNT:
		var progress := float(segment_index + 1) / float(PRESSURE_RIB_SEGMENT_COUNT)
		var x_position := lerpf(PRESSURE_RIB_X_MIN, PRESSURE_RIB_X_MAX, progress)
		var normalized_x := (x_position - center_x) / half_width
		var curve_height := PRESSURE_RIB_SPRING_HEIGHT + (
			PRESSURE_RIB_CROWN_HEIGHT - PRESSURE_RIB_SPRING_HEIGHT
		) * sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
		var transforms: Array[Transform3D] = []
		var segment_length := 0.0
		for rib_index in PRESSURE_RIB_COPY_COUNT:
			var current := Vector3(
				x_position,
				curve_height,
				PRESSURE_RIB_Z_START + float(rib_index) * PRESSURE_RIB_Z_STEP
			)
			var previous := previous_points[rib_index]
			var direction := current - previous
			segment_length = direction.length()
			transforms.append(Transform3D(
				Basis(Quaternion(Vector3.UP, direction.normalized())),
				(previous + current) * 0.5
			))
			previous_points[rib_index] = current
		_multimesh_mesh(
			envelope,
			"PressureRibSegmentBatch%02d" % segment_index,
			StationSurfaceKit.chamfered_cylinder_mesh_cached(
				PRESSURE_RIB_RADIUS,
				PRESSURE_RIB_RADIUS,
				segment_length,
				32,
				_chamfered_cylinder_cache
			),
			_materials["off_white"],
			transforms
		)


func _omni_light(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.name = node_name
	result.position = light_position
	result.light_color = color
	result.light_energy = energy
	result.omni_range = range_value
	result.omni_attenuation = 1.45
	result.shadow_enabled = false
	result.distance_fade_enabled = true
	result.distance_fade_begin = 28.0
	result.distance_fade_length = 12.0
	result.set_meta("localized_practical_light", true)
	parent.add_child(result)
	return result


## A luminaire's spill, as an actual light.
##
## Every lit fixture in this module previously read as a painted decal, and the
## reason is mechanical rather than a matter of degree. `emission` is a purely
## local surface term in Forward+: it changes what the emitting fragment returns
## and nothing else. The glow pass then convolves the finished *image*, so a
## bright lens grows a halo in screen space but still contributes zero radiance
## to the plate it is bolted to. Raising emission therefore cannot make a sign
## light its own backing panel — it only pushes the lens further past the
## tonemapper's shoulder and widens the bloom, which is precisely the bimodal
## frame this pass was asked to fix. The only mechanism in this renderer that
## lights a mount is a Light3D, so that is what these are.
##
## They are deliberately small, and every property here is a restraint:
## shadowless, sub-7 m range, steeper attenuation than the room fills, and faded
## out by 85 m so the whole-lattice overview pays for none of them. Each carries
## its own fixture's hue, so the spill identifies the source rather than adding
## an anonymous lift. Where one is added the lens emission comes down by roughly
## what the practical now carries: the change moves energy out of the blown top
## of the histogram into the 20-40 structural band instead of adding gain. Frame
## cost is unmeasured and unmeasurable here — this box renders through llvmpipe.
##
## The fade distance is measured, not chosen. It was first set at 16 m begin /
## 8 m length, and every one of these lights was then off in every rendered
## framing except the two interiors: measured across the six station-operations
## frames and `aft_junction`/`station`/`fleet_overview`, structural sigma moved
## by -0.9% to +0.1% — the emission that came out of the lenses was real and the
## spill that was supposed to replace it never arrived. The station is a 10-50 m
## structure normally read from 30-70 m, so a fade that ends at 24 m ends inside
## the subject. 60 m begin / 25 m length keeps the practicals present at every
## distance the station is actually looked at and still switches them off for the
## 140 m-plus lattice overview.
func _fixture_practical(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := _omni_light(parent, node_name, light_position, color, energy, range_value)
	light.omni_attenuation = 2.1
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("fixture_practical", true)
	return light


## Presentation-only declaration for the bounded static warmth slice. The
## practical has no process/animation path, so reduced-flash changes do not need
## to branch it and cannot leave the room in a different lighting state.
func _mark_authored_interior_warmth(node: Node, role: StringName) -> Node:
	node.set_meta("station_interior_warmth", role)
	node.set_meta("evidence_status", &"modern_interpretation")
	node.set_meta("reduced_flash_safe", true)
	node.set_meta("presentation_only", true)
	return node


## Marks only the small, visual-only collars wrapped around an existing solid
## support or service run. The wrapped mesh/body remains the collision and
## semantic authority; this TorusMesh is presentation trim with no children.
func _interface_collar(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO,
		shared_mesh: TorusMesh = null
	) -> MeshInstance3D:
	var instance := _torus(
		parent,
		node_name,
		torus_position,
		inner_radius,
		outer_radius,
		material,
		rotation_degrees_value,
		shared_mesh
	)
	instance.set_meta(
		TorusGeometryBudget.PROFILE_META,
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR
	)
	instance.set_meta(INTERFACE_COLLAR_KIND_META, StringName(node_name))
	return instance


func _torus(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO,
		shared_mesh: TorusMesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = torus_position
	instance.rotation_degrees = rotation_degrees_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = _torus_mesh(inner_radius, outer_radius, 48, 16)
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _torus_mesh(
		inner_radius: float,
		outer_radius: float,
		rings: int,
		ring_segments: int
	) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	return mesh


func _multimesh_torus(
		parent: Node3D,
		node_name: String,
		mesh: TorusMesh,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	multimesh.custom_aabb = _transformed_mesh_bounds(mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _multimesh_rounded_box(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var mesh := _rounded_box_mesh(size)
	return _multimesh_mesh(parent, node_name, mesh, material, transforms)


func _multimesh_mesh(
		parent: Node3D,
		node_name: String,
		mesh: Mesh,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	multimesh.custom_aabb = _transformed_mesh_bounds(mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


static func _approach_edge_collar_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var collar_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	for side in [-1.0, 1.0]:
		for z_position in [0.65, 2.5, 4.35]:
			transforms.append(Transform3D(
				collar_basis,
				Vector3(float(side) * 3.5, -0.38, float(z_position))
			))
	return transforms


static func _rack_card_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	const RACK_X := 6.90
	for module_index in range(1, 3):
		var module_y := 0.46 + float(module_index) * 0.44
		for card_index in 7:
			transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(
					RACK_X - 0.54 + float(card_index) * 0.18,
					module_y,
					10.000
				)
			))
	return transforms


static func _stair_tread_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for index in STAIR_STEP_COUNT:
		var progress := float(index) / float(STAIR_STEP_COUNT - 1)
		transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(
				-5.7,
				progress * UPPER_FLOOR_ELEVATION + 0.06,
				3.0 + progress * 9.8
			)
		))
	return transforms


static func _console_shock_collar_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var collar_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	for bay_index in 3:
		var bay_origin := Vector3(
			3.15 + float(bay_index) * 2.85, 0.0, 15.7
		)
		for support_x in [-0.86, 0.86]:
			transforms.append(Transform3D(
				collar_basis,
				bay_origin + Vector3(float(support_x), 0.08, 0.34),
			))
	return transforms


static func _cabinet_fastener_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var fastener_basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(90.0)))
	for cabinet_index in 3:
		var cabinet_z := -2.05 + float(cabinet_index) * 2.05
		for fastener_y in [0.67, 2.77]:
			for fastener_z in [-0.53, 0.53]:
				transforms.append(Transform3D(
					fastener_basis,
					Vector3(-0.535, float(fastener_y), cabinet_z + float(fastener_z))
				))
	return transforms


static func _vip_facade_column_trim_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for transform_value in VIP_FACADE_COLUMN_TRIM_TRANSFORMS:
		transforms.append(transform_value as Transform3D)
	return transforms


static func _transform_arrays_match(
		actual: Array,
		expected: Array[Transform3D]
	) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if actual[index] is not Transform3D \
			or not (actual[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


static func _encode_multimesh_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
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


static func _transformed_mesh_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
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


## Module-local Z of the stair-base landing's southern edge.
func _stair_base_landing_south_edge() -> float:
	return STAIR_BASE_LANDING_CENTRE.z - STAIR_BASE_LANDING_SIZE.z * 0.5


## Module-local Z of the stair-base landing's northern edge.
func _stair_base_landing_north_edge() -> float:
	return STAIR_BASE_LANDING_CENTRE.z + STAIR_BASE_LANDING_SIZE.z * 0.5


## Fraction along the ramp at which a stair rail line may begin. A rail line that
## passes over the stair-base landing begins only once the ramp has climbed past
## the landing's northern edge, so the landing stays a continuous walking surface.
func _stair_rail_start_progress(rail_x: float, start: Vector3, finish: Vector3) -> float:
	var west_edge := STAIR_BASE_LANDING_CENTRE.x - STAIR_BASE_LANDING_SIZE.x * 0.5
	var east_edge := STAIR_BASE_LANDING_CENTRE.x + STAIR_BASE_LANDING_SIZE.x * 0.5
	if rail_x <= west_edge or rail_x >= east_edge:
		return 0.0
	var run := finish.z - start.z
	if is_zero_approx(run):
		return 0.0
	return clampf((_stair_base_landing_north_edge() - start.z) / run, 0.0, 1.0)


func _add_rail(parent: Node3D, from: Vector3, to: Vector3, rail_name: String) -> void:
	for endpoint in [from, to]:
		_cylinder(parent, rail_name + "Post", endpoint + Vector3.UP * 0.68, 0.055, 1.36, _materials["warm_grey"], true)
	_beam_between(parent, rail_name, from + Vector3.UP * 1.34, to + Vector3.UP * 1.34, 0.07, _materials["brass"], true)


func _text_sign(
		parent: Node3D,
		text: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	var mesh := TextMesh.new()
	mesh.text = text
	mesh.font_size = 64
	mesh.pixel_size = 0.012
	mesh.depth = 0.02
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var instance := MeshInstance3D.new()
	instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
