class_name FleetDockComb
extends Node3D

## Source-bounded macro-architecture interpretation of the station comb visible
## in B2. The repeated trunk/rung/slab rhythm is observed; this exact geometry,
## scale, direction, count, vertical transition, and placement are modern.
##
## Dock markers are deliberately non-authoritative landmarks. Dock 01 records a
## modern external Zenith assignment, Dock 02 a modern external Halyard
## assignment, and Dock 03 a modern external Bulwark assignment while
## ShipyardWorld owns all actual berths, leases and landing volumes. This component itself
## owns no ShipBerth, landing area, lease, audio, activity, or process loop.

const SCHEMA_VERSION := 2
const MODULE_ID: StringName = &"fleet-dock-comb"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
## Declared station connection slot. `ShipyardWorld` publishes the matching hub
## endpoint; the pair is what `StationRouteRegistry` records as one graph edge.
const HUB_CONNECTION_SLOT: StringName = &"hub-fleet-dock-comb"
const WORLD_LAYER := PhysicsLayers.WORLD

const TRUNK_LENGTH := 48.0
const TRUNK_CLEAR_WIDTH := 4.8
const LOWER_DECK_ELEVATION := 0.0
const UPPER_DECK_ELEVATION := 2.4
const RUNG_CLEAR_WIDTH := 3.6
const RUNG_COUNT := 3
const DOCK_SLAB_COUNT := 3
const DOCK_MARKER_COUNT := 3
# Dock 02 stopped being empty when the Halyard Crew Transport was parked on it.
# The marker's bookkeeping moves with the craft rather than after it: a slab
# that still reported `deferred_empty` while a 27 m transport stood on it would
# be exactly the documentation drift this repository keeps having to correct.
# The module still owns no berth authority for any assignment; the world owns
# all three berths (`ShipyardWorld.SHIP_BERTH_FEEDBACK_SPECS`). Dock 03's marker
# retains its deferred key as a stable landmark identity while its live status
# is assigned.
const ASSIGNED_DOCK_COUNT := 3
const DEFERRED_DOCK_COUNT := 0
const WALKABLE_SURFACE_COUNT := 7
const COLLISION_BODY_COUNT := 7
const COLLISION_SHAPE_COUNT := 7
## Exact post-batch renderer census. The visual-only trunk expansion strips and
## slab corner beacons still draw at their authored transforms, while one
## MultiMesh per family owns each family's submission. The beacon nodes remain
## hidden as stable named inspection anchors.
const TRUNK_EXPANSION_JOINT_COPY_COUNT := 12
const SLAB_CORNER_BEACON_COPY_COUNT := 12
const SLAB_SUPPORT_COPY_COUNT := 6
const PRE_SLAB_BEACON_GEOMETRY_SUBMISSION_COUNT := 90
const PRE_SLAB_SUPPORT_GEOMETRY_SUBMISSION_COUNT := 79
const RENDER_DESCENDANT_COUNT := 135
const RENDER_MESH_INSTANCE_COUNT := 89
const RENDER_MULTIMESH_BATCH_COUNT := 3
const RENDER_DRAWN_COPY_COUNT := 101
const RENDER_GEOMETRY_SUBMISSION_COUNT := 74
const ASSIGNED_DOCK_01_CENTER := Vector3(15.0, -0.3, 8.5)
const ASSIGNED_DOCK_01_SIZE := Vector3(12.0, 0.6, 15.0)

## Dock-slab indices whose outboard face is still a drop into open void, and which
## therefore still carry a toe kerb along it.
##
## Arm 02 is absent, and the reason is measured rather than stylistic. The
## Halyard berth pass built `ShipyardWorld`'s `HalyardApronNose` — a 12.0 x 11.0 m
## walkable plate at world `x 31.0 … 43.0, z 36.3 … 47.3`, flush with this slab at
## `y = 4.2` — directly against `DockSlab02`'s outboard face. `DockEdgeKerb02`
## stood at world `x 31.80 … 42.20, z 47.30 … 47.58`: exactly on that seam. The
## edge it was marking stopped being an edge, and what was left was a 0.130 m lip
## lying across the middle of one unbroken 34.4 m berth pad with walkable deck on
## both sides of it — 0.010 m under the walking player's own no-jump step height,
## in the middle of the floor, marking nothing.
##
## Removed rather than lowered or repurposed. Lowering it leaves a stripe
## pretending to be structure; repurposing it as a threshold invents a meaning
## this module's grammar does not have, where the assigned/deferred distinction is
## carried by service-hardware state. Docks 01 and 03 keep theirs, because their
## outboard faces — `x 15.30 … 25.70` and `x 46.80 … 57.20` at the same `z` — are
## nowhere near the apron and still drop into genuine void.
const DROP_EDGE_DOCK_INDICES: Array[int] = [0, 2]

# The root is the connection plane. Local +Z follows the narrow trunk and every
# broad slab is on local +X, keeping the module starboard-biased and rotatable.
const FOOTPRINT_MIN := Vector3(-2.6, -2.5, 0.0)
const FOOTPRINT_MAX := Vector3(21.0, 5.0, 48.0)

# Re-frozen in the open, 64 -> 107, by the dock-arm service pass. Measured, not
# guessed: the module built 58 visible meshes before it and builds 100 after, so
# the ceiling keeps roughly the same headroom over the built figure that the old
# one did (6 -> 7). The 42 additions are the per-arm service hardware — bracket,
# service pod, mast, umbilical head, cap, status lens, boom, toe kerb, two mooring
# cleat pads and two bollards on each of the three arms, one dropped umbilical
# hose on the assigned arm — plus the two trunk conduits and three rung branch
# conduits that tie the arms back to the trunk. No collision body, shape, label,
# route marker, dock marker, walkable surface or published envelope moves: the
# collision and label budgets below are untouched and still exact.
#
# Not re-frozen by the 2026-08-16 dock-02 promotion pass, and that is a measured
# statement rather than an omission: that pass removed one mesh (`DockEdgeKerb02`,
# whose edge the Halyard apron built over) and added one (`DockUmbilicalHose02`,
# because arm 02's boom now runs out like arm 01's), so the module still drew
# exactly 100 visible copies against this same 107 MeshInstance ceiling.
# Batching the twelve trunk joint strips later reduced the live MeshInstance
# count to 88 plus one MultiMesh without changing those 100 drawn copies. The
# historical ceiling remains policy; the exact renderer contract below freezes
# the new topology. Collision bodies, shapes, labels, lights and both loop counts
# are all untouched too.
const MESH_INSTANCE_BUDGET := 107
const STATIC_BODY_BUDGET := COLLISION_BODY_COUNT
const COLLISION_SHAPE_BUDGET := COLLISION_SHAPE_COUNT
const LABEL_BUDGET := DOCK_MARKER_COUNT
# Re-frozen in the open, 0 -> 4. The comb was the only station module with no
# light of any kind, and it showed: three dock slabs carrying stripes, corner
# beacons and edge cues that every one of them rendered as a flat painted decal
# on unlit plate, because `emission` illuminates nothing in Forward+ and the glow
# pass only convolves the finished image. The four additions are one amber
# practical per slab, sited over the four corner beacons it shares, plus one over
# the trunk's middle route light. They are shadowless, range-bounded, faded out
# at 26 m, and none of them is a process or physics loop — the "static geometry,
# no frame cost" half of this module's policy is unchanged, and the two loop
# budgets stay at zero. Frame cost is unmeasured: this box renders through
# llvmpipe and any number produced here would be meaningless.
#
# Re-frozen again in the open, 4 -> 7, by the dock-arm service pass, for exactly
# the same mechanism and with exactly the same idiom: each arm's new mast status
# lens is emissive, emission lights nothing in Forward+, and without a practical
# it is one more glowing decal on unlit plate. The three additions are one amber
# spill per mast head, shadowless, `omni_range` 5.4 m, faded out at the same
# 60/25 m as every other comb practical. Both loop budgets stay at zero and frame
# cost stays unmeasured for the reason recorded above.
const LIGHT_BUDGET := 7

## Distance fade applied to every comb practical. Measured, not chosen — see
## `_dock_practical`.
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0

const SURFACE_IDS := [
	"trunk",
	"rung-01",
	"dock-slab-01",
	"rung-02",
	"dock-slab-02",
	"rung-03-vertical",
	"dock-slab-03-upper",
]

const RUNG_IDS := [
	"rung-01",
	"rung-02",
	"rung-03-vertical",
]

const DOCK_SLAB_IDS := [
	"dock-slab-01",
	"dock-slab-02",
	"dock-slab-03-upper",
]

## Dock marker ids in slab order, so a builder working by slab index can ask the
## registry what that dock's status actually is. The ids themselves are the
## originals and deliberately keep their historical spelling: `deferred-dock-02`
## was promoted to an external assignment without being renamed, and renaming a
## published key to make a comment read better would break every consumer that
## already knows it.
const DOCK_MARKER_IDS: Array[StringName] = [
	&"assigned-dock-01",
	&"deferred-dock-02",
	&"deferred-dock-03",
]

const EVIDENCE_REFERENCES := [
	"B2@04:55-05:10 / OE-B2-COMB / long narrow trunk with perpendicular rung-like arms",
	"B2@04:55-05:10 / OE-B2-SLABS / broad end slabs separated by genuine voids",
	"B2@04:40-05:10 / OE-B2-BERTHS / ships at separate lattice offsets",
]

const CONTENT_NOTE := (
	"B2 supports the repeated comb rhythm, broad separated end volumes, and ships "
	+ "distributed at lattice offsets. Fleet Dock Comb is not recovered original "
	+ "geometry: its name, exact three-tooth count, measurements, starboard bias, "
	+ "surface design, short ramp, materials, labels, and world adjacency are modern "
	+ "interpretation. Dock 01 is a modern externally-owned assignment for the "
	+ "B7-observed Zenith partial reconstruction; Dock 02 is a modern externally-"
	+ "owned assignments for the project-original modern Halyard and Bulwark designs. No marker "
	+ "grants landing, lease, boarding, regeneration, or ship-"
	+ "spawn authority inside this module. The per-arm service hardware — mast, "
	+ "umbilical head, boom, service pod, mooring cleats, toe kerb and the trunk/rung conduit "
	+ "run — is modern interpretation with no source at all: no anchor in any "
	+ "source describes how the original station moored, fed or serviced a docked "
	+ "craft, and the deployed/stowed distinction between the assigned and the "
	+ "deferred arms is a presentation convention, not a recovered operating state."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_approach: Marker3D = %RouteApproach
@onready var _route_trunk_forward: Marker3D = %RouteTrunkForward
@onready var _route_dock_01_threshold: Marker3D = %RouteDock01Threshold
@onready var _route_trunk_mid: Marker3D = %RouteTrunkMid
@onready var _route_dock_02_threshold: Marker3D = %RouteDock02Threshold
@onready var _route_trunk_aft: Marker3D = %RouteTrunkAft
@onready var _route_vertical_base: Marker3D = %RouteVerticalBase
@onready var _route_vertical_top: Marker3D = %RouteVerticalTop
@onready var _route_dock_03_threshold: Marker3D = %RouteDock03Threshold
@onready var _assigned_dock_01: Marker3D = %AssignedDock01
@onready var _deferred_dock_02: Marker3D = %DeferredDock02
@onready var _deferred_dock_03: Marker3D = %DeferredDock03

var _materials: Dictionary = {}
var _route_markers: Dictionary = {}
var _dock_markers: Dictionary = {}
var _surface_nodes: Dictionary = {}
var _build_root: Node3D
var _enabled := true
var _built := false
var _build_generation := 0
## Size-keyed chamfered box meshes. Equal-sized boxes share one `ArrayMesh`, so
## the twelve identical trunk expansion joints and the repeated dock furniture
## pay for their extra edge geometry once.
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _trunk_expansion_joint_transforms: Array[Transform3D] = []
var _trunk_expansion_joint_batch: MultiMeshInstance3D = null
var _slab_corner_beacon_transforms: Array[Transform3D] = []
var _slab_corner_beacon_batch: MultiMeshInstance3D = null
var _slab_support_transforms: Array[Transform3D] = []
var _slab_support_batch: MultiMeshInstance3D = null


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _built:
		_built = true
		_create_materials()
		_index_semantics()
		_build_structure()
		_apply_metadata()
		_build_generation += 1
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


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
		result[route_id] = (_route_markers[route_id] as Marker3D).global_transform
	return result


func get_deferred_dock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for dock_id: StringName in _dock_markers.keys():
		var marker := _dock_markers[dock_id] as Marker3D
		if StringName(marker.get_meta("dock_status", &"")) == &"deferred_empty":
			result.append(dock_id)
	result.sort()
	return result


func get_deferred_dock_marker(dock_id: StringName) -> Marker3D:
	if dock_id not in get_deferred_dock_ids():
		return null
	return get_dock_marker(dock_id)


func get_deferred_dock_transform(dock_id: StringName) -> Transform3D:
	var marker := get_deferred_dock_marker(dock_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


func get_assigned_dock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for dock_id: StringName in _dock_markers.keys():
		var marker := _dock_markers[dock_id] as Marker3D
		if StringName(marker.get_meta("dock_status", &"")) == &"assigned_external":
			result.append(dock_id)
	result.sort()
	return result


func get_dock_marker(dock_id: StringName) -> Marker3D:
	return _dock_markers.get(dock_id) as Marker3D


func get_dock_transform(dock_id: StringName) -> Transform3D:
	var marker := get_dock_marker(dock_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


## These are presentation landmarks, not ShipBerth specifications. No landing
## extents or compatibility tags are intentionally exposed.
func get_deferred_dock_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dock_id in get_deferred_dock_ids():
		var marker := get_dock_marker(dock_id)
		result.append({
			"dock_id": dock_id,
			"status": &"deferred_empty",
			"marker_transform": marker.global_transform,
			"ship_assignment": &"none",
			"owns_berth_authority": false,
			"landing_volume_present": false,
			"boarding_area_present": false,
			"evidence_claim": &"OE-B2-BERTHS",
		})
	return result.duplicate(true)


func get_assigned_dock_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dock_id in get_assigned_dock_ids():
		var marker := get_dock_marker(dock_id)
		result.append({
			"dock_id": dock_id,
			"status": &"assigned_external",
			"marker_transform": marker.global_transform,
			"ship_assignment": StringName(marker.get_meta("ship_assignment", &"")),
			"berth_id": StringName(marker.get_meta("external_berth_id", &"")),
			"owns_berth_authority": false,
			"landing_volume_present": false,
			"boarding_area_present": false,
			"evidence_claim": &"OE-B2-BERTHS",
			"historical_class_to_berth_mapping": false,
		})
	return result.duplicate(true)


func get_dock_roster() -> Array[Dictionary]:
	var result := get_assigned_dock_roster()
	result.append_array(get_deferred_dock_roster())
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return str(first.get("dock_id", &"")) < str(second.get("dock_id", &""))
	)
	return result.duplicate(true)


func get_integration_footprint() -> Dictionary:
	return {
		"anchor_transform": _module_anchor.global_transform,
		"connection_plane_local": Transform3D.IDENTITY,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
		"comb_teeth_axis_local": Vector3.RIGHT,
		"starboard_biased": true,
		"assigned_dock_01_walkable_aabb": AABB(
			ASSIGNED_DOCK_01_CENTER - ASSIGNED_DOCK_01_SIZE * 0.5,
			ASSIGNED_DOCK_01_SIZE
		),
	}


func get_bounds_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"local_aabb": AABB(FOOTPRINT_MIN, FOOTPRINT_MAX - FOOTPRINT_MIN),
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"world_aabb": _transform_aabb(AABB(FOOTPRINT_MIN, FOOTPRINT_MAX - FOOTPRINT_MIN), global_transform),
		"trunk_length": TRUNK_LENGTH,
		"trunk_clear_width": TRUNK_CLEAR_WIDTH,
		"rung_clear_width": RUNG_CLEAR_WIDTH,
		"floor_elevations": PackedFloat32Array([LOWER_DECK_ELEVATION, UPPER_DECK_ELEVATION]),
		"full_footprint_floor_present": _has_full_footprint_floor(),
		"negative_space_samples_local": get_negative_space_samples(),
		"assigned_dock_01_walkable_aabb": AABB(
			ASSIGNED_DOCK_01_CENTER - ASSIGNED_DOCK_01_SIZE * 0.5,
			ASSIGNED_DOCK_01_SIZE
		),
	}


func get_negative_space_samples() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(15.0, 1.0, 17.5),
		Vector3(15.0, 1.0, 32.5),
		Vector3(15.0, 1.0, 47.5),
		Vector3(6.5, 1.0, 17.5),
		Vector3(6.5, 1.0, 32.5),
	])


func get_component_roster() -> Dictionary:
	var actual_surface_ids := PackedStringArray()
	for raw_id in _surface_nodes.keys():
		actual_surface_ids.append(str(raw_id))
	actual_surface_ids.sort()
	var expected_surface_ids := PackedStringArray(SURFACE_IDS)
	expected_surface_ids.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"surface_ids": actual_surface_ids,
		"expected_surface_ids": expected_surface_ids,
		"walkable_surface_count": _surface_nodes.size(),
		"rung_ids": PackedStringArray(RUNG_IDS),
		"rung_count": RUNG_COUNT,
		"dock_slab_ids": PackedStringArray(DOCK_SLAB_IDS),
		"dock_slab_count": DOCK_SLAB_COUNT,
		# Published so the dock-arm service pass is auditable as a roster rather
		# than only as a mesh count: every arm carries one mast and two mooring
		# cleats, and exactly one arm — the assigned one — has its boom deployed.
		"dock_service_mast_count": _count_service_nodes("DockServiceMast"),
		"dock_mooring_cleat_count": _count_service_nodes("DockMooringCleatBollard"),
		"deployed_service_boom_count": _count_service_nodes("DockUmbilicalHose"),
		"vertical_transition_count": 1,
		"dock_marker_count": _dock_markers.size(),
		"assigned_dock_ids": PackedStringArray(get_assigned_dock_ids()),
		"assigned_dock_count": get_assigned_dock_ids().size(),
		"deferred_dock_ids": PackedStringArray(get_deferred_dock_ids()),
		"deferred_dock_count": get_deferred_dock_ids().size(),
		"route_ids": PackedStringArray(get_route_ids()),
		"render_batches": get_render_batch_contract(),
	}


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)
	contract["schema_version"] = SCHEMA_VERSION
	contract["expected_surface_ids"] = PackedStringArray(SURFACE_IDS)
	contract["full_footprint_floor_present"] = _has_full_footprint_floor()
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	contract["boarding_authority_count"] = 0
	# Dock markers are placement hints for the fleet layer, never a claim of
	# ownership over the ships parked against them.
	contract["dock_markers_are_authoritative"] = false
	return contract


func get_performance_contract() -> Dictionary:
	# Budgets are this module's own policy: the comb is fixed geometry with an
	# exact surface and marker count, so its ceilings are the counts themselves
	# and it is allowed no lights and no frame or physics loop at all.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": MESH_INSTANCE_BUDGET,
		"static_bodies": STATIC_BODY_BUDGET,
		"collision_shapes": COLLISION_SHAPE_BUDGET,
		"labels": LABEL_BUDGET,
		"lights": LIGHT_BUDGET,
		"process_loops": 0,
		"physics_process_loops": 0,
	})
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_render_batch_contract() -> Dictionary:
	var mesh_nodes := find_children("*", "MeshInstance3D", true, false)
	var batch_nodes := find_children("*", "MultiMeshInstance3D", true, false)
	var drawn_copies := 0
	var submissions := 0
	for raw_node in mesh_nodes:
		var instance := raw_node as MeshInstance3D
		if instance.mesh == null or not instance.visible:
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

	var expected_joint_buffer := _encode_multimesh_transforms(_trunk_expansion_joint_transforms)
	var joint_buffer_matches := (
		is_instance_valid(_trunk_expansion_joint_batch)
		and _trunk_expansion_joint_batch.multimesh != null
		and _trunk_expansion_joint_batch.multimesh.buffer == expected_joint_buffer
	)
	var expected_beacon_buffer := _encode_multimesh_transforms(_slab_corner_beacon_transforms)
	var beacon_buffer_matches := (
		is_instance_valid(_slab_corner_beacon_batch)
		and _slab_corner_beacon_batch.multimesh != null
		and _slab_corner_beacon_batch.multimesh.buffer == expected_beacon_buffer
	)
	var joint_bounds_match := false
	if is_instance_valid(_trunk_expansion_joint_batch) and _trunk_expansion_joint_batch.multimesh != null:
		var expected_bounds := _transformed_mesh_bounds(
			_trunk_expansion_joint_batch.multimesh.mesh.get_aabb(),
			_trunk_expansion_joint_transforms
		)
		joint_bounds_match = _trunk_expansion_joint_batch.multimesh.custom_aabb.is_equal_approx(expected_bounds)
	var beacon_bounds_match := false
	if is_instance_valid(_slab_corner_beacon_batch) and _slab_corner_beacon_batch.multimesh != null:
		var expected_beacon_bounds := _transformed_mesh_bounds(
			_slab_corner_beacon_batch.multimesh.mesh.get_aabb(),
			_slab_corner_beacon_transforms
		)
		beacon_bounds_match = _slab_corner_beacon_batch.multimesh.custom_aabb.is_equal_approx(expected_beacon_bounds)
	var expected_support_buffer := _encode_multimesh_transforms(_slab_support_transforms)
	var support_buffer_matches := (
		is_instance_valid(_slab_support_batch)
		and _slab_support_batch.multimesh != null
		and _slab_support_batch.multimesh.buffer == expected_support_buffer
	)
	var support_bounds_match := false
	var support_contract_matches := false
	if is_instance_valid(_slab_support_batch) and _slab_support_batch.multimesh != null:
		var support_multi := _slab_support_batch.multimesh
		var expected_support_bounds := _transformed_mesh_bounds(
			support_multi.mesh.get_aabb(), _slab_support_transforms
		)
		support_bounds_match = support_multi.custom_aabb.is_equal_approx(expected_support_bounds)
		support_contract_matches = (
			_slab_support_batch.transform.is_equal_approx(Transform3D.IDENTITY)
			and support_multi.instance_count == SLAB_SUPPORT_COPY_COUNT
			and support_multi.visible_instance_count == -1
			and support_multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.55, 2.5, 0.55))
			and support_multi.mesh.get_surface_count() == 1
			and _slab_support_batch.material_override == _materials.get("frame")
			and _slab_support_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and _slab_support_batch.layers == 1
			and _slab_support_batch.get_child_count() == 0
			and _slab_support_batch.get_script() == null
		)
	var descendant_count := find_children("*", "Node", true, false).size()
	var exact_counts := (
		descendant_count == RENDER_DESCENDANT_COUNT
		and mesh_nodes.size() == RENDER_MESH_INSTANCE_COUNT
		and batch_nodes.size() == RENDER_MULTIMESH_BATCH_COUNT
		and drawn_copies == RENDER_DRAWN_COPY_COUNT
		and submissions == RENDER_GEOMETRY_SUBMISSION_COUNT
		and _trunk_expansion_joint_transforms.size() == TRUNK_EXPANSION_JOINT_COPY_COUNT
		and _slab_corner_beacon_transforms.size() == SLAB_CORNER_BEACON_COPY_COUNT
		and _slab_support_transforms.size() == SLAB_SUPPORT_COPY_COUNT
		and support_contract_matches
	)
	var joint_buffer_floats := (
		_trunk_expansion_joint_batch.multimesh.buffer.size()
		if is_instance_valid(_trunk_expansion_joint_batch) and _trunk_expansion_joint_batch.multimesh != null
		else 0
	)
	var beacon_buffer_floats := (
		_slab_corner_beacon_batch.multimesh.buffer.size()
		if is_instance_valid(_slab_corner_beacon_batch) and _slab_corner_beacon_batch.multimesh != null
		else 0
	)
	var support_buffer_floats := (
		_slab_support_batch.multimesh.buffer.size()
		if is_instance_valid(_slab_support_batch) and _slab_support_batch.multimesh != null
		else 0
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"descendant_nodes": descendant_count,
		"mesh_instances": mesh_nodes.size(),
		"multimesh_batches": batch_nodes.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
		"trunk_expansion_joint_copies": _trunk_expansion_joint_transforms.size(),
		"slab_corner_beacon_copies": _slab_corner_beacon_transforms.size(),
		"slab_support_copies": _slab_support_transforms.size(),
		"slab_support_submissions_before": SLAB_SUPPORT_COPY_COUNT,
		"slab_support_submissions_after": 1,
		"geometry_submissions_before_slab_support_batch": PRE_SLAB_SUPPORT_GEOMETRY_SUBMISSION_COUNT,
		"slab_corner_beacon_submissions_before": SLAB_CORNER_BEACON_COPY_COUNT,
		"slab_corner_beacon_submissions_after": 1,
		"geometry_submissions_before_slab_beacon_batch": PRE_SLAB_BEACON_GEOMETRY_SUBMISSION_COUNT,
		"geometry_submissions_removed": PRE_SLAB_BEACON_GEOMETRY_SUBMISSION_COUNT - submissions,
		"trunk_renderer_buffer_floats": joint_buffer_floats,
		"slab_corner_beacon_renderer_buffer_floats": beacon_buffer_floats,
		"slab_support_renderer_buffer_floats": support_buffer_floats,
		"renderer_buffer_floats": joint_buffer_floats + beacon_buffer_floats + support_buffer_floats,
		"renderer_buffer_matches_authored": joint_buffer_matches and beacon_buffer_matches and support_buffer_matches,
		"trunk_renderer_buffer_matches_authored": joint_buffer_matches,
		"slab_corner_beacon_renderer_buffer_matches_authored": beacon_buffer_matches,
		"slab_support_renderer_buffer_matches_authored": support_buffer_matches,
		"bounds_match_authored": joint_bounds_match and beacon_bounds_match and support_bounds_match,
		"trunk_bounds_match_authored": joint_bounds_match,
		"slab_corner_beacon_bounds_match_authored": beacon_bounds_match,
		"slab_support_bounds_match_authored": support_bounds_match,
		"slab_support_contract_matches": support_contract_matches,
		"exact_counts": exact_counts,
		"authored_joint_transforms": _trunk_expansion_joint_transforms.duplicate(),
		"authored_slab_corner_beacon_transforms": _slab_corner_beacon_transforms.duplicate(),
		"authored_slab_support_transforms": _slab_support_transforms.duplicate(),
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
		"route_markers": get_route_ids().size(),
		"dock_landmarks": get_dock_roster().size(),
	}


func set_module_enabled(enabled: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _enabled


func get_lifecycle_contract() -> Dictionary:
	# The generated build root carries this module's visibility: the module node
	# itself stays visible so its markers keep resolving while it is disabled.
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _enabled, _build_root
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built and _build_root != null
	contract["build_generation"] = _build_generation
	# Surfaces are reported in declared order from the authoritative map rather
	# than in tree order, so the ids line up with `SURFACE_IDS`.
	var surface_instance_ids := PackedInt64Array()
	for surface_id in SURFACE_IDS:
		var surface := _surface_nodes.get(surface_id) as StaticBody3D
		if surface != null:
			surface_instance_ids.append(surface.get_instance_id())
	contract["surface_instance_ids"] = surface_instance_ids
	return contract


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"references": PackedStringArray(EVIDENCE_REFERENCES),
		"claim_ids": PackedStringArray(["OE-B2-COMB", "OE-B2-SLABS", "OE-B2-BERTHS"]),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray([
			"long narrow trunk with short orthogonal rungs",
			"broad separated end slabs with substantial negative space",
			"ships distributed at separate station lattice offsets",
		]),
		"modern_interpretations": PackedStringArray([
			"Fleet Dock Comb name and exact three-tooth roster",
			"all dimensions, directions, surface details, and station placement",
			"starboard-only bias and one short vertical ramp",
			"dock labels, marker transforms, the Zenith-to-dock-01 assignment, and the Halyard-to-dock-02 assignment",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical arm, slab, and berth count",
			"exact scale, directions, elevations, functions, and adjacency",
			"ship-class assignments for the observed separated berths",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null or not _module_anchor.global_transform.is_equal_approx(global_transform):
		errors.append("module integration anchor must match the exact root connection plane")
	if _route_markers.size() != 9:
		errors.append("route marker registry must contain exactly nine explicit nodes")
	if _dock_markers.size() != DOCK_MARKER_COUNT:
		errors.append("dock registry must contain exactly three physical landmarks")
	if get_assigned_dock_ids().size() != ASSIGNED_DOCK_COUNT:
		errors.append("dock registry must contain exactly three external assignments")
	if get_deferred_dock_ids().size() != DEFERRED_DOCK_COUNT:
		errors.append("dock registry must contain no empty deferred landmarks")
	if _surface_nodes.size() != WALKABLE_SURFACE_COUNT:
		errors.append("walkable surface roster must contain exactly seven collision-backed surfaces")
	var roster := get_component_roster()
	if roster.surface_ids != roster.expected_surface_ids:
		errors.append("walkable surface identity roster differs from the declared contract")
	if int(roster.rung_count) != RUNG_COUNT or int(roster.dock_slab_count) != DOCK_SLAB_COUNT:
		errors.append("comb must preserve exactly three rungs and three broad slabs")
	var collision := get_collision_contract()
	if int(collision.body_count) != COLLISION_BODY_COUNT or int(collision.shape_count) != COLLISION_SHAPE_COUNT:
		errors.append("collision roster must remain one body and shape per walkable surface")
	if not bool(collision.all_layers_match_lifecycle) or not bool(collision.all_masks_zero):
		errors.append("collision layers or masks differ from the canonical lifecycle contract")
	if bool(collision.full_footprint_floor_present):
		errors.append("a hidden full-footprint floor destroys the required station voids")
	var authority := get_authority_contract()
	if int(authority.ship_berth_count) != 0 \
		or int(authority.landing_or_interaction_area_count) != 0 \
		or int(authority.audio_node_count) != 0 \
		or int(authority.activity_node_count) != 0:
		errors.append("comb module must own no berth, area, audio, or activity authority")
	for dock in get_dock_roster():
		if bool(dock.owns_berth_authority) \
			or bool(dock.landing_volume_present) \
			or bool(dock.boarding_area_present):
			errors.append("dock landmarks must remain non-authoritative inside the comb")
			break
	# Three external assignments, checked by dock id rather than by position, so a
	# reordered roster cannot silently validate the wrong dock. Neither is a
	# historical class-to-berth mapping: dock 01 carries the B7-observed Zenith
	# reconstruction, while dock 02 and dock 03 carry original modern designs.
	var expected_assignments := {
		&"assigned-dock-01": {
			"ship": &"zenith_b7_observed",
			"berth": &"zenith_fleet_dock_berth",
		},
		&"deferred-dock-02": {
			"ship": &"halyard_new_design",
			"berth": &"halyard_fleet_dock_berth",
		},
		&"deferred-dock-03": {
			"ship": &"bulwark_heavy_gunship",
			"berth": &"bulwark_fleet_dock_berth",
		},
	}
	var assigned := get_assigned_dock_roster()
	if assigned.size() != ASSIGNED_DOCK_COUNT:
		errors.append("external dock assignment roster drifted from its declared size")
	else:
		for dock in assigned:
			var dock_id: StringName = dock.dock_id
			if not expected_assignments.has(dock_id):
				errors.append("dock %s published an unregistered external assignment" % dock_id)
				continue
			var expected: Dictionary = expected_assignments[dock_id]
			if dock.ship_assignment != expected["ship"] \
				or dock.berth_id != expected["berth"] \
				or bool(dock.historical_class_to_berth_mapping):
				errors.append("dock %s external assignment drifted or gained a historical claim" % dock_id)
	if not bool(get_performance_contract().within_budget):
		errors.append("module exceeds its fixed geometry or processing budget")
	var rendering := get_render_batch_contract()
	if not bool(rendering.exact_counts):
		errors.append("comb renderer node, batch, copy, or submission counts drifted")
	if not bool(rendering.trunk_renderer_buffer_matches_authored):
		errors.append("comb trunk-joint renderer buffer drifted from its authored roster")
	if not bool(rendering.trunk_bounds_match_authored):
		errors.append("comb trunk-joint batch bounds drifted from its authored copies")
	if not bool(rendering.slab_corner_beacon_renderer_buffer_matches_authored):
		errors.append("comb slab-corner-beacon renderer buffer drifted from its authored roster")
	if not bool(rendering.slab_corner_beacon_bounds_match_authored):
		errors.append("comb slab-corner-beacon batch bounds drifted from its authored copies")
	if not bool(rendering.slab_support_renderer_buffer_matches_authored):
		errors.append("comb slab-support renderer buffer drifted from its authored roster")
	if not bool(rendering.slab_support_bounds_match_authored):
		errors.append("comb slab-support batch bounds drifted from its authored copies")
	if not bool(rendering.slab_support_contract_matches):
		errors.append("comb slab-support renderer contract drifted")
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
		or not bool(lifecycle.visible_matches_enabled) \
		or not bool(lifecycle.collision_matches_enabled) \
		or not bool(lifecycle.process_free):
		errors.append("identity-preserving enable/disable lifecycle is inconsistent")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence": get_evidence_metadata(),
		"roster": get_component_roster(),
		"bounds": get_bounds_contract(),
		"collision": get_collision_contract(),
		"authority": get_authority_contract(),
		"performance": get_performance_contract(),
		"render_batches": get_render_batch_contract(),
		"lifecycle": get_lifecycle_contract(),
		"assigned_docks": get_assigned_dock_roster(),
		"deferred_docks": get_deferred_dock_roster(),
		"docks": get_dock_roster(),
	}.duplicate(true)


func audit() -> Dictionary:
	return get_audit_report()


func _index_semantics() -> void:
	_route_markers = {
		&"approach": _route_approach,
		&"trunk-forward": _route_trunk_forward,
		&"dock-01-threshold": _route_dock_01_threshold,
		&"trunk-mid": _route_trunk_mid,
		&"dock-02-threshold": _route_dock_02_threshold,
		&"trunk-aft": _route_trunk_aft,
		&"vertical-base": _route_vertical_base,
		&"vertical-top": _route_vertical_top,
		&"dock-03-threshold": _route_dock_03_threshold,
	}
	_dock_markers = {
		&"assigned-dock-01": _assigned_dock_01,
		&"deferred-dock-02": _deferred_dock_02,
		&"deferred-dock-03": _deferred_dock_03,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	# The trunk approach is the only station connection slot. The three dock
	# thresholds serve deferred or externally assigned docks and own no berth
	# authority, so they never join the station adjacency graph.
	_route_approach.set_meta(StationModuleContract.CONNECTION_SLOT_META, HUB_CONNECTION_SLOT)
	for dock_id: StringName in _dock_markers.keys():
		var marker := _dock_markers[dock_id] as Marker3D
		marker.set_meta("dock_id", dock_id)
		marker.set_meta("owns_berth_authority", false)
		marker.set_meta("evidence_claim", &"OE-B2-BERTHS")
		if dock_id == &"assigned-dock-01":
			marker.set_meta("deferred_dock", false)
			marker.set_meta("dock_status", &"assigned_external")
			marker.set_meta("ship_assignment", &"zenith_b7_observed")
			marker.set_meta("external_berth_id", &"zenith_fleet_dock_berth")
			marker.set_meta("historical_class_to_berth_mapping", false)
		elif dock_id == &"deferred-dock-02":
			# The Halyard is an original modern design, so this assignment maps a
			# modern name to a modern slab and still claims nothing historical.
			marker.set_meta("deferred_dock", false)
			marker.set_meta("dock_status", &"assigned_external")
			marker.set_meta("ship_assignment", &"halyard_new_design")
			marker.set_meta("external_berth_id", &"halyard_fleet_dock_berth")
			marker.set_meta("historical_class_to_berth_mapping", false)
		elif dock_id == &"deferred-dock-03":
			# Bulwark is an original modern design; this production assignment
			# makes no historical class-to-berth claim.
			marker.set_meta("deferred_dock", false)
			marker.set_meta("dock_status", &"assigned_external")
			marker.set_meta("ship_assignment", &"bulwark_heavy_gunship")
			marker.set_meta("external_berth_id", &"bulwark_fleet_dock_berth")
			marker.set_meta("historical_class_to_berth_mapping", false)
		else:
			marker.set_meta("deferred_dock", true)
			marker.set_meta("dock_status", &"deferred_empty")
			marker.set_meta("ship_assignment", &"none")


func _create_materials() -> void:
	# The two broad walking surfaces are traffic-worn plate, not mirror steel.
	# They were metallic 0.62/0.42, which was survivable while station ambient was
	# a flat cyan colour that metals could reflect. Ambient is now sky-sourced and
	# the sky is near-black, so at that metalness a 12 m dock slab lost its diffuse
	# response and photographed as an unreadable black rectangle. The structural
	# frame, underframe and grip keep their original metal values.
	_materials["deck"] = _material(Color("8b9698"), 0.16, 0.56)
	_materials["deck_light"] = _material(Color("bdc5c4"), 0.14, 0.44)
	_materials["frame"] = _material(Color("304248"), 0.72, 0.31)
	_materials["underframe"] = _material(Color("17252b"), 0.76, 0.36)
	_materials["grip"] = _material(Color("26363b"), 0.35, 0.68)
	_materials["cyan"] = _material(Color("55dfe2"), 0.14, 0.28, Color("36cdd2"), 1.4)
	_materials["amber"] = _material(Color("f2a84b"), 0.35, 0.31, Color("e9872c"), 1.1)
	_materials["deferred"] = _material(Color("d5564d"), 0.18, 0.38, Color("a72f2b"), 0.9)
	_apply_station_panel_family()


## Bind the registered station panel/normal/roughness recipe to the comb's
## structural greys.
##
## The 12 m dock slabs and the 48 m trunk were the largest unmapped surfaces in
## the station: uniform scalar teal across a whole berth, which is the single
## clearest "untextured primitive" read in the frames. The recipe, `normal_scale`,
## red-channel roughness, world-triplanar mode and sharpness are copied verbatim
## from the station family at the 0.30 physical scale `ShipyardWorld` and
## `AftJunctionStack` use, so the comb decks are the same plate stock as the hub
## they bolt onto and no plate size changes across the connector seam.
## Emissive route/status cues stay unmapped, as they do in every sibling module.
func _apply_station_panel_family() -> void:
	var panel_albedo := load("res://assets/materials/procedural-panel-triplanar-albedo-v2.png") as Texture2D
	var panel_normal := load("res://assets/materials/procedural-panel-triplanar-normal-v2.png") as Texture2D
	var panel_roughness := load("res://assets/materials/procedural-panel-triplanar-roughness-v2.png") as Texture2D
	if panel_albedo == null or panel_normal == null or panel_roughness == null:
		return
	for key in ["deck", "deck_light", "frame", "underframe", "grip"]:
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


func _build_structure() -> void:
	_build_root = Node3D.new()
	_build_root.name = "GeneratedComb"
	_build_root.set_meta("generated_geometry", true)
	_build_root.set_meta("runtime_rebuild_allowed", false)
	add_child(_build_root)

	var surfaces := Node3D.new()
	surfaces.name = "WalkableSurfaces"
	_build_root.add_child(surfaces)

	_register_surface(_surface_box(surfaces, "Trunk", Vector3(0, -0.3, 24.0), Vector3(4.8, 0.6, 48.0), _materials["deck"]), &"trunk", &"trunk")
	_register_surface(_surface_box(surfaces, "Rung01", Vector3(5.5, -0.3, 10.0), Vector3(7.0, 0.6, 3.6), _materials["deck_light"]), &"rung-01", &"orthogonal-rung")
	_register_surface(_surface_box(surfaces, "DockSlab01", ASSIGNED_DOCK_01_CENTER, ASSIGNED_DOCK_01_SIZE, _materials["deck"]), &"dock-slab-01", &"broad-assigned-slab")
	_register_surface(_surface_box(surfaces, "Rung02", Vector3(5.5, -0.3, 25.0), Vector3(7.0, 0.6, 3.6), _materials["deck_light"]), &"rung-02", &"orthogonal-rung")
	_register_surface(_surface_box(surfaces, "DockSlab02", Vector3(15.0, -0.3, 25.0), Vector3(12.0, 0.6, 12.0), _materials["deck"]), &"dock-slab-02", &"broad-assigned-slab")

	var ramp_start := Vector3(2.0, LOWER_DECK_ELEVATION, 40.0)
	var ramp_finish := Vector3(9.0, UPPER_DECK_ELEVATION, 40.0)
	var ramp_direction := ramp_finish - ramp_start
	var ramp_angle := atan2(ramp_direction.y, ramp_direction.x)
	var ramp_normal := Vector3(-sin(ramp_angle), cos(ramp_angle), 0.0)
	var ramp_center := (ramp_start + ramp_finish) * 0.5 - ramp_normal * 0.3
	_register_surface(
		_surface_box(
			surfaces,
			"Rung03Vertical",
			ramp_center,
			Vector3(ramp_direction.length(), 0.6, 3.6),
			_materials["deck_light"],
			Vector3(0, 0, rad_to_deg(ramp_angle))
		),
		&"rung-03-vertical",
		&"orthogonal-rung-vertical-transition"
	)
	_register_surface(_surface_box(surfaces, "DockSlab03Upper", Vector3(15.0, 2.1, 40.0), Vector3(12.0, 0.6, 12.0), _materials["deck"]), &"dock-slab-03-upper", &"broad-assigned-slab")

	_build_surface_detail()
	_build_understructure()
	_build_deferred_landmarks()


func _build_surface_detail() -> void:
	var detail := Node3D.new()
	detail.name = "SurfaceDetail"
	detail.set_meta("visual_detail_only", true)
	_build_root.add_child(detail)

	var joint_transforms: Array[Transform3D] = []
	for z_position in [2.0, 6.0, 10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 34.0, 38.0, 42.0, 46.0]:
		joint_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(0, 0.018, float(z_position)))
		)
	_trunk_expansion_joint_transforms.assign(joint_transforms)
	_trunk_expansion_joint_batch = _multimesh_boxes(
		detail,
		"TrunkExpansionJoints",
		Vector3(4.25, 0.035, 0.06),
		_materials["grip"],
		_trunk_expansion_joint_transforms
	)
	for z_position in [5.0, 20.0, 35.0]:
		# COMB-DECK-CUE-001, found by measuring rather than by reading. Every trunk
		# route light was authored at y = 0.045 with a 0.05 m section, so it spanned
		# y = 0.020 … 0.070 over a trunk whose walking surface is exactly y = 0.
		# All three hovered 0.020 m above the plate they are supposed to be inlaid
		# into and touched no geometry anywhere in the module — the same class as
		# the 0.040-0.090 m underframe and crate defects fixed on 2026-08-16, just
		# small enough to have been missed. Centre moved 0.045 -> 0.020 so the cue
		# enters the deck by 0.005 m. Length, width, section, spacing, colour and
		# the practical above it are untouched.
		_visual_box(detail, "TrunkRouteLight", Vector3(0, 0.020, float(z_position)), Vector3(0.22, 0.05, 1.25), _materials["cyan"])
	# One of the three trunk route lights actually lights the trunk. Three would
	# be three copies of the same 4 m pool down a 2 m wide walkway; the middle one
	# alone puts a gradient along the trunk that reads as a lit route rather than
	# three glowing tiles on dark plate.
	_dock_practical(detail, "TrunkRouteSpill", Vector3(0, 0.32, 20.0), Color("7fe0e4"), 0.5, 4.6)

	var slab_specs := [
		[Vector3(15.0, 0.02, 8.5), 0.0],
		[Vector3(15.0, 0.02, 25.0), 0.0],
		[Vector3(15.0, 2.42, 40.0), 2.4],
	]
	_slab_corner_beacon_transforms.clear()
	for index in slab_specs.size():
		var top_center := slab_specs[index][0] as Vector3
		var elevation := float(slab_specs[index][1])
		_visual_box(detail, "SlabInset%02d" % (index + 1), top_center, Vector3(10.4, 0.04, 10.4), _materials["grip"])
		# Read off the dock registry rather than hard-coded to arm 01. That literal
		# was correct exactly once: the module already counted two external
		# assignments, and the Halyard has been standing on arm 02 since the berth
		# pass, but this line kept painting arm 02 in the deferred red because it
		# tested the index instead of the dock's own status. Paint now cannot
		# disagree with the roster it is painting.
		var status_material: Material = (
			_materials["cyan"] if _dock_is_assigned(index) else _materials["deferred"]
		)
		_visual_box(detail, "DockCrossStripe%02d" % (index + 1), top_center + Vector3(0, 0.035, 0), Vector3(8.2, 0.03, 0.18), status_material)
		_visual_box(detail, "DockLongStripe%02d" % (index + 1), top_center + Vector3(0, 0.038, 0), Vector3(0.18, 0.03, 8.2), status_material)
		for corner in [Vector2(-5.1, -5.1), Vector2(-5.1, 5.1), Vector2(5.1, -5.1), Vector2(5.1, 5.1)]:
			var beacon_anchor := _visual_box(
				detail,
				"SlabCornerBeacon%02d" % (index + 1),
				Vector3(15.0 + corner.x, elevation + 0.08, top_center.z + corner.y),
				Vector3(0.48, 0.12, 0.48),
				_materials["amber"]
			)
			_slab_corner_beacon_transforms.append(beacon_anchor.transform)
			# Keep the established names, transforms, meshes and material handles as
			# stable inspection anchors. The single batch below owns their draw.
			beacon_anchor.visible = false
		# One practical per slab, over the slab centre, carrying the amber of the
		# four corner beacons it stands between. Amber for all three rather than
		# each slab's own status colour: the beacons are the constant element, and
		# tinting a whole berth deck with the deferred red would read as an alarm
		# rather than as a dock that is not yet in service. The status stripes keep
		# their exact authored colours and their cyan/red separation.
		_dock_practical(
			detail,
			"SlabBeaconSpill%02d" % (index + 1),
			Vector3(15.0, elevation + 0.55, top_center.z),
			Color("f6b568"),
			0.6,
			7.2
		)
	_slab_corner_beacon_batch = _multimesh_boxes(
		detail,
		"SlabCornerBeacons",
		Vector3(0.48, 0.12, 0.48),
		_materials["amber"],
		_slab_corner_beacon_transforms
	)

	# Narrow edge cues belong only to the true walkable rungs. They never bridge
	# either of the large gaps between slabs.
	#
	# COMB-DECK-CUE-001, same measurement and same fix as the trunk route lights:
	# authored at y = 0.055 with a 0.06 m section, all four spanned y = 0.025 …
	# 0.085 over a rung deck whose top is y = 0, so every one of them hovered
	# 0.025 m clear and touched nothing. Centre moved 0.055 -> 0.025.
	for rung_z in [10.0, 25.0]:
		for side in [-1.0, 1.0]:
			_visual_box(detail, "RungEdgeCue", Vector3(5.5, 0.025, float(rung_z) + float(side) * 1.62), Vector3(6.7, 0.06, 0.1), _materials["amber"])

	_build_dock_arm_service(detail)


## Dock-arm service hardware: what each arm is *for*.
##
## Before this, an arm was a 12 m plate with a painted cross, four corner beacons
## and a floor label. Nothing on it said a ship is fed, held down or serviced
## there, so the three arms differed from each other only by the colour of a
## stripe, and the deferred ones read as unfinished plate rather than as
## commissioned berths waiting for a hull. Each arm now carries a mast with an
## umbilical head, a service boom, two mooring cleats and — where there is still
## an edge to mark — a toe kerb along the drop edge, and the assigned/deferred
## distinction is carried by the *state* of that hardware rather than by paint
## alone: an assigned arm's boom is run out along the berth flank with its
## umbilical hose dropped to the deck bracket, a deferred arm's is stowed
## vertically against the mast with the head blanked. That is a relationship a
## player can read at a glance and one this module can honestly claim, because a
## dock's own servicing state is not a historical assertion about the original
## station.
##
## Which arm is which is read from the dock registry, never from a slab index.
## That distinction became load-bearing when the Halyard was berthed on arm 02:
## the module had already promoted that dock to an external assignment, but every
## builder here still tested `index == 0`, so a 28 m crew transport stood on a
## deferred-red plate with a blanked, stowed boom beside it. A convention that
## says "state, not paint" has to derive the state from the same place the roster
## does or it is just a second kind of paint.
##
## Three placement rules, all measured against the live scene rather than
## assumed, and all of them load-bearing:
##
## 1. **Nothing substantial stands on the walking plate.** The module carries no
##    collision on dressing and its collision roster is frozen at one body per
##    walkable surface, so any waist-height object on the deck would be a solid-
##    looking thing a player walks straight through. Everything tall here stands
##    *outboard* of the slab edge over the void, where no player can reach it and
##    no walkable surface is implied; everything that does touch the plate is a
##    0.19 m cleat or a 0.14 m toe kerb, in the same class as the 0.12 m corner
##    beacons already there.
## 2. **Nothing enters the parked hull.** The live Zenith's world AABB is
##    `x 14.80…29.20, y 4.23…8.48, z 47.95…58.40`, which is module-local
##    `x 9.90…20.35, y 0.03…4.28, z 2.80…17.20` — the ship covers nearly the whole
##    of dock 01's plate. So the cleats sit on the inboard strip at local
##    `x = 9.5` (0.40 m clear of the hull) and the kerb on the outboard strip at
##    `x = 20.86` (0.37 m clear), and the same layout is used on all three arms so
##    the three are not three different designs. The mast stands at `x = 21.9`,
##    1.29 m outboard of the parked hull.
## 3. **Nothing floats.** Every piece below either shares volume with the slab it
##    is bolted to or with the piece it hangs off; the bracket is buried 1.4 m
##    into the slab's own 0.6 m section, the mast foot sits inside the bracket,
##    and the hose ends inside the boom at the top and inside the bracket at the
##    bottom.
func _build_dock_arm_service(detail: Node3D) -> void:
	var service := Node3D.new()
	service.name = "DockArmService"
	service.set_meta("visual_detail_only", true)
	detail.add_child(service)

	for index in DOCK_SLAB_IDS.size():
		var elevation := 0.0 if index < 2 else UPPER_DECK_ELEVATION
		var slab_z := [8.5, 25.0, 40.0][index] as float
		# Same correction as the slab paint above, and it matters more here, because
		# this is the module's *own* stated grammar: assigned versus deferred is
		# carried by the state of the service hardware, not by paint. Arm 02 has had
		# a 28 m crew transport standing on it and its boom stowed against the mast
		# with the head blanked, which said "no craft here" under a craft. Deriving
		# it from the dock registry is what makes that grammar true rather than
		# decorative.
		var assigned := _dock_is_assigned(index)
		var status_material: Material = _materials["cyan"] if assigned else _materials["deferred"]
		var suffix := "%02d" % (index + 1)

		# Bolted through the slab's own section: 1.4 m of this bracket is inside
		# the plate (x 19.6…21.0) and 1.2 m cantilevers past it, which is what the
		# mast stands on.
		_service_box(
			service,
			"DockServiceBracket" + suffix,
			Vector3(20.9, elevation - 0.30, slab_z),
			Vector3(2.6, 0.34, 0.90),
			_materials["frame"],
			"cantilevered service bracket outboard of a walkable dock slab"
		)
		# Pale plate rather than the dark structural grey, decided by looking. In
		# the first rendered pass the mast was `frame` (`304248`), and against a
		# near-black sky it vanished: down the length of an arm at 15 m it read as
		# nothing at all, and only the outboard three-quarter view found it. The
		# mast is the element that says "this is a berth" from across the lattice,
		# so it takes the same `deck_light` plate the decks are made of and
		# silhouettes against space. The bracket, head and boom stay dark, which is
		# what gives the assembly its light/dark separation instead of one grey mass.
		var mast := MeshInstance3D.new()
		mast.name = "DockServiceMast" + suffix
		mast.position = Vector3(21.9, elevation + 1.80, slab_z)
		mast.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
			0.26, 0.26, 4.20, 16, _chamfered_cylinder_cache
		)
		mast.material_override = _materials["deck_light"]
		mast.set_meta("visual_detail_only", true)
		mast.set_meta("non_authoritative_visual", true)
		mast.set_meta("non_walkable_reason", "dock service mast standing outboard of the slab over open void")
		service.add_child(mast)

		_service_box(
			service,
			"DockUmbilicalHead" + suffix,
			Vector3(21.9, elevation + 2.35, slab_z),
			Vector3(0.62, 0.86, 0.72),
			_materials["underframe"],
			"umbilical head carried on a dock service mast"
		)
		_service_box(
			service,
			"DockMastCap" + suffix,
			Vector3(21.9, elevation + 3.98, slab_z),
			Vector3(0.86, 0.22, 0.86),
			_materials["deck_light"],
			"mast head cap over open void outboard of the slab"
		)
		# Mass under the mast foot. Without it the arm's outboard edge is a plate
		# with a stick on it; the pod is what makes the mast read as the top of a
		# service riser rather than as a pole. It hangs off the bracket below the
		# deck line — pod crown y = elevation - 0.45 against a bracket underside of
		# elevation - 0.47 — so it cannot imply a walkable surface.
		_service_box(
			service,
			"DockServicePod" + suffix,
			Vector3(21.9, elevation - 0.90, slab_z),
			Vector3(1.05, 0.90, 1.70),
			_materials["underframe"],
			"service pod slung beneath the slab edge over open void"
		)
		# The status lens, and the only place on this hardware where the assigned
		# and deferred colours differ. Its practical below is amber on all three
		# masts for the reason already recorded for the slab beacons: tinting a
		# whole berth with the deferred red reads as an alarm rather than as a dock
		# awaiting service. Status lives on the lens, working light stays neutral.
		_service_box(
			service,
			"DockMastLamp" + suffix,
			Vector3(21.9, elevation + 3.80, slab_z),
			Vector3(0.34, 0.10, 0.34),
			status_material,
			"mast status lens over open void outboard of the slab"
		)
		if assigned:
			# Run out along the berth flank, deliberately *not* swung over the pad:
			# the pad is the parked hull's airspace and a boom crossing it would
			# read as a boom through a ship.
			_service_box(
				service,
				"DockServiceBoom" + suffix,
				Vector3(21.9, elevation + 2.62, slab_z + 1.30),
				Vector3(0.30, 0.26, 3.10),
				_materials["underframe"],
				"deployed service boom over open void outboard of the slab"
			)
			var hose := _beam_between(
				service,
				"DockUmbilicalHose" + suffix,
				Vector3(21.9, elevation + 2.52, slab_z + 2.60),
				Vector3(21.55, elevation - 0.22, slab_z + 0.30),
				0.075,
				_materials["underframe"]
			)
			hose.set_meta("non_authoritative_visual", true)
			hose.set_meta("non_walkable_reason", "dropped umbilical hose over open void outboard of the slab")
		else:
			_service_box(
				service,
				"DockServiceBoom" + suffix,
				Vector3(21.52, elevation + 2.30, slab_z),
				Vector3(0.34, 2.60, 0.34),
				_materials["underframe"],
				"stowed service boom over open void outboard of the slab"
			)

		# Toe kerb along the drop edge. It is 0.14 m — a kerb, not a rail. A rail
		# here would need collision to be honest, and collision is exactly what
		# this module's frozen one-body-per-surface roster forbids; a 0.14 m kerb
		# marks the edge without pretending to stop anyone.
		#
		# It is only built where there is still an edge to mark. See
		# [constant DROP_EDGE_DOCK_INDICES] for the arm that lost one.
		if index in DROP_EDGE_DOCK_INDICES:
			_service_box(
				service,
				"DockEdgeKerb" + suffix,
				Vector3(20.86, elevation + 0.06, slab_z),
				Vector3(0.28, 0.14, 10.4),
				_materials["frame"],
				""
			)
		for side: float in [-1.0, 1.0]:
			var cleat_z := slab_z + side * 4.4
			_service_box(
				service,
				"DockMooringCleatPad%s_%s" % [suffix, "A" if side < 0.0 else "B"],
				Vector3(9.5, elevation + 0.02, cleat_z),
				Vector3(0.66, 0.05, 0.66),
				_materials["grip"],
				""
			)
			var bollard := MeshInstance3D.new()
			bollard.name = "DockMooringCleatBollard%s_%s" % [suffix, "A" if side < 0.0 else "B"]
			bollard.position = Vector3(9.5, elevation + 0.10, cleat_z)
			bollard.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
				0.20, 0.20, 0.17, 16, _chamfered_cylinder_cache
			)
			bollard.material_override = _materials["underframe"]
			bollard.set_meta("visual_detail_only", true)
			service.add_child(bollard)

		# The lens is emissive and emission lights nothing in Forward+, which is
		# the whole reason this module already carries four practicals. Same
		# treatment, same shadowless range-bounded idiom, same distance fade.
		_dock_practical(
			service,
			"DockMastSpill" + suffix,
			Vector3(21.9, elevation + 3.30, slab_z),
			Color("f6b568"),
			0.5,
			5.4
		)

	# The service run that ties the arms back to the trunk. Two conduits down the
	# trunk between the existing chords, one branch under each rung out to the
	# slab it serves. Every one of them is seated the way COMB-UNDERFRAME-001
	# taught: crowns enter the deck section they are bolted to rather than hanging
	# below it, which is why they are at y = -0.66 with a 0.09 m radius against a
	# deck underside of y = -0.60.
	for conduit_spec in [["Port", -1.15], ["Starboard", 1.15]]:
		_beam_between(
			service,
			"TrunkServiceConduit" + str(conduit_spec[0]),
			Vector3(float(conduit_spec[1]), -0.66, 1.0),
			Vector3(float(conduit_spec[1]), -0.66, 47.0),
			0.09,
			_materials["underframe"]
		)
	for branch_index in 3:
		var branch_z := [10.0, 25.0, 40.0][branch_index] as float + 1.15
		var branch_end_y := (-0.66 if branch_index < 2 else UPPER_DECK_ELEVATION - 0.66)
		_beam_between(
			service,
			"RungServiceConduit%02d" % (branch_index + 1),
			Vector3(2.0, -0.66, branch_z),
			Vector3(20.4, branch_end_y, branch_z),
			0.085,
			_materials["underframe"]
		)


## Live count of generated dock-service parts whose name starts with `prefix`.
## Counted off the built tree rather than from a constant so a roster entry can
## never keep claiming hardware a lifecycle change has removed.
func _count_service_nodes(prefix: String) -> int:
	if _build_root == null:
		return 0
	var service := _build_root.get_node_or_null(^"SurfaceDetail/DockArmService") as Node3D
	if service == null:
		return 0
	var total := 0
	for child in service.get_children():
		if str(child.name).begins_with(prefix):
			total += 1
	return total


## A dock-service visual with an explicit non-walkable reason attached.
##
## `reason` may be empty for a piece that lies flat on a slab the module already
## collides: those are deliberately left visible to
## `station_surface_playability_test.gd`'s discovery sweep so it can keep
## checking that there really is collision under them. Only pieces standing over
## the void carry the exclusion, and they carry it with the reason spelled out.
func _service_box(
		parent: Node3D,
		node_name: String,
		local_position: Vector3,
		size: Vector3,
		material: Material,
		reason: String
	) -> MeshInstance3D:
	var result := _visual_box(parent, node_name, local_position, size, material)
	if not reason.is_empty():
		result.set_meta("non_authoritative_visual", true)
		result.set_meta("non_walkable_reason", reason)
	return result


func _build_understructure() -> void:
	var underframe := Node3D.new()
	underframe.name = "VisualUnderframe"
	underframe.set_meta("visual_detail_only", true)
	_build_root.add_child(underframe)

	# COMB-UNDERFRAME-001. Every walkable surface here has its underside at
	# y = -0.60. The two 47 m trunk chords were centred on y = -0.85 with a 0.16 m
	# radius, so their crowns reached y = -0.69 and both beams hung 0.090 m clear
	# of the deck they are bolted to; the port one touched nothing at all in the
	# whole module. The three rung chords hung 0.040 m clear the same way. Each
	# beam is now centred so its crown enters the deck by 0.060 m (crown y = -0.540
	# against a deck underside of y = -0.600), which is the only change: radius,
	# endpoints in x/z and length are untouched.
	_beam_between(underframe, "TrunkChordPort", Vector3(-2.05, -0.70, 0.5), Vector3(-2.05, -0.70, 47.5), 0.16, _materials["underframe"])
	_beam_between(underframe, "TrunkChordStarboard", Vector3(2.05, -0.70, 0.5), Vector3(2.05, -0.70, 47.5), 0.16, _materials["underframe"])
	for rung_z in [10.0, 25.0, 40.0]:
		_beam_between(underframe, "RungUnderChord", Vector3(2.0, -0.72, float(rung_z)), Vector3(20.4, (-0.72 if rung_z < 40.0 else 1.68), float(rung_z)), 0.18, _materials["frame"])
	_slab_support_transforms.clear()
	for slab_spec in [[8.5, -1.75], [25.0, -1.75], [40.0, 0.65]]:
		var slab_z := float(slab_spec[0])
		var support_y := float(slab_spec[1])
		for support_x in [11.0, 19.0]:
			var support_anchor := _visual_box(
				underframe,
				"SlabSupport",
				Vector3(float(support_x), support_y, slab_z),
				Vector3(0.55, 2.5, 0.55),
				_materials["frame"]
			)
			_slab_support_transforms.append(support_anchor.transform)
			# Preserve every established named MeshInstance path as a transform,
			# material and inspection anchor; the batch owns their visible draw.
			support_anchor.visible = false
	_slab_support_batch = _multimesh_boxes(
		underframe,
		"SlabSupports",
		Vector3(0.55, 2.5, 0.55),
		_materials["frame"],
		_slab_support_transforms
	)


## Whether the dock slab at `index` currently carries an external ship assignment.
##
## Read off the marker registry `_index_semantics()` already builds, so the paint,
## the service hardware and the deck label cannot drift from the roster the module
## publishes. `_index_semantics()` runs before `_build_structure()`, so this is
## live by the time any builder asks.
func _dock_is_assigned(index: int) -> bool:
	if index < 0 or index >= DOCK_MARKER_IDS.size():
		return false
	var marker := _dock_markers.get(DOCK_MARKER_IDS[index]) as Marker3D
	if marker == null:
		return false
	return StringName(marker.get_meta("dock_status", &"")) == &"assigned_external"


func _build_deferred_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "DockLandmarks"
	landmarks.set_meta("non_authoritative_presentation", true)
	_build_root.add_child(landmarks)
	# Text and colour follow the dock registry for the same reason the paint and
	# the hardware do. Assigned modern designs use their stable names; no deferred
	# label remains after Dock 03's Bulwark promotion.
	var label_specs := [
		["ZENITH // B7 OBSERVED", Vector3(15.0, 0.18, 4.55), "DEFERRED DOCK 01"],
		["HALYARD // MODERN DESIGN", Vector3(15.0, 0.18, 19.55), "DEFERRED DOCK 02"],
		["BULWARK // MODERN DESIGN", Vector3(15.0, 2.58, 34.55), "DEFERRED DOCK 03"],
	]
	for index in label_specs.size():
		var label := Label3D.new()
		var assigned := _dock_is_assigned(index)
		if not assigned:
			label_specs[index][0] = label_specs[index][2]
		label.name = ("AssignedDockLabel%02d" if assigned else "DeferredDockLabel%02d") % (index + 1)
		label.text = str(label_specs[index][0])
		label.position = label_specs[index][1] as Vector3
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.font_size = 42
		label.pixel_size = 0.018
		label.modulate = Color("67e4e6") if assigned else Color("e36a60")
		label.outline_modulate = Color("0d2a2c") if assigned else Color("2a1112")
		label.outline_size = 8
		label.no_depth_test = false
		label.set_meta("assigned_dock_label", assigned)
		label.set_meta("deferred_dock_label", not assigned)
		landmarks.add_child(label)


func _register_surface(body: StaticBody3D, surface_id: StringName, surface_role: StringName) -> void:
	body.set_meta("fleet_comb_surface", true)
	body.set_meta("surface_id", surface_id)
	body.set_meta("surface_role", surface_role)
	body.set_meta("walkable_surface", true)
	_surface_nodes[surface_id] = body


func _surface_box(
		parent: Node3D,
		node_name: String,
		local_position: Vector3,
		size: Vector3,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	# Chamfered visual, unchanged box collider. The mesh keeps the requested outer
	# extent along every axis and the `BoxShape3D` below is still built from the
	# same exact `size`, so nothing published or walkable moves. As on every other
	# station deck built this way, the chamfer does soften the rendered top face
	# for the last few centimetres at the rim; that softening is the point, and
	# the deck's flat collision top is unaffected by it.
	mesh_instance.mesh = _rounded_box_mesh(size)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _visual_box(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.position = local_position
	result.mesh = _rounded_box_mesh(size)
	result.material_override = material
	result.set_meta("visual_detail_only", true)
	parent.add_child(result)
	return result


## Batches only repeated, childless, non-colliding surface detail. Transforms
## are authored in `parent` space; route, dock, surface and service nodes stay
## ordinary named nodes with their existing authority and lifecycle contracts.
func _multimesh_boxes(
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
	# Raw-buffer authored transforms do not rebuild the CPU AABB under headless,
	# so provide the exact transformed-mesh union explicitly for renderer culling.
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


## Box with softly chamfered edges, at this module's frozen bevel rule.
##
## The rule stays `clamp(shortest_side * 0.22, 0.003, 0.2)` and is *not* the
## kit's own `bevel_for_size`. It is proportional on purpose: a 0.03 m route
## stripe gets a 0.007 m chamfer while a 0.6 m dock slab gets 0.132 m, and any
## rule with a real minimum bevel eats the stripes. The kit's 0.012 m floor does
## exactly that — measured over every live chamfered box in this module it would
## move 5 of 13 distinct sizes by up to 0.0054 m, and on the 0.03 m stripes that
## is a 0.012 m chamfer from each side of a 0.03 m section. So the shared code is
## the builder, not the rule. The outer extent along each axis is preserved
## exactly, so `get_aabb()` still returns the requested size and no footprint,
## collider or published envelope moves.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.2),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.FACE_GRID
	)


func _beam_between(parent: Node3D, node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var direction := to - from
	var result := MeshInstance3D.new()
	result.name = node_name
	result.position = (from + to) * 0.5
	result.quaternion = Quaternion(Vector3.UP, direction.normalized())
	# Chamfered rims at the comb's frozen 16 radial segments; outer radius and
	# beam length are unchanged, so the beam still spans exactly `from`..`to`.
	result.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, direction.length(), 16, _chamfered_cylinder_cache
	)
	result.material_override = material
	result.set_meta("visual_detail_only", true)
	parent.add_child(result)
	return result


## A deck cue's spill, as an actual light.
##
## The comb's cues — status stripes, corner beacons, rung edge cues, trunk route
## lights — are emissive meshes lying flat on plate, and an emissive mesh
## illuminates nothing: `emission` is a local surface term and the glow pass
## convolves the finished image, so raising it only blooms the cue and leaves the
## deck under it at structure value. That is exactly the "glowing decal" reading.
## These are the smallest lights that fix it: shadowless, sub-8 m range, steep
## falloff, faded out at 26 m so the comb seen from across the lattice pays for
## none of them, and no process or physics loop is introduced.
func _dock_practical(
		parent: Node3D,
		node_name: String,
		light_position: Vector3,
		color: Color,
		energy: float,
		range_value: float
	) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = PRACTICAL_FADE_BEGIN
	light.distance_fade_length = PRACTICAL_FADE_LENGTH
	light.set_meta("fixture_practical", true)
	light.set_meta("visual_detail_only", true)
	parent.add_child(light)
	return light


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
	result.clearcoat_roughness = 0.45
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _apply_enabled_state() -> void:
	if _build_root == null:
		return
	# The authoritative surface map is passed in rather than a subtree scan: this
	# runs during `_ready()`, before the build root is guaranteed to be reachable
	# from a `find_children()` sweep of this node.
	var surfaces := _surface_nodes.values()
	StationModuleContract.apply_enabled_state(surfaces, WORLD_LAYER, _enabled, _build_root)
	for raw_surface in surfaces:
		var surface := raw_surface as StaticBody3D
		# Generated bodies would otherwise keep the default mask; the station
		# never queries outward from its own architecture.
		surface.collision_mask = 0


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", true)
	set_meta("authenticated_original_geometry", false)
	set_meta("owns_berth_authority", false)
	set_meta("dock_marker_count", DOCK_MARKER_COUNT)
	set_meta("assigned_dock_count", ASSIGNED_DOCK_COUNT)
	set_meta("deferred_dock_count", DEFERRED_DOCK_COUNT)
	set_meta("integration_footprint_min", FOOTPRINT_MIN)
	set_meta("integration_footprint_max", FOOTPRINT_MAX)
	set_meta("content_note", CONTENT_NOTE)
	add_to_group("station_modules")
	add_to_group("source_bounded_station_modules")


func _has_full_footprint_floor() -> bool:
	var footprint_size := FOOTPRINT_MAX - FOOTPRINT_MIN
	for raw_shape in find_children("*", "CollisionShape3D", true, false):
		var collision := raw_shape as CollisionShape3D
		var box := collision.shape as BoxShape3D
		if box != null and box.size.x >= footprint_size.x * 0.9 and box.size.z >= footprint_size.z * 0.9:
			return true
	return false


func _transform_aabb(local_aabb: AABB, transform: Transform3D) -> AABB:
	var first := true
	var result := AABB()
	for x_side in [0.0, 1.0]:
		for y_side in [0.0, 1.0]:
			for z_side in [0.0, 1.0]:
				var corner := local_aabb.position + Vector3(
					local_aabb.size.x * float(x_side),
					local_aabb.size.y * float(y_side),
					local_aabb.size.z * float(z_side)
				)
				var world_corner := transform * corner
				if first:
					result = AABB(world_corner, Vector3.ZERO)
					first = false
				else:
					result = result.expand(world_corner)
	return result
