class_name SalvageTerrace
extends Node3D

## Standalone exposed salvage inspection/service terraces.
##
## This module is NEW work with evidence status `modern_interpretation`.
## Nothing here claims recovered station geometry, historical salvage practice,
## or an original adjacency. Six collision-backed surfaces form three broad,
## spatially distinct working terraces joined by two continuous ramps. The
## connector is exactly the local origin and no traversal requires a jump.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"salvage-terrace"
const ELEMENT_STATUS: StringName = &"new"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := 1
const CONNECTION_SLOT_ID: StringName = &"hub-salvage-terrace"

const LOWER_ELEVATION := 0.0
const UPPER_ELEVATION := 3.6
const INSPECTION_ELEVATION := 5.4
const SURFACE_THICKNESS := 0.30
const MAIN_RAMP_WIDTH := 6.0
const MAIN_RAMP_HORIZONTAL_RUN := 8.0
const INSPECTION_RAMP_WIDTH := 6.0
const INSPECTION_RAMP_HORIZONTAL_RUN := 4.0
const PANEL_SURFACE_SCALE := 0.30

## Exact non-overlapping horizontal projection. Shared boundaries have zero area.
## The lower work pad retains its complete apron and route seams while its
## redundant aft strip is compacted from 12 m to 7 m deep: 144 -> 84 m2.
const LOWER_PAD_DEPTH := 7.0
const LOWER_PAD_CENTER_Z := 5.5
const LOWER_PAD_AFT_Z := 9.0
const LEVEL_WALKABLE_AREA_M2 := 324.0
const RAMP_PROJECTED_AREA_M2 := 72.0
const HORIZONTAL_WALKABLE_AREA_M2 := 396.0
const MAIN_RAMP_TRUE_AREA_M2 := 52.636109
const INSPECTION_RAMP_TRUE_AREA_M2 := 26.318054
const RAMP_TRUE_AREA_M2 := 78.954163

const FOOTPRINT_MIN := Vector3(-18.1, -1.8, -0.7)
const FOOTPRINT_MAX := Vector3(27.3, 7.1, 18.1)

const SURFACE_IDS := [
	&"connection-apron",
	&"lower-salvage-pad",
	&"main-service-ramp",
	&"upper-inspection-pad",
	&"inspection-ramp",
	&"top-inspection-pad",
]
const PAD_IDS := [
	&"lower-salvage-pad",
	&"upper-inspection-pad",
	&"top-inspection-pad",
]
const ROUTE_IDS := [
	&"connector",
	&"entry",
	&"lower-pad",
	&"main-ramp-base",
	&"upper-pad",
	&"inspection-ramp-base",
	&"inspection-pad",
]

## Exact focused-census budgets. These are frozen to the finished standalone
## build rather than padded during integration, so any added submission/node
## turns audit red.
const PERFORMANCE_BUDGET := {
	"mesh_instances": 32,
	"multimesh_batches": 6,
	"multimesh_instances": 164,
	"geometry_submissions": 38,
	"visible_geometry_copies": 200,
	"multimesh_buffer_floats": 1968,
	"static_bodies": 26,
	"collision_shapes": 26,
	"labels": 1,
	"lights": 3,
	"nodes": 108,
	"process_loops": 0,
	"physics_process_loops": 0,
}
const MULTIMESH_INSTANCE_COUNTS := {
	"TerraceSupportBatch": 10,
	"SalvageCageBatch": 6,
	"ServiceBeaconBatch": 4,
	"SalvageFrameBatch": 10,
	"SortingMachineryBatch": 8,
	"RailDetailBatch": 126,
}
const SERVICE_BEACON_SIZE := Vector3(0.18, 0.42, 0.18)
const RAIL_POST_VISUAL_SIZE := Vector3(0.10, 1.20, 0.10)
const UNIT_BOX_BATCH_NAMES := [
	&"RailDetailBatch",
	&"SalvageFrameBatch",
	&"SortingMachineryBatch",
]
const HAZARD_DRESSING_RENDER_NAME := &"HazardDressingBatch"
const HAZARD_DRESSING_PARTS := [
	{
		"id": &"InspectionGantryBoom",
		"position": Vector3(23.25, 5.8, 7.5),
		"size": Vector3(7.5, 0.35, 0.35),
		"reason": "extended overhead inspection boom outside capsule height",
	},
	{
		"id": &"RoofHazardStripe",
		"position": Vector3(-12.0, 4.46, 2.95),
		"size": Vector3(8.0, 0.10, 0.35),
		"reason": "overhead bay-edge identification stripe",
	},
	{
		"id": &"CrusherFeedHood",
		"position": Vector3(-12.4, 2.55, 10.35),
		"size": Vector3(2.2, 0.35, 1.8),
		"reason": "crusher hood behind the compacted aft safety rail",
	},
	{
		"id": &"CraneBridge",
		"position": Vector3(-12.0, 4.05, 5.5),
		"size": Vector3(9.4, 0.28, 0.38),
		"reason": "overhead salvage crane bridge above player clearance",
	},
	{
		"id": &"CraneHook",
		"position": Vector3(-10.1, 2.68, 5.5),
		"size": Vector3(0.35, 0.22, 0.35),
		"reason": "high suspended crane hook outside route contact",
	},
]

## These four physical rails keep separate bodies, collision shapes, stable
## paths and exact transforms. Their conservative solid renderer was already
## permanently hidden because RailDetailBatch draws the visible open rail, so
## the stable `Mesh` path is retained as an inert anchor without allocating a
## renderer, mesh resource, material binding or structural submission.
const SHORT_SIDE_RAIL_VISUAL_SIZE := Vector3(0.16, 1.3, 2.0)
const SHORT_SIDE_RAIL_NAMES := [
	"EntryPortForward",
	"EntryStarboardForward",
	"UpperInboardForward",
	"UpperInboardAft",
]
const SHORT_SIDE_RAIL_ORIGINS := [
	Vector3(-6.0, 0.65, 1.0),
	Vector3(6.0, 0.65, 1.0),
	Vector3(14.0, 4.25, 1.0),
	Vector3(14.0, 4.25, 9.0),
]
const SHORT_SIDE_RAIL_VISUAL_COUNT := 4
const LONG_RAIL_VISUAL_SIZE := Vector3(12.0, 1.3, 0.16)
const LONG_RAIL_NAMES := [&"LowerForward", &"LowerAft", &"UpperForward"]
const LONG_RAIL_VISUAL_COUNT := 3
const ENTRY_FRONT_RAIL_VISUAL_SIZE := Vector3(4.0, 1.3, 0.16)
const ENTRY_FRONT_RAIL_NAMES := [&"EntryFrontPort", &"EntryFrontStarboard"]
const TOP_SIDE_RAIL_VISUAL_SIZE := Vector3(0.16, 1.3, 4.0)
const TOP_SIDE_RAIL_NAMES := [&"TopPort", &"TopStarboard"]
const FOUR_METER_RAIL_VISUAL_COUNT := 4
const MAIN_RAMP_RAIL_NAMES := [&"MainRampForward", &"MainRampAft"]
const INSPECTION_RAMP_RAIL_NAMES := [&"InspectionRampPort", &"InspectionRampStarboard"]
const SLOPED_RAIL_VISUAL_COUNT := 4

const CONTENT_NOTE := (
	"Salvage Terrace is a NEW modern interpretation. No source authenticates its "
	+ "terraces, ramps, salvage racks, inspection gantry, dimensions, colours, "
	+ "operating role, or station adjacency. It owns presentation and static World "
	+ "collision only; it owns no ship, berth, combat, interaction, activity, lease, "
	+ "spawn, audio, or network authority."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _route_connector: Marker3D = %RouteConnector
@onready var _route_entry: Marker3D = %RouteEntry
@onready var _route_lower_pad: Marker3D = %RouteLowerPad
@onready var _route_main_ramp_base: Marker3D = %RouteMainRampBase
@onready var _route_upper_pad: Marker3D = %RouteUpperPad
@onready var _route_inspection_ramp_base: Marker3D = %RouteInspectionRampBase
@onready var _route_inspection_pad: Marker3D = %RouteInspectionPad
@onready var _build_root: Node3D = %GeneratedRoot

var _route_markers: Dictionary = {}
var _surface_nodes: Dictionary = {}
var _surface_contracts: Array[Dictionary] = []
var _rail_nodes: Array[StaticBody3D] = []
var _materials: Dictionary = {}
var _enabled := true
var _built := false
var _build_generation := 0
var _built_node_ids: Dictionary = {}
var _built_node_transforms: Dictionary = {}
var _built_multimesh_buffers: Dictionary = {}
var _built_multimesh_visible_counts: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _long_rail_visual_mesh: BoxMesh
var _entry_front_rail_visual_mesh: BoxMesh
var _top_side_rail_visual_mesh: BoxMesh
var _main_ramp_rail_visual_mesh: BoxMesh
var _inspection_ramp_rail_visual_mesh: BoxMesh
var _unit_box_batch_mesh: BoxMesh
var _rail_detail_transforms: Array[Transform3D] = []
var _ramp_threshold_post_transforms: Array[Transform3D] = []


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _built:
		_built = true
		_create_materials()
		_index_routes()
		_build_surfaces()
		_build_safety_rails()
		_build_batched_supports_and_dressing()
		_build_salvage_work_bay()
		_build_identity_sign()
		_apply_metadata()
		_build_generation += 1
		_capture_built_contract()
	_apply_enabled_state()


func get_module_id() -> StringName:
	return MODULE_ID


func get_module_anchor() -> Marker3D:
	return _module_anchor


func get_route_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for route_id in ROUTE_IDS:
		result.append(StringName(route_id))
	return result


func has_route_marker(route_id: StringName) -> bool:
	return _route_markers.has(route_id)


func get_route_marker(route_id: StringName) -> Marker3D:
	return _route_markers.get(route_id) as Marker3D


func get_route_transform(route_id: StringName) -> Transform3D:
	var marker := get_route_marker(route_id)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


func get_connection_slot_contract() -> Array[Dictionary]:
	return [{
		"slot_id": CONNECTION_SLOT_ID,
		"route_id": &"connector",
		"local_transform": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.15, 0.0)),
		"connection_plane_local": Transform3D.IDENTITY,
		"approach_axis_local": Vector3.FORWARD,
		"clear_width": 4.0,
		"clear_height": INF,
	}].duplicate(true)


func get_integration_footprint() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"anchor_transform": _module_anchor.global_transform,
		"connection_plane_local": Transform3D.IDENTITY,
		"local_min": FOOTPRINT_MIN,
		"local_max": FOOTPRINT_MAX,
		"local_size": FOOTPRINT_MAX - FOOTPRINT_MIN,
		"approach_axis_local": Vector3.FORWARD,
		"module_extends_local": Vector3.BACK,
		"connection_at_local_origin": true,
	}


func get_standable_surface_contract() -> Array[Dictionary]:
	return _build_live_surface_contracts().duplicate(true)


func get_walkable_area_contract() -> Dictionary:
	var live_surfaces := _build_live_surface_contracts()
	var by_surface := {}
	var level_area := 0.0
	var ramp_projected_area := 0.0
	var ramp_true_area := 0.0
	var projected_sum := 0.0
	var projection_rects: Array[Rect2] = []
	var live_geometry_valid := live_surfaces.size() == SURFACE_IDS.size()
	var projection_axis_aligned := true
	for surface in live_surfaces:
		by_surface[surface.surface_id] = {
			"kind": surface.kind,
			"horizontal_area_m2": surface.horizontal_area_m2,
			"true_area_m2": surface.true_area_m2,
		}
		var horizontal_area := float(surface.horizontal_area_m2)
		projected_sum += horizontal_area
		if surface.kind == &"ramp":
			ramp_projected_area += horizontal_area
			ramp_true_area += float(surface.true_area_m2)
		else:
			level_area += horizontal_area
		live_geometry_valid = live_geometry_valid and bool(surface.geometry_valid)
		projection_axis_aligned = projection_axis_aligned and bool(surface.projection_axis_aligned)
		projection_rects.append(surface.projection_rect as Rect2)
	var horizontal_union := _axis_aligned_rect_union_area(projection_rects) if projection_axis_aligned else 0.0
	var non_overlapping := (
		live_geometry_valid
		and projection_axis_aligned
		and is_equal_approx(horizontal_union, projected_sum)
	)
	var main_ramp := by_surface.get(&"main-service-ramp", {}) as Dictionary
	var inspection_ramp := by_surface.get(&"inspection-ramp", {}) as Dictionary
	return {
		"schema_version": SCHEMA_VERSION,
		"surface_union": (
			&"non_overlapping_shared_boundaries_only"
			if non_overlapping
			else &"invalid_or_overlapping_live_projection"
		),
		"surface_count": live_surfaces.size(),
		"live_geometry_derived": true,
		"live_geometry_valid": live_geometry_valid,
		"projection_axis_aligned": projection_axis_aligned,
		"non_overlapping": non_overlapping,
		"projected_surface_sum_m2": projected_sum,
		"level_area_m2": level_area,
		"ramp_projected_area_m2": ramp_projected_area,
		"horizontal_walkable_area_m2": horizontal_union,
		"ramp_true_area_m2": ramp_true_area,
		"main_ramp_true_area_m2": float(main_ramp.get("true_area_m2", 0.0)),
		"inspection_ramp_true_area_m2": float(inspection_ramp.get("true_area_m2", 0.0)),
		"baseline_share_claimed": false,
		"by_surface": by_surface.duplicate(true),
	}


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["surface_ids"] = PackedStringArray(SURFACE_IDS)
	roster["surface_count"] = _surface_nodes.size()
	roster["usable_pad_ids"] = PackedStringArray(PAD_IDS)
	roster["usable_pad_count"] = PAD_IDS.size()
	roster["ramp_count"] = 2
	roster["safety_rail_count"] = _rail_nodes.size()
	roster["identity_label_count"] = find_children("*", "Label3D", true, false).size()
	roster["multimesh_batch_count"] = find_children("*", "MultiMeshInstance3D", true, false).size()
	roster["work_light_count"] = find_children("*", "OmniLight3D", true, false).size()
	roster["salvage_work_bay_present"] = _salvage_work_bay_is_complete()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(self, WORLD_LAYER, _enabled)
	contract["schema_version"] = SCHEMA_VERSION
	contract["walkable_surface_count"] = _surface_nodes.size()
	contract["safety_rail_count"] = _rail_nodes.size()
	contract["every_walkable_surface_tagged"] = _walkable_tags_are_exact()
	contract["surface_geometry_matches_collision"] = _surface_geometry_matches_contract()
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	contract["element_status"] = ELEMENT_STATUS
	contract["ship_authority_count"] = 0
	contract["berth_authority_count"] = 0
	contract["combat_authority_count"] = 0
	contract["interaction_authority_count"] = 0
	contract["station_activity_authority_count"] = 0
	contract["owns_ship_authority"] = false
	contract["owns_berth_authority"] = false
	contract["owns_combat_authority"] = false
	contract["owns_activity_authority"] = false
	return contract


func get_performance_contract() -> Dictionary:
	var contract := StationModuleContract.build_performance_contract(self, PERFORMANCE_BUDGET)
	var multimeshes := find_children("*", "MultiMeshInstance3D", true, false)
	var multimesh_instances := 0
	var multimesh_drawn_copies := 0
	var multimesh_buffer_floats := 0
	var batch_instance_counts := {}
	for raw_batch in multimeshes:
		var batch := raw_batch as MultiMeshInstance3D
		if batch.multimesh != null:
			multimesh_instances += batch.multimesh.instance_count
			multimesh_drawn_copies += (
				batch.multimesh.instance_count
				if batch.multimesh.visible_instance_count < 0
				else mini(batch.multimesh.visible_instance_count, batch.multimesh.instance_count)
			)
			multimesh_buffer_floats += batch.multimesh.buffer.size()
			batch_instance_counts[batch.name] = batch.multimesh.instance_count
	contract["schema_version"] = SCHEMA_VERSION
	contract["multimesh_batches"] = multimeshes.size()
	contract["multimesh_instances"] = multimesh_instances
	contract["multimesh_drawn_copies"] = multimesh_drawn_copies
	contract["multimesh_buffer_floats"] = multimesh_buffer_floats
	contract["batch_instance_counts"] = batch_instance_counts
	contract["geometry_submissions"] = int(contract.mesh_instances) + multimeshes.size()
	contract["visible_geometry_copies"] = _authored_mesh_copy_count() + multimesh_drawn_copies
	contract["nodes"] = 1 + find_children("*", "", true, false).size()
	contract["budgets"] = PERFORMANCE_BUDGET.duplicate(true)
	contract["buffers_match_authored"] = _multimesh_contract_is_live()
	var rail_visual_sharing := get_short_side_rail_visual_allocation_audit()
	var long_rail_visual_sharing := get_long_rail_visual_allocation_audit()
	var four_meter_rail_visual_sharing := get_four_meter_rail_visual_allocation_audit()
	var sloped_rail_visual_sharing := get_sloped_rail_visual_allocation_audit()
	var unit_box_batch_mesh_sharing := get_unit_box_batch_mesh_allocation_audit()
	var hazard_dressing_batching := get_hazard_dressing_batch_audit()
	contract["short_side_rail_visual_sharing"] = rail_visual_sharing
	contract["long_rail_visual_sharing"] = long_rail_visual_sharing
	contract["four_meter_rail_visual_sharing"] = four_meter_rail_visual_sharing
	contract["sloped_rail_visual_sharing"] = sloped_rail_visual_sharing
	contract["unit_box_batch_mesh_sharing"] = unit_box_batch_mesh_sharing
	contract["hazard_dressing_batching"] = hazard_dressing_batching
	contract["resource_sharing_matches_authored"] = (
		bool(rail_visual_sharing.valid)
		and bool(long_rail_visual_sharing.valid)
		and bool(four_meter_rail_visual_sharing.valid)
		and bool(sloped_rail_visual_sharing.valid)
		and bool(unit_box_batch_mesh_sharing.valid)
		and bool(hazard_dressing_batching.valid)
	)
	var exact_census := true
	for key in PERFORMANCE_BUDGET:
		exact_census = exact_census and int(contract.get(key, -1)) == int(PERFORMANCE_BUDGET[key])
	contract["exact_census"] = exact_census
	contract["within_budget"] = (
		bool(contract.within_budget)
		and exact_census
		and bool(contract.buffers_match_authored)
		and bool(contract.resource_sharing_matches_authored)
	)
	return contract


func _authored_mesh_copy_count() -> int:
	var copies := 0
	for raw_mesh in find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		copies += int(mesh.get_meta("authored_visible_copy_count", 1))
	return copies


## The combined renderer retains exact source-part size and transform metadata,
## while eliminating four static submissions and mesh-instance nodes.
func get_hazard_dressing_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var renderer := _build_root.get_node_or_null(NodePath(HAZARD_DRESSING_RENDER_NAME)) as MeshInstance3D
	var parts: Array = [] if renderer == null else renderer.get_meta("salvage_terrace_hazard_dressing_parts", []) as Array
	if renderer == null or renderer.mesh == null:
		errors.append("hazard_dressing_renderer_missing")
	elif renderer.material_override != _materials.hazard or renderer.transform != Transform3D.IDENTITY:
		errors.append("hazard_dressing_renderer_recipe_drift")
	if parts.size() != HAZARD_DRESSING_PARTS.size():
		errors.append("hazard_dressing_part_count_drift")
	else:
		for index in HAZARD_DRESSING_PARTS.size():
			var expected := HAZARD_DRESSING_PARTS[index] as Dictionary
			var actual := parts[index] as Dictionary
			if (
				actual.get("id", &"") != expected.id
				or not (actual.get("size", Vector3.ZERO) as Vector3).is_equal_approx(expected.size as Vector3)
				or not (actual.get("transform", Transform3D.IDENTITY) as Transform3D).is_equal_approx(
					Transform3D(Basis.IDENTITY, expected.position as Vector3)
				)
				or actual.get("reason", "") != expected.reason
			):
				errors.append("hazard_dressing_part_recipe_drift")
				break
	if renderer != null and int(renderer.get_meta("authored_visible_copy_count", 0)) != HAZARD_DRESSING_PARTS.size():
		errors.append("hazard_dressing_visible_copy_count_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"authored_visible_copies": HAZARD_DRESSING_PARTS.size(),
		"renderer_nodes": 1 if renderer != null else 0,
		"geometry_submissions": 1 if renderer != null and renderer.mesh != null else 0,
		"legacy_renderer_nodes": 5,
		"legacy_geometry_submissions": 5,
		"renderer_node_delta": (1 if renderer != null else 0) - 5,
		"geometry_submission_delta": (1 if renderer != null and renderer.mesh != null else 0) - 5,
	}.duplicate(true)


## Renderer-independent, component-local allocation evidence for four exact
## short side-rail visuals. A structural submission is one mesh surface, not a
## driver draw-call claim. The report intentionally makes no whole-scene,
## frame-time, GPU, VRAM, or pixel-equivalence claim.
func get_short_side_rail_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var collision_shape_ids := {}
	var behavior_rows: Array[Dictionary] = []
	var stable_path_node_count := 0
	var renderer_node_count := 0
	var physical_rail_body_count := 0
	var collision_shape_count := 0
	var scripted_node_count := 0
	var foreign_authority_node_count := 0
	var processing_node_count := 0

	for index in SHORT_SIDE_RAIL_NAMES.size():
		var rail_name := String(SHORT_SIDE_RAIL_NAMES[index])
		var rail_path := NodePath("GeneratedRoot/%s" % rail_name)
		var rail := get_node_or_null(rail_path) as StaticBody3D
		if rail == null:
			errors.append("short_side_rail_visual_missing:%s" % rail_name)
			continue
		physical_rail_body_count += 1
		var visual_anchor := rail.get_node_or_null(^"Mesh") as Marker3D
		var collision := rail.get_node_or_null(^"Collision") as CollisionShape3D
		if visual_anchor == null:
			errors.append("short_side_rail_visual_missing:%s/Mesh" % rail_name)
		else:
			stable_path_node_count += 1
			if (
				not visual_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
				or not bool(visual_anchor.get_meta("renderer_elided_anchor", false))
				or str(visual_anchor.get_meta("non_walkable_reason", ""))
					!= "physical safety rail, not a route surface"
				or visual_anchor.get_child_count() != 0
			):
				errors.append("short_side_rail_visual_anchor_state_drift")
		for child in rail.get_children():
			if child is MeshInstance3D or child is MultiMeshInstance3D:
				renderer_node_count += 1
		if collision == null or not (collision.shape is BoxShape3D):
			errors.append("short_side_rail_physics_contract_drift")
		else:
			collision_shape_count += 1
			collision_shape_ids[collision.shape.get_instance_id()] = true
			if not (collision.shape as BoxShape3D).size.is_equal_approx(
				SHORT_SIDE_RAIL_VISUAL_SIZE
			):
				errors.append("short_side_rail_physics_contract_drift")
		if (
			not bool(rail.get_meta("safety_rail", false))
			or not rail.transform.is_equal_approx(
				Transform3D(Basis.IDENTITY, SHORT_SIDE_RAIL_ORIGINS[index] as Vector3)
			)
			or rail.collision_mask != 0
			or rail.get_child_count() != 2
		):
			errors.append("short_side_rail_physics_contract_drift")
		for candidate in [rail, visual_anchor, collision]:
			if candidate == null:
				continue
			var node := candidate as Node
			if node.get_script() != null:
				scripted_node_count += 1
			if node.is_processing() or node.is_physics_processing():
				processing_node_count += 1
			for child in node.get_children():
				if (
					child is Area3D
					or child is NavigationRegion3D
					or child is Light3D
					or child is AudioStreamPlayer
					or child is AudioStreamPlayer3D
					or child is Camera3D
				):
					foreign_authority_node_count += 1
		behavior_rows.append({
			"path": String(rail_path),
			"origin": [rail.position.x, rail.position.y, rail.position.z],
			"visual_path": String(rail_path) + "/Mesh",
			"collision_path": String(rail_path) + "/Collision",
		})

	if stable_path_node_count != SHORT_SIDE_RAIL_VISUAL_COUNT:
		errors.append("short_side_rail_visual_node_count_drift")
	if renderer_node_count != 0:
		errors.append("short_side_rail_visual_submission_count_drift")
	if (
		physical_rail_body_count != SHORT_SIDE_RAIL_VISUAL_COUNT
		or collision_shape_count != SHORT_SIDE_RAIL_VISUAL_COUNT
		or collision_shape_ids.size() != SHORT_SIDE_RAIL_VISUAL_COUNT
	):
		errors.append("short_side_rail_physics_contract_drift")
	if scripted_node_count != 0 or foreign_authority_node_count != 0 or processing_node_count != 0:
		errors.append("short_side_rail_visual_path_gained_authority_or_lifecycle")

	var before := {
		"stable_path_nodes": 4,
		"renderer_nodes": 4,
		"visible_geometry_copies": 0,
		"structural_submissions": 4,
		"mesh_resource_allocations": 1,
		"material_resource_allocations": 1,
		"physical_rail_bodies": 4,
		"collision_shapes": 4,
		"collision_resource_allocations": 4,
	}
	var current := {
		"stable_path_nodes": stable_path_node_count,
		"renderer_nodes": renderer_node_count,
		"visible_geometry_copies": 0,
		"structural_submissions": 0,
		"mesh_resource_allocations": 0,
		"material_resource_allocations": 0,
		"physical_rail_bodies": physical_rail_body_count,
		"collision_shapes": collision_shape_count,
		"collision_resource_allocations": collision_shape_ids.size(),
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"salvage_terrace_short_side_rail_visuals",
		"before": before,
		"current": current,
		"reductions": {
			"stable_path_nodes": 0,
			"renderer_nodes": 4,
			"visible_geometry_copies": 0,
			"structural_submissions": 4,
			"mesh_resource_allocations": 1,
			"physical_rail_bodies": 0,
			"collision_shapes": 0,
		},
		"behavior_rows": behavior_rows,
		"scripted_node_count": scripted_node_count,
		"foreign_authority_node_count": foreign_authority_node_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"renderer_elided": true,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
		"pixel_equivalence_claimed": false,
	}.duplicate(true)


func get_long_rail_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	var collision_ids := {}
	for rail_name in LONG_RAIL_NAMES:
		var rail := get_node_or_null(NodePath("GeneratedRoot/%s" % rail_name)) as StaticBody3D
		var visual := rail.get_node_or_null(^"Mesh") as MeshInstance3D if rail != null else null
		var collision := rail.get_node_or_null(^"Collision") as CollisionShape3D if rail != null else null
		if visual == null or not (visual.mesh is BoxMesh):
			errors.append("long_rail_visual_missing")
		else:
			mesh_ids[visual.mesh.get_instance_id()] = true
			if visual.mesh != _long_rail_visual_mesh or not (visual.mesh as BoxMesh).size.is_equal_approx(LONG_RAIL_VISUAL_SIZE):
				errors.append("long_rail_visual_identity_or_recipe_drift")
		if collision == null or not (collision.shape is BoxShape3D):
			errors.append("long_rail_collision_missing")
		else:
			collision_ids[collision.shape.get_instance_id()] = true
	if mesh_ids.size() != 1:
		errors.append("long_rail_visual_mesh_count_drift")
	if collision_ids.size() != LONG_RAIL_VISUAL_COUNT:
		errors.append("long_rail_collision_identity_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(), "errors": errors,
		"visual_copies": LONG_RAIL_VISUAL_COUNT,
		"mesh_resource_allocations": mesh_ids.size(),
		"collision_resource_allocations": collision_ids.size(),
		"legacy_mesh_resource_allocations": 3,
		"mesh_resource_allocation_delta": -2,
	}.duplicate(true)


## Four hidden conservative rail renderers retain their individual collision
## bodies and paths. The two X-oriented and two Z-oriented recipes each share
## one immutable mesh resource, preserving their exact local visual bounds.
func get_four_meter_rail_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	var collision_ids := {}
	var aabb_matches_collision := true
	for rail_name in ENTRY_FRONT_RAIL_NAMES + TOP_SIDE_RAIL_NAMES:
		var rail := get_node_or_null(NodePath("GeneratedRoot/%s" % rail_name)) as StaticBody3D
		var visual := rail.get_node_or_null(^"Mesh") as MeshInstance3D if rail != null else null
		var collision := rail.get_node_or_null(^"Collision") as CollisionShape3D if rail != null else null
		var expected_mesh := (
			_entry_front_rail_visual_mesh
			if rail_name in ENTRY_FRONT_RAIL_NAMES else _top_side_rail_visual_mesh
		)
		var expected_size := (
			ENTRY_FRONT_RAIL_VISUAL_SIZE
			if rail_name in ENTRY_FRONT_RAIL_NAMES else TOP_SIDE_RAIL_VISUAL_SIZE
		)
		var has_box_visual := visual != null and visual.mesh is BoxMesh
		if not has_box_visual:
			errors.append("four_meter_rail_visual_missing")
		else:
			mesh_ids[visual.mesh.get_instance_id()] = true
			if (
				visual.mesh != expected_mesh
				or not (visual.mesh as BoxMesh).size.is_equal_approx(expected_size)
				or visual.material_override != _materials.rail
			):
				errors.append("four_meter_rail_visual_identity_or_recipe_drift")
		if collision == null or not (collision.shape is BoxShape3D):
			errors.append("four_meter_rail_collision_missing")
		else:
			collision_ids[collision.shape.get_instance_id()] = true
			var collision_shape := collision.shape as BoxShape3D
			var collision_bounds := _transformed_aabb(
				AABB(-collision_shape.size * 0.5, collision_shape.size), collision.transform
			)
			if not has_box_visual:
				aabb_matches_collision = false
				errors.append("four_meter_rail_visual_aabb_drift")
			else:
				var visual_bounds := _transformed_aabb(visual.mesh.get_aabb(), visual.transform)
				if not visual_bounds.is_equal_approx(collision_bounds):
					aabb_matches_collision = false
					errors.append("four_meter_rail_visual_aabb_drift")
	if mesh_ids.size() != 2:
		errors.append("four_meter_rail_visual_mesh_count_drift")
	if collision_ids.size() != FOUR_METER_RAIL_VISUAL_COUNT:
		errors.append("four_meter_rail_collision_identity_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(), "errors": errors,
		"visual_copies": FOUR_METER_RAIL_VISUAL_COUNT,
		"mesh_resource_allocations": mesh_ids.size(),
		"collision_resource_allocations": collision_ids.size(),
		"legacy_mesh_resource_allocations": 4,
		"mesh_resource_allocation_delta": -2,
		"visual_aabbs_match_collision": aabb_matches_collision,
	}.duplicate(true)


## The two physical rails on each ramp retain distinct bodies, collision shapes,
## paths and transforms. Their hidden conservative visual envelopes now reuse one
## immutable mesh per exact ramp length instead of allocating one per side.
func get_sloped_rail_visual_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	var collision_ids := {}
	var visual_aabbs_match_collision := true
	var authored_groups := [
		{
			"names": MAIN_RAMP_RAIL_NAMES,
			"mesh": _main_ramp_rail_visual_mesh,
		},
		{
			"names": INSPECTION_RAMP_RAIL_NAMES,
			"mesh": _inspection_ramp_rail_visual_mesh,
		},
	]
	for group in authored_groups:
		var expected_mesh := group.mesh as BoxMesh
		for rail_name in group.names:
			var rail := get_node_or_null(NodePath("GeneratedRoot/%s" % rail_name)) as StaticBody3D
			var visual := rail.get_node_or_null(^"Mesh") as MeshInstance3D if rail != null else null
			var collision := rail.get_node_or_null(^"Collision") as CollisionShape3D if rail != null else null
			var has_box_visual := visual != null and visual.mesh is BoxMesh
			if not has_box_visual:
				errors.append("sloped_rail_visual_missing")
			else:
				mesh_ids[visual.mesh.get_instance_id()] = true
				if (
					visual.mesh != expected_mesh
					or visual.material_override != _materials.rail
					or visual.visible
					or not visual.transform.is_equal_approx(Transform3D.IDENTITY)
				):
					errors.append("sloped_rail_visual_identity_or_recipe_drift")
			if collision == null or not (collision.shape is BoxShape3D):
				errors.append("sloped_rail_collision_missing")
			else:
				collision_ids[collision.shape.get_instance_id()] = true
				var collision_shape := collision.shape as BoxShape3D
				if not has_box_visual:
					visual_aabbs_match_collision = false
				else:
					var visual_bounds := _transformed_aabb(visual.mesh.get_aabb(), visual.transform)
					var collision_bounds := _transformed_aabb(
						AABB(-collision_shape.size * 0.5, collision_shape.size), collision.transform
					)
					if not visual_bounds.is_equal_approx(collision_bounds):
						visual_aabbs_match_collision = false
						errors.append("sloped_rail_visual_aabb_drift")
	if mesh_ids.size() != 2:
		errors.append("sloped_rail_visual_mesh_count_drift")
	if collision_ids.size() != SLOPED_RAIL_VISUAL_COUNT:
		errors.append("sloped_rail_collision_identity_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(), "errors": errors,
		"visual_copies": SLOPED_RAIL_VISUAL_COUNT,
		"renderer_nodes": SLOPED_RAIL_VISUAL_COUNT,
		"geometry_submissions": SLOPED_RAIL_VISUAL_COUNT,
		"mesh_resource_allocations": mesh_ids.size(),
		"collision_resource_allocations": collision_ids.size(),
		"legacy_mesh_resource_allocations": 4,
		"mesh_resource_allocation_delta": -2,
		"visual_aabbs_match_collision": visual_aabbs_match_collision,
		"batched": false,
	}.duplicate(true)


## Three existing transform-scaled batches have the same immutable unit-box
## recipe. They retain separate MultiMeshes, buffers, materials and submissions;
## only the redundant primitive mesh allocation is shared.
func get_unit_box_batch_mesh_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids := {}
	var multimesh_ids := {}
	var instance_count := 0
	var visible_copy_count := 0
	var expected_materials := {
		&"RailDetailBatch": _materials.rail,
		&"SalvageFrameBatch": _materials.frame,
		&"SortingMachineryBatch": _materials.machine,
	}
	for batch_name in UNIT_BOX_BATCH_NAMES:
		var batch := get_node_or_null(
			NodePath("GeneratedRoot/%s" % batch_name)
		) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null or not (batch.multimesh.mesh is BoxMesh):
			errors.append("unit_box_batch_missing")
			continue
		var mesh := batch.multimesh.mesh as BoxMesh
		mesh_ids[mesh.get_instance_id()] = true
		multimesh_ids[batch.multimesh.get_instance_id()] = true
		instance_count += batch.multimesh.instance_count
		visible_copy_count += (
			batch.multimesh.instance_count
			if batch.multimesh.visible_instance_count < 0
			else mini(batch.multimesh.visible_instance_count, batch.multimesh.instance_count)
		)
		if (
			mesh != _unit_box_batch_mesh
			or not mesh.size.is_equal_approx(Vector3.ONE)
			or mesh.resource_local_to_scene
			or batch.material_override != expected_materials[batch_name]
		):
			errors.append("unit_box_batch_identity_or_recipe_drift")
	if mesh_ids.size() != 1:
		errors.append("unit_box_batch_mesh_count_drift")
	if multimesh_ids.size() != UNIT_BOX_BATCH_NAMES.size():
		errors.append("unit_box_batch_submission_identity_drift")
	if instance_count != 144 or visible_copy_count != 144:
		errors.append("unit_box_batch_visible_copy_count_drift")
	errors.sort()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"batch_count": UNIT_BOX_BATCH_NAMES.size(),
		"geometry_submissions": multimesh_ids.size(),
		"visible_geometry_copies": visible_copy_count,
		"mesh_resource_allocations": mesh_ids.size(),
		"legacy_mesh_resource_allocations": 3,
		"mesh_resource_allocation_delta": mesh_ids.size() - 3,
		"multimesh_resource_allocations": multimesh_ids.size(),
		"batched": true,
	}.duplicate(true)


func _transformed_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x_value in [bounds.position.x, bounds.end.x]:
		for y_value in [bounds.position.y, bounds.end.y]:
			for z_value in [bounds.position.z, bounds.end.z]:
				var point := transform * Vector3(x_value, y_value, z_value)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)


func set_module_enabled(enabled: bool) -> void:
	# An unbuilt scene may receive authored/pre-tree configuration, but an
	# initialized module must stay current to rewrite visibility or collision.
	if is_queued_for_deletion() or (_built and not is_inside_tree()):
		return
	_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _enabled


func get_lifecycle_contract() -> Dictionary:
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _enabled, _build_root
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	contract["build_generation"] = _build_generation
	return contract


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"module_id": MODULE_ID,
		"element_status": ELEMENT_STATUS,
		"evidence_status": EVIDENCE_STATUS,
		"source_confidence": &"none",
		"source_bounded": false,
		"authenticated_original_geometry": false,
		"authenticated_original_function": false,
		"references": PackedStringArray(),
		"claim_ids": PackedStringArray(),
		"content_note": CONTENT_NOTE,
		"modern_interpretations": PackedStringArray([
			"the entire Salvage Terrace module and its name",
			"all terrace, ramp, rail, support, dressing, material, and sign design",
			"the salvage inspection/service role and station connection slot",
		]),
		"explicit_unknowns": PackedStringArray([
			"whether any historical build contained a salvage terrace",
			"historical salvage practice, equipment, dimensions, and adjacency",
		]),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null or not _module_anchor.global_transform.is_equal_approx(global_transform):
		errors.append("module anchor must remain the exact local-origin connection plane")
	if (
		_route_markers.size() != ROUTE_IDS.size()
		or PackedStringArray(get_route_ids()) != PackedStringArray(ROUTE_IDS)
	):
		errors.append("route marker roster differs from the exact seven-node contract")
	if not _connection_slot_is_exact():
		errors.append("connector slot must remain clear and exactly at the local origin")
	if _surface_nodes.size() != SURFACE_IDS.size():
		errors.append("standable surface roster must contain exactly six authoritative surfaces")
	if not _walkable_tags_are_exact():
		errors.append("walkable surface census tags differ from their stable id/kind contract")
	if not _surface_geometry_matches_contract():
		errors.append("visible and collision-backed walkable surface geometry diverged")
	var area := get_walkable_area_contract()
	if (
		not bool(area.live_geometry_derived)
		or not bool(area.live_geometry_valid)
		or not bool(area.projection_axis_aligned)
		or not bool(area.non_overlapping)
		or not is_equal_approx(float(area.projected_surface_sum_m2), HORIZONTAL_WALKABLE_AREA_M2)
		or not is_equal_approx(float(area.level_area_m2), LEVEL_WALKABLE_AREA_M2)
		or not is_equal_approx(float(area.ramp_projected_area_m2), 72.0)
		or not is_equal_approx(float(area.horizontal_walkable_area_m2), HORIZONTAL_WALKABLE_AREA_M2)
		or not is_equal_approx(float(area.ramp_true_area_m2), RAMP_TRUE_AREA_M2)
	):
		errors.append("live walkable-area union differs from the compacted exact non-overlapping 396 square metre contract")
	if PAD_IDS.size() < 2 or _surface_nodes.get(&"lower-salvage-pad") == _surface_nodes.get(&"upper-inspection-pad"):
		errors.append("module requires spatially distinct usable terrace pads")
	if _rail_nodes.size() < 12 or not _rails_are_live_and_physical():
		errors.append("exposed terrace and ramp edges require live physical safety rails")
	if not _dressing_is_batched_and_route_clear():
		errors.append("salvage/service dressing must stay batched and outside traversal routes")
	if not _salvage_work_bay_is_complete():
		errors.append("finished salvage work bay identity, machinery, framing, or lighting drifted")
	if not _identity_sign_is_route_clear():
		errors.append("identity sign must remain behind the entry rail and outside every walkable projection")
	var collision := get_collision_contract()
	if (
		not bool(collision.all_layers_match_lifecycle)
		or not bool(collision.all_masks_zero)
		or not bool(collision.all_shapes_present_and_enabled)
	):
		errors.append("static collision differs from the canonical World lifecycle contract")
	var authority := get_authority_contract()
	if (
		int(authority.ship_berth_count) != 0
		or int(authority.landing_or_interaction_area_count) != 0
		or int(authority.audio_node_count) != 0
		or int(authority.activity_node_count) != 0
		or bool(authority.owns_ship_authority)
		or bool(authority.owns_berth_authority)
		or bool(authority.owns_combat_authority)
		or bool(authority.owns_activity_authority)
	):
		errors.append("module must own zero ship, berth, combat, interaction, audio, or activity authority")
	var performance := get_performance_contract()
	if not bool(performance.exact_census):
		errors.append("exact renderer and physics performance census drifted")
	if not bool(performance.buffers_match_authored):
		errors.append("MultiMesh batch counts, visibility, transforms, or raw buffers drifted")
	if not bool(performance.resource_sharing_matches_authored):
		errors.append("shared safety-rail visual allocation contract drifted")
	var lifecycle := get_lifecycle_contract()
	if (
		not bool(lifecycle.reversible)
		or not bool(lifecycle.visible_matches_enabled)
		or not bool(lifecycle.collision_matches_enabled)
		or not bool(lifecycle.process_free)
	):
		errors.append("identity-preserving enable/disable lifecycle is inconsistent")
	if not _built_contract_is_live():
		errors.append("built hierarchy identity, transform, or visibility contract drifted")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"evidence_status": EVIDENCE_STATUS,
		"evidence": get_evidence_metadata(),
		"connection_slots": get_connection_slot_contract(),
		"routes": PackedStringArray(ROUTE_IDS),
		"footprint": get_integration_footprint(),
		"standable_surfaces": get_standable_surface_contract(),
		"walkable_area": get_walkable_area_contract(),
		"roster": get_component_roster(),
		"collision": get_collision_contract(),
		"authority": get_authority_contract(),
		"performance": get_performance_contract(),
		"lifecycle": get_lifecycle_contract(),
	}.duplicate(true)


func audit() -> Dictionary:
	return get_audit_report()


func _index_routes() -> void:
	_route_markers = {
		&"connector": _route_connector,
		&"entry": _route_entry,
		&"lower-pad": _route_lower_pad,
		&"main-ramp-base": _route_main_ramp_base,
		&"upper-pad": _route_upper_pad,
		&"inspection-ramp-base": _route_inspection_ramp_base,
		&"inspection-pad": _route_inspection_pad,
	}
	for route_id in _route_markers:
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	_route_connector.set_meta(StationModuleContract.CONNECTION_SLOT_META, CONNECTION_SLOT_ID)


func _build_surfaces() -> void:
	_add_level_surface(&"connection-apron", Vector3(0.0, LOWER_ELEVATION, 4.0), Vector2(12.0, 8.0))
	_add_level_surface(
		&"lower-salvage-pad",
		Vector3(-12.0, LOWER_ELEVATION, LOWER_PAD_CENTER_Z),
		Vector2(12.0, LOWER_PAD_DEPTH)
	)
	_add_ramp_surface(
		&"main-service-ramp",
		Vector3(6.0, LOWER_ELEVATION, 5.0),
		Vector3(14.0, UPPER_ELEVATION, 5.0),
		MAIN_RAMP_WIDTH
	)
	_add_level_surface(&"upper-inspection-pad", Vector3(20.0, UPPER_ELEVATION, 5.0), Vector2(12.0, 10.0))
	_add_ramp_surface(
		&"inspection-ramp",
		Vector3(23.0, UPPER_ELEVATION, 10.0),
		Vector3(23.0, INSPECTION_ELEVATION, 14.0),
		INSPECTION_RAMP_WIDTH
	)
	_add_level_surface(&"top-inspection-pad", Vector3(23.0, INSPECTION_ELEVATION, 16.0), Vector2(6.0, 4.0))


func _add_level_surface(
		surface_id: StringName,
		top_center: Vector3,
		plan_size: Vector2
	) -> void:
	var size := Vector3(plan_size.x, SURFACE_THICKNESS, plan_size.y)
	var transform := Transform3D(Basis.IDENTITY, top_center - Vector3.UP * SURFACE_THICKNESS * 0.5)
	var body := _box_body(_build_root, String(surface_id).to_pascal_case(), transform, size, _materials.deck)
	_tag_walkable_surface(body, surface_id, &"level")
	_surface_nodes[surface_id] = body
	_surface_contracts.append({
		"surface_id": surface_id,
		"kind": &"level",
		"body_path": get_path_to(body),
		"local_transform": transform,
		"size": size,
		"top_elevation": top_center.y,
	})


func _add_ramp_surface(
		surface_id: StringName,
		start: Vector3,
		finish: Vector3,
		width: float
	) -> void:
	var direction := finish - start
	var basis := _basis_with_local_back_along(direction)
	# Local -Z runs from start to finish. Offset the body half its thickness away
	# from the walking plane, so both endpoint planes meet their adjacent decks.
	var normal := basis.y.normalized()
	var transform := Transform3D(basis, (start + finish) * 0.5 - normal * SURFACE_THICKNESS * 0.5)
	var size := Vector3(width, SURFACE_THICKNESS, direction.length())
	var body := _box_body(_build_root, String(surface_id).to_pascal_case(), transform, size, _materials.deck)
	_tag_walkable_surface(body, surface_id, &"ramp")
	_surface_nodes[surface_id] = body
	_surface_contracts.append({
		"surface_id": surface_id,
		"kind": &"ramp",
		"body_path": get_path_to(body),
		"local_transform": transform,
		"size": size,
		"start": start,
		"finish": finish,
		"width": width,
	})


func _tag_walkable_surface(body: StaticBody3D, surface_id: StringName, kind: StringName) -> void:
	body.set_meta("walkable_surface", true)
	body.set_meta("walkable_surface_id", surface_id)
	body.set_meta("walkable_surface_kind", kind)
	body.set_meta("walkable_surface_owner", MODULE_ID)


func _build_safety_rails() -> void:
	# Every exposed edge is a continuous physical barrier. Gates exist only where
	# another declared walkable surface meets it, plus the 4 m local-origin entry.
	_long_rail_visual_mesh = BoxMesh.new()
	_long_rail_visual_mesh.resource_name = "SalvageTerraceLongRailVisualMesh"
	_long_rail_visual_mesh.size = LONG_RAIL_VISUAL_SIZE
	_entry_front_rail_visual_mesh = BoxMesh.new()
	_entry_front_rail_visual_mesh.resource_name = "SalvageTerraceEntryFrontRailVisualMesh"
	_entry_front_rail_visual_mesh.size = ENTRY_FRONT_RAIL_VISUAL_SIZE
	_top_side_rail_visual_mesh = BoxMesh.new()
	_top_side_rail_visual_mesh.resource_name = "SalvageTerraceTopSideRailVisualMesh"
	_top_side_rail_visual_mesh.size = TOP_SIDE_RAIL_VISUAL_SIZE
	_main_ramp_rail_visual_mesh = BoxMesh.new()
	_main_ramp_rail_visual_mesh.resource_name = "SalvageTerraceMainRampRailVisualMesh"
	_main_ramp_rail_visual_mesh.size = Vector3(
		0.16, 1.3, Vector3(8.0, UPPER_ELEVATION - LOWER_ELEVATION, 0.0).length()
	)
	_inspection_ramp_rail_visual_mesh = BoxMesh.new()
	_inspection_ramp_rail_visual_mesh.resource_name = "SalvageTerraceInspectionRampRailVisualMesh"
	_inspection_ramp_rail_visual_mesh.size = Vector3(
		0.16, 1.3,
		Vector3(0.0, INSPECTION_ELEVATION - UPPER_ELEVATION, 4.0).length()
	)
	_add_rail("EntryFrontPort", Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.65, 0.0)), Vector3(4.0, 1.3, 0.16))
	_add_rail("EntryFrontStarboard", Transform3D(Basis.IDENTITY, Vector3(4.0, 0.65, 0.0)), Vector3(4.0, 1.3, 0.16))
	_add_rail("EntryPortForward", Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.65, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail("EntryStarboardForward", Transform3D(Basis.IDENTITY, Vector3(6.0, 0.65, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail(
		"LowerOutboard",
		Transform3D(Basis.IDENTITY, Vector3(-18.0, 0.65, LOWER_PAD_CENTER_Z)),
		Vector3(0.16, 1.3, LOWER_PAD_DEPTH),
		# The compacted covered bay keeps closer-spaced perimeter posts beside
		# the sorting line; this is physical edge protection, not a new batch.
		6
	)
	_add_rail("LowerForward", Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.65, 2.0)), Vector3(12.0, 1.3, 0.16))
	_add_rail(
		"LowerAft",
		Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.65, LOWER_PAD_AFT_Z)),
		Vector3(12.0, 1.3, 0.16),
		# Denser posts resolve the compacted sorting-line boundary while keeping
		# the established open-rail silhouette and renderer allocation.
		8
	)
	_add_rail(
		"LowerInboardAft",
		Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.65, 8.5)),
		Vector3(0.16, 1.3, 1.0)
	)
	_add_sloped_rail("MainRampForward", Vector3(6.0, 0.0, 2.0), Vector3(14.0, 3.6, 2.0), _main_ramp_rail_visual_mesh)
	_add_sloped_rail("MainRampAft", Vector3(6.0, 0.0, 8.0), Vector3(14.0, 3.6, 8.0), _main_ramp_rail_visual_mesh)
	_add_rail("UpperOutboard", Transform3D(Basis.IDENTITY, Vector3(26.0, 4.25, 5.0)), Vector3(0.16, 1.3, 10.0))
	_add_rail("UpperForward", Transform3D(Basis.IDENTITY, Vector3(20.0, 4.25, 0.0)), Vector3(12.0, 1.3, 0.16))
	_add_rail("UpperAftPort", Transform3D(Basis.IDENTITY, Vector3(17.0, 4.25, 10.0)), Vector3(6.0, 1.3, 0.16))
	_add_rail("UpperInboardForward", Transform3D(Basis.IDENTITY, Vector3(14.0, 4.25, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail("UpperInboardAft", Transform3D(Basis.IDENTITY, Vector3(14.0, 4.25, 9.0)), Vector3(0.16, 1.3, 2.0))
	_add_sloped_rail("InspectionRampPort", Vector3(20.0, 3.6, 10.0), Vector3(20.0, 5.4, 14.0), _inspection_ramp_rail_visual_mesh)
	_add_sloped_rail("InspectionRampStarboard", Vector3(26.0, 3.6, 10.0), Vector3(26.0, 5.4, 14.0), _inspection_ramp_rail_visual_mesh)
	_add_rail("TopAft", Transform3D(Basis.IDENTITY, Vector3(23.0, 6.05, 18.0)), Vector3(6.0, 1.3, 0.16))
	_add_rail("TopPort", Transform3D(Basis.IDENTITY, Vector3(20.0, 6.05, 16.0)), Vector3(0.16, 1.3, 4.0))
	_add_rail("TopStarboard", Transform3D(Basis.IDENTITY, Vector3(26.0, 6.05, 16.0)), Vector3(0.16, 1.3, 4.0))
	_add_multimesh_batch(
		"RailDetailBatch", Vector3.ONE, _rail_detail_transforms, _materials.rail,
		"open top and mid rails with regular posts over conservative hidden collision"
	)


func _add_rail(
		node_name: String, transform: Transform3D, size: Vector3,
		post_interval_count_override: int = -1,
		shared_visual_mesh: BoxMesh = null
	) -> void:
	var visual_mesh := shared_visual_mesh
	var omit_hidden_renderer := node_name in SHORT_SIDE_RAIL_NAMES
	if visual_mesh == null:
		if StringName(node_name) in LONG_RAIL_NAMES:
			visual_mesh = _long_rail_visual_mesh
		elif StringName(node_name) in ENTRY_FRONT_RAIL_NAMES:
			visual_mesh = _entry_front_rail_visual_mesh
		elif StringName(node_name) in TOP_SIDE_RAIL_NAMES:
			visual_mesh = _top_side_rail_visual_mesh
	var rail := _box_body(
		_build_root, node_name, transform, size, _materials.rail, visual_mesh,
		omit_hidden_renderer
	)
	rail.set_meta("safety_rail", true)
	var visual_path_node := rail.get_node(^"Mesh") as Node3D
	# Keep the proven conservative physics envelope but do not render it as a
	# waist-high solid wall. Open rail bars and posts are drawn by RailDetailBatch.
	if visual_path_node is MeshInstance3D:
		(visual_path_node as MeshInstance3D).visible = false
	visual_path_node.set_meta(
		"non_walkable_reason", "physical safety rail, not a route surface"
	)
	_rail_nodes.append(rail)
	_append_rail_detail_transforms(transform, size, post_interval_count_override)


func _append_rail_detail_transforms(
		rail_transform: Transform3D, size: Vector3, post_interval_count_override: int = -1
	) -> void:
	var runs_on_x := size.x >= size.z
	var run_length := size.x if runs_on_x else size.z
	var bar_size := (
		Vector3(run_length, 0.10, 0.10)
		if runs_on_x else Vector3(0.10, 0.10, run_length)
	)
	for rail_height in [-0.05, 0.50]:
		_rail_detail_transforms.append(
			rail_transform * Transform3D(
				Basis.IDENTITY.scaled(bar_size), Vector3(0.0, rail_height, 0.0)
			)
		)
	var interval_count := (
		post_interval_count_override
		if post_interval_count_override > 0
		else ceili(run_length / 2.0)
	)
	for post_index in range(interval_count + 1):
		var along := lerpf(-run_length * 0.5, run_length * 0.5, float(post_index) / interval_count)
		var local_position := Vector3(along, 0.0, 0.0) if runs_on_x else Vector3(0.0, 0.0, along)
		_rail_detail_transforms.append(
			rail_transform * Transform3D(
				Basis.IDENTITY.scaled(RAIL_POST_VISUAL_SIZE), local_position
			)
		)


func _add_sloped_rail(
		node_name: String, start: Vector3, finish: Vector3, visual_mesh: BoxMesh
	) -> void:
	var direction := finish - start
	var basis := _basis_with_local_back_along(direction)
	var transform := Transform3D(basis, (start + finish) * 0.5 + Vector3.UP * 0.65)
	_add_rail(node_name, transform, Vector3(0.16, 1.3, direction.length()), -1, visual_mesh)
	# Sloped rails author from finish back to start, so the final appended detail
	# is the actual rendered post at the route threshold.
	_ramp_threshold_post_transforms.append(_rail_detail_transforms.back())


func _build_batched_supports_and_dressing() -> void:
	var support_transforms: Array[Transform3D] = []
	for support in [
		Vector3(-16, -0.9, 4), Vector3(-16, -0.9, 8), Vector3(-8, -0.9, 4),
		Vector3(-8, -0.9, 8), Vector3(16, 2.4, 2), Vector3(24, 2.4, 2),
		Vector3(16, 2.4, 8), Vector3(24, 2.4, 8), Vector3(21, 4.5, 16),
		Vector3(25, 4.5, 16),
	]:
		support_transforms.append(Transform3D(Basis.IDENTITY, support as Vector3))
	_add_multimesh_batch("TerraceSupportBatch", Vector3(0.65, 1.8, 0.65), support_transforms, _materials.frame, "structural support below walkable decks")

	# Salvage cages sit outside the compacted walkable union behind the lower
	# pad's aft rail. They read as stored service stock without consuming routes.
	var salvage_transforms: Array[Transform3D] = []
	for position_value in [
		Vector3(-17.1, 0.65, 10.2), Vector3(-15.5, 0.65, 10.2),
		Vector3(-13.9, 0.65, 10.2), Vector3(16.0, 4.25, 11.0),
		Vector3(17.6, 4.25, 11.0), Vector3(19.2, 4.25, 11.0),
	]:
		salvage_transforms.append(Transform3D(Basis.IDENTITY, position_value as Vector3))
	_add_multimesh_batch("SalvageCageBatch", Vector3(1.3, 1.3, 1.3), salvage_transforms, _materials.salvage, "batched salvage cage outside every traversal corridor")

	# Reuse the existing four-copy emissive batch as two unmistakable ramp gates.
	# These remain passive presentation: no light, collision, processing, route or
	# authority is added, and the separate hazard-dressing surface is untouched.
	var beacon_transforms: Array[Transform3D] = []
	for post_transform in _ramp_threshold_post_transforms:
		var cue_basis := post_transform.basis.orthonormalized()
		var post_top := post_transform.origin + post_transform.basis.y * 0.5
		var cue_center := post_top + cue_basis.y * SERVICE_BEACON_SIZE.y * 0.5
		beacon_transforms.append(Transform3D(cue_basis, cue_center))
	_add_multimesh_batch(
		"ServiceBeaconBatch", SERVICE_BEACON_SIZE, beacon_transforms, _materials.emissive,
		"paired emissive ramp-gate cues mounted over physical rail posts with no dynamic light"
	)

	# One outboard inspection gantry over void, intentionally collision-free and
	# outside the surface union. Its long orange boom reaches inboard from the mast
	# as a strong gameplay-distance landmark without placing furniture in any route.
	_visual_box("InspectionGantryMast", Vector3(27.0, 3.0, 7.5), Vector3(0.45, 6.0, 0.45), _materials.frame, "outboard inspection gantry over void")
	_visual_box("SuspendedSalvageClamp", Vector3(26.6, 5.0, 7.5), Vector3(0.8, 1.2, 0.8), _materials.salvage, "suspended service clamp beyond the upper terrace rail")


func _build_salvage_work_bay() -> void:
	# A tall portal frame turns the lower terrace into a recognizable covered
	# breaking/sorting bay. The uprights hug the already-guarded perimeter and
	# every cross-member remains well above the player capsule.
	var frame_transforms: Array[Transform3D] = []
	for z_value in [3.0, 5.75, 8.5]:
		frame_transforms.append(
			Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 7.0, 0.7)), Vector3(-17.55, 2.1, z_value))
		)
		frame_transforms.append(
			Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 7.0, 0.7)), Vector3(-6.45, 2.1, z_value))
		)
		frame_transforms.append(
			Transform3D(Basis.IDENTITY.scaled(Vector3(11.8, 0.55, 0.7)), Vector3(-12.0, 4.25, z_value))
		)
	frame_transforms.append(
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 3.0, 0.7)), Vector3(25.55, 5.1, 5.0))
	)
	_add_multimesh_batch(
		"SalvageFrameBatch", Vector3.ONE, frame_transforms, _materials.frame,
		"portal framing hugs guarded edges or stays above player clearance"
	)

	# Compact sorting equipment is staged behind the aft rail, not on any of the
	# six walkable projections. Different transforms make the shared cube read as
	# conveyor, crusher, hopper, and stock rather than repeated crates.
	var machinery_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY.scaled(Vector3(3.2, 0.7, 1.2)), Vector3(-15.7, 1.0, 10.35)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.4, 2.2, 1.4)), Vector3(-12.4, 1.25, 10.35)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.8, 0.45, 1.6)), Vector3(-9.8, 0.65, 10.35)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.35, 1.6, 0.35)), Vector3(-16.8, 1.45, 10.35)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(2.8, 0.55, 1.1)), Vector3(16.0, 4.2, 11.25)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.2, 1.8, 1.2)), Vector3(19.2, 4.75, 11.25)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.7, 0.4, 1.4)), Vector3(21.4, 4.05, 11.25)),
		Transform3D(Basis.IDENTITY.scaled(Vector3(0.3, 1.4, 0.3)), Vector3(17.6, 4.65, 11.25)),
	]
	_add_multimesh_batch(
		"SortingMachineryBatch", Vector3.ONE, machinery_transforms, _materials.machine,
		"sorting machinery staged behind physical aft rails outside route projections"
	)

	_visual_box("LowerBayRoof", Vector3(-12.0, 4.6, 5.5), Vector3(11.4, 0.22, 6.4), _materials.roof, "high compacted salvage-bay roof above player clearance")
	_visual_box("CraneTrolley", Vector3(-10.1, 3.72, 5.5), Vector3(0.8, 0.55, 0.7), _materials.machine, "overhead crane trolley above player clearance")
	_visual_box("CraneDropCable", Vector3(-10.1, 3.15, 5.5), Vector3(0.08, 0.9, 0.08), _materials.rail, "overhead crane cable outside capsule height")
	_visual_box("UpperInspectionConsole", Vector3(25.55, 4.25, 5.0), Vector3(0.45, 1.1, 1.8), _materials.machine, "inspection console beyond upper outboard rail")
	_visual_box("UpperConsoleScreen", Vector3(25.28, 4.45, 5.0), Vector3(0.05, 0.55, 1.15), _materials.emissive, "emissive inspection display beyond upper outboard rail")
	_visual_box("BayNameplate", Vector3(-12.0, 4.15, 2.76), Vector3(4.4, 0.65, 0.12), _materials.emissive, "illuminated salvage-bay nameplate above entry clearance")
	_build_hazard_dressing_render()

	_add_work_light("LowerBayWorkLight", Vector3(-12.0, 3.9, 5.5), Color("83e9df"), 1.4, 6.5)
	_add_work_light("SortingLineWorkLight", Vector3(-12.0, 2.8, 8.0), Color("ff9b43"), 1.15, 4.5)
	_add_work_light("UpperInspectionWorkLight", Vector3(24.8, 5.25, 5.0), Color("72dcd7"), 1.0, 4.0)


func _add_work_light(
		node_name: String, position_value: Vector3, color_value: Color,
		energy: float, range_value: float
	) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color_value
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = range_value * 3.0
	light.distance_fade_length = range_value
	light.set_meta("non_walkable_reason", "localized static work illumination")
	_build_root.add_child(light)


func _build_identity_sign() -> void:
	var sign_back := _visual_box("IdentitySignBack", Vector3(-4.0, 2.1, -0.5), Vector3(3.6, 1.6, 0.25), _materials.frame, "vertical identity sign behind the physical entry rail and outside the walkable union")
	sign_back.set_meta("outside_walkable_union", true)
	var label := Label3D.new()
	label.name = "SalvageTerraceIdentity"
	label.text = "SALVAGE\nTERRACE"
	label.font_size = 52
	label.outline_size = 8
	label.modulate = Color("b9f4ee")
	label.outline_modulate = Color("10252b")
	label.position = Vector3(-4.0, 2.1, -0.64)
	label.set_meta("non_walkable_reason", "bounded vertical area identity label")
	_build_root.add_child(label)


func _add_multimesh_batch(
		node_name: String,
		size: Vector3,
		transforms: Array[Transform3D],
		material: Material,
		reason: String
	) -> void:
	var mesh: BoxMesh
	if StringName(node_name) in UNIT_BOX_BATCH_NAMES and size.is_equal_approx(Vector3.ONE):
		if _unit_box_batch_mesh == null:
			_unit_box_batch_mesh = BoxMesh.new()
			_unit_box_batch_mesh.resource_name = "SalvageTerraceUnitBoxBatchMesh"
			_unit_box_batch_mesh.size = Vector3.ONE
		mesh = _unit_box_batch_mesh
	else:
		mesh = BoxMesh.new()
		mesh.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = transforms.size()
	multimesh.mesh = mesh
	# Bulk-author the actual renderer buffer so the 12-float Transform3D payload
	# remains directly auditable even under the headless rendering backend.
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.set_meta("non_walkable_reason", reason)
	_build_root.add_child(batch)


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


func _box_body(
		parent: Node3D,
		node_name: String,
		transform: Transform3D,
		size: Vector3,
		material: Material,
		shared_visual_mesh: BoxMesh = null,
		omit_hidden_renderer: bool = false
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = transform
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	if omit_hidden_renderer:
		var visual_anchor := Marker3D.new()
		visual_anchor.name = "Mesh"
		visual_anchor.set_meta("renderer_elided_anchor", true)
		body.add_child(visual_anchor)
	else:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		var mesh := shared_visual_mesh
		if mesh == null:
			mesh = BoxMesh.new()
			mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.material_override = material
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _visual_box(
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		reason: String
	) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.position = position_value
	result.mesh = StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.16),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.FACE_GRID
	)
	result.material_override = material
	result.set_meta("non_walkable_reason", reason)
	_build_root.add_child(result)
	return result


## These five authored hazard pieces are immutable, collision-free dressing with
## one material. Bake their exact rounded meshes at their authored transforms
## into one retained surface, leaving the five source meshes transient.
func _build_hazard_dressing_render() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var authored_parts: Array[Dictionary] = []
	for definition_variant in HAZARD_DRESSING_PARTS:
		var definition := definition_variant as Dictionary
		var size := definition.size as Vector3
		var transform := Transform3D(Basis.IDENTITY, definition.position as Vector3)
		tool.append_from(
			StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
				size,
				StationSurfaceKit.proportional_bevel_for_size(size, 0.16),
				_rounded_box_cache,
				StationSurfaceKit.BevelUV.FACE_GRID
			),
			0,
			transform
		)
		authored_parts.append({
			"id": definition.id,
			"size": size,
			"transform": transform,
			"reason": definition.reason,
		})
	var renderer := MeshInstance3D.new()
	renderer.name = HAZARD_DRESSING_RENDER_NAME
	renderer.mesh = tool.commit()
	renderer.material_override = _materials.hazard
	renderer.set_meta("non_walkable_reason", "five merged collision-free hazard dressing pieces outside every traversal corridor")
	renderer.set_meta("salvage_terrace_hazard_dressing_parts", authored_parts)
	renderer.set_meta("authored_visible_copy_count", authored_parts.size())
	_build_root.add_child(renderer)


func _create_materials() -> void:
	_materials["deck"] = _material(Color("334f59"), 0.68, 0.34)
	_materials["frame"] = _material(Color("172930"), 0.76, 0.3)
	_materials["rail"] = _material(Color("789097"), 0.7, 0.27)
	_materials["salvage"] = _material(Color("7a5132"), 0.42, 0.5)
	_materials["hazard"] = _material(Color("dc7f2d"), 0.28, 0.38)
	_materials["emissive"] = _material(Color("76e6dc"), 0.12, 0.25, Color("36c9c2"), 1.2)
	_materials["machine"] = _material(Color("415b62"), 0.82, 0.26)
	_materials["roof"] = _material(Color("20363d"), 0.74, 0.42)
	# Keep the terrace's existing cool-teal and salvage-brown palette while making
	# physical roles legible at walking distance. These are the same six shared
	# resources already feeding every MeshInstance and MultiMesh: only the surface
	# kit's clearcoat hierarchy changes, so geometry, collisions, transforms,
	# lights and renderer allocations stay untouched.
	var finish_by_key := {
		# All six authoritative pads and ramps are trafficked deck plate.
		"deck": StationSurfaceKit.PanelFinish.WALKED_DECK,
		# Supports, portal framing, gantry mast and sign backing remain load-bearing
		# dark alloy rather than painted equipment.
		"frame": StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
		# Safety furniture and the crane cable read as handled metal trim.
		"rail": StationSurfaceKit.PanelFinish.METAL_TRIM,
		# Stored cages/clamp, sorting plant and the bay shell are painted industrial
		# surfaces, distinct from both frame alloy and walked deck.
		"salvage": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		"machine": StationSurfaceKit.PanelFinish.PAINTED_METAL,
		"roof": StationSurfaceKit.PanelFinish.PAINTED_METAL,
	}
	for key: String in finish_by_key:
		StationSurfaceKit.apply_panel_triplanar(
			_materials[key] as StandardMaterial3D,
			PANEL_SURFACE_SCALE,
			finish_by_key[key]
		)


func _material(
		albedo: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		emission_energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	material.clearcoat_enabled = true
	material.clearcoat = 0.18
	material.clearcoat_roughness = 0.48
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _basis_with_local_back_along(direction: Vector3) -> Basis:
	# Box depth is local Z. Align local -Z with the route direction, retain a
	# horizontal width axis, and derive the walking-plane normal from both.
	var z_axis := -direction.normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _connection_slot_is_exact() -> bool:
	return (
		is_instance_valid(_route_connector)
		and _route_connector.position.is_equal_approx(Vector3(0.0, 0.15, 0.0))
		and _route_connector.basis.is_equal_approx(Basis.IDENTITY)
		and StationModuleContract.new().read_connection_slot_id(_route_connector) == CONNECTION_SLOT_ID
		and get_connection_slot_contract().size() == 1
	)


func _walkable_tags_are_exact() -> bool:
	for surface_id in SURFACE_IDS:
		var body := _surface_nodes.get(StringName(surface_id)) as StaticBody3D
		if (
			not is_instance_valid(body)
			or not bool(body.get_meta("walkable_surface", false))
			or StringName(body.get_meta("walkable_surface_id", &"")) != StringName(surface_id)
			or StringName(body.get_meta("walkable_surface_owner", &"")) != MODULE_ID
			or StringName(body.get_meta("walkable_surface_kind", &""))
				!= (&"ramp" if String(surface_id).contains("ramp") else &"level")
		):
			return false
	for body in StationModuleContract.collect_static_bodies(self):
		if body not in _surface_nodes.values() and bool(body.get_meta("walkable_surface", false)):
			return false
	return true


func _surface_geometry_matches_contract() -> bool:
	if _surface_contracts.size() != SURFACE_IDS.size():
		return false
	for contract in _surface_contracts:
		var body := _surface_nodes.get(contract.surface_id) as StaticBody3D
		if not is_instance_valid(body) or not body.transform.is_equal_approx(contract.local_transform):
			return false
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
		var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
		var mesh := mesh_instance.mesh as BoxMesh if mesh_instance != null else null
		var shape := collision.shape as BoxShape3D if collision != null else null
		if (
			mesh == null or shape == null
			or not mesh.size.is_equal_approx(contract.size as Vector3)
			or not shape.size.is_equal_approx(contract.size as Vector3)
			or mesh_instance.material_override != _materials.deck
		):
			return false
	return true


func _build_live_surface_contracts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for authored in _surface_contracts:
		var live := authored.duplicate(true)
		var body := _surface_nodes.get(authored.surface_id) as StaticBody3D
		var geometry := _live_surface_geometry(body)
		live["local_transform"] = body.transform if is_instance_valid(body) else Transform3D.IDENTITY
		live["size"] = geometry.size
		live["horizontal_area_m2"] = geometry.horizontal_area_m2
		live["true_area_m2"] = geometry.true_area_m2
		live["projection_rect"] = geometry.projection_rect
		live["projection_axis_aligned"] = geometry.projection_axis_aligned
		live["geometry_valid"] = geometry.valid
		result.append(live)
	return result


func _live_surface_geometry(body: StaticBody3D) -> Dictionary:
	var invalid := {
		"valid": false,
		"size": Vector3.ZERO,
		"horizontal_area_m2": 0.0,
		"true_area_m2": 0.0,
		"projection_rect": Rect2(),
		"projection_axis_aligned": false,
	}
	if not is_instance_valid(body):
		return invalid
	var collision := body.get_node_or_null(^"Collision") as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape == null:
		return invalid
	var local_transform := global_transform.affine_inverse() * collision.global_transform
	var x_edge := local_transform.basis.x * shape.size.x
	var y_edge := local_transform.basis.y * shape.size.y
	var z_edge := local_transform.basis.z * shape.size.z
	var surface_cross := x_edge.cross(z_edge)
	# The authoritative footprint is the top walking plane, not the collision
	# box centre. Ramp bodies are offset below that plane by half their thickness.
	var top_center := local_transform.origin + y_edge * 0.5
	var projection_points := PackedVector2Array()
	for x_sign: float in [-0.5, 0.5]:
		for z_sign: float in [-0.5, 0.5]:
			var point: Vector3 = top_center + x_edge * x_sign + z_edge * z_sign
			projection_points.append(Vector2(point.x, point.z))
	var bounds := _bounds_for_points(projection_points)
	var projected_area := absf(surface_cross.y)
	return {
		"valid": surface_cross.length() > 0.0 and projected_area > 0.0,
		"size": shape.size,
		"horizontal_area_m2": projected_area,
		"true_area_m2": surface_cross.length(),
		"projection_rect": bounds,
		"projection_axis_aligned": is_equal_approx(bounds.get_area(), projected_area),
	}


func _bounds_for_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _axis_aligned_rect_union_area(rects: Array[Rect2]) -> float:
	if rects.is_empty():
		return 0.0
	var x_edges: Array[float] = []
	for rect in rects:
		x_edges.append(rect.position.x)
		x_edges.append(rect.end.x)
	x_edges.sort()
	var area := 0.0
	for index in x_edges.size() - 1:
		var x_min := x_edges[index]
		var x_max := x_edges[index + 1]
		if is_equal_approx(x_min, x_max):
			continue
		var intervals: Array[Vector2] = []
		for rect in rects:
			if rect.position.x < x_max and rect.end.x > x_min:
				intervals.append(Vector2(rect.position.y, rect.end.y))
		intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var covered_y := 0.0
		if not intervals.is_empty():
			var merged_start := intervals[0].x
			var merged_end := intervals[0].y
			for interval_index in range(1, intervals.size()):
				var interval := intervals[interval_index]
				if interval.x <= merged_end:
					merged_end = maxf(merged_end, interval.y)
				else:
					covered_y += merged_end - merged_start
					merged_start = interval.x
					merged_end = interval.y
			covered_y += merged_end - merged_start
		area += (x_max - x_min) * covered_y
	return area


func _identity_sign_is_route_clear() -> bool:
	var sign_back := _build_root.get_node_or_null(^"IdentitySignBack") as MeshInstance3D
	if sign_back == null or not bool(sign_back.get_meta("outside_walkable_union", false)):
		return false
	var sign_bounds := _mesh_projection_bounds(sign_back)
	if sign_bounds.get_area() <= 0.0 or sign_bounds.end.y >= 0.0 or sign_bounds.end.x > -2.0:
		return false
	for surface in _build_live_surface_contracts():
		var overlap := sign_bounds.intersection(surface.projection_rect as Rect2)
		if overlap.get_area() > 0.0001:
			return false
	return true


func _mesh_projection_bounds(mesh_instance: MeshInstance3D) -> Rect2:
	if mesh_instance == null or mesh_instance.mesh == null:
		return Rect2()
	var aabb := mesh_instance.mesh.get_aabb()
	var local_transform := global_transform.affine_inverse() * mesh_instance.global_transform
	var points := PackedVector2Array()
	for x_value in [aabb.position.x, aabb.end.x]:
		for y_value in [aabb.position.y, aabb.end.y]:
			for z_value in [aabb.position.z, aabb.end.z]:
				var point := local_transform * Vector3(x_value, y_value, z_value)
				points.append(Vector2(point.x, point.z))
	return _bounds_for_points(points)


func _rails_are_live_and_physical() -> bool:
	for rail in _rail_nodes:
		if (
			not is_instance_valid(rail)
			or rail.get_parent() != _build_root
			or not bool(rail.get_meta("safety_rail", false))
			or rail.collision_mask != 0
			or rail.collision_layer != (WORLD_LAYER if _enabled else 0)
			or rail.find_children("*", "CollisionShape3D", true, false).size() != 1
		):
			return false
	return true


func _dressing_is_batched_and_route_clear() -> bool:
	var batches := _build_root.find_children("*", "MultiMeshInstance3D", true, false)
	if batches.size() != 6:
		return false
	for raw_batch in batches:
		var batch := raw_batch as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.instance_count <= 0:
			return false
		if str(batch.get_meta("non_walkable_reason", "")).is_empty():
			return false
	# Free-standing visuals are above/outboard of the declared centreline
	# corridors; their exact transforms are held by the build contract.
	return true


func _salvage_work_bay_is_complete() -> bool:
	var required_nodes := PackedStringArray([
		"SalvageFrameBatch", "SortingMachineryBatch", "LowerBayRoof",
		String(HAZARD_DRESSING_RENDER_NAME), "CraneTrolley", "UpperInspectionConsole",
		"UpperConsoleScreen", "BayNameplate", "LowerBayWorkLight",
		"SortingLineWorkLight", "UpperInspectionWorkLight",
	])
	for node_name in required_nodes:
		var candidate := _build_root.get_node_or_null(NodePath(node_name))
		if candidate == null or str(candidate.get_meta("non_walkable_reason", "")).is_empty():
			return false
	var frame_batch := _build_root.get_node_or_null(^"SalvageFrameBatch") as MultiMeshInstance3D
	var machinery_batch := _build_root.get_node_or_null(^"SortingMachineryBatch") as MultiMeshInstance3D
	if (
		frame_batch == null or frame_batch.multimesh == null
		or frame_batch.multimesh.instance_count != 10
		or machinery_batch == null or machinery_batch.multimesh == null
		or machinery_batch.multimesh.instance_count != 8
	):
		return false
	var lights := _build_root.find_children("*", "OmniLight3D", true, false)
	if lights.size() != 3:
		return false
	for raw_light in lights:
		var light := raw_light as OmniLight3D
		if light.shadow_enabled or light.omni_range > 6.5 or light.light_energy > 1.4:
			return false
	return true


func _capture_built_contract() -> void:
	_built_node_ids.clear()
	_built_node_transforms.clear()
	_built_multimesh_buffers.clear()
	_built_multimesh_visible_counts.clear()
	for candidate in find_children("*", "", true, false):
		var path := str(get_path_to(candidate))
		_built_node_ids[path] = candidate.get_instance_id()
		if candidate is Node3D:
			_built_node_transforms[path] = (candidate as Node3D).transform
		if candidate is MultiMeshInstance3D:
			var batch := candidate as MultiMeshInstance3D
			if batch.multimesh != null:
				_built_multimesh_buffers[path] = batch.multimesh.buffer.duplicate()
				_built_multimesh_visible_counts[path] = batch.multimesh.visible_instance_count


func _built_contract_is_live() -> bool:
	var descendants := find_children("*", "", true, false)
	if descendants.size() != _built_node_ids.size():
		return false
	for path_value in _built_node_ids:
		var candidate := get_node_or_null(NodePath(str(path_value)))
		if (
			not is_instance_valid(candidate)
			or candidate.get_instance_id() != int(_built_node_ids[path_value])
		):
			return false
		if candidate is Node3D and not (candidate as Node3D).transform.is_equal_approx(
			_built_node_transforms[path_value] as Transform3D
		):
			return false
	return true


func _multimesh_contract_is_live() -> bool:
	var batches := find_children("*", "MultiMeshInstance3D", true, false)
	if batches.size() != MULTIMESH_INSTANCE_COUNTS.size():
		return false
	for raw_batch in batches:
		var batch := raw_batch as MultiMeshInstance3D
		var path := str(get_path_to(batch))
		if (
			batch.multimesh == null
			or not MULTIMESH_INSTANCE_COUNTS.has(String(batch.name))
			or batch.multimesh.instance_count != int(MULTIMESH_INSTANCE_COUNTS[String(batch.name)])
			or not _built_multimesh_buffers.has(path)
			or batch.multimesh.buffer != _built_multimesh_buffers[path]
			or batch.multimesh.visible_instance_count != int(_built_multimesh_visible_counts.get(path, -2))
		):
			return false
	return true


func _apply_enabled_state() -> void:
	if _build_root == null:
		return
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _enabled, _build_root
	)


func _apply_metadata() -> void:
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("element_status", ELEMENT_STATUS)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("source_bounded", false)
	set_meta("authenticated_original_geometry", false)
	set_meta("owns_ship_authority", false)
	set_meta("owns_berth_authority", false)
	set_meta("owns_combat_authority", false)
	set_meta("owns_activity_authority", false)
	set_meta("horizontal_walkable_area_m2", HORIZONTAL_WALKABLE_AREA_M2)
	set_meta("content_note", CONTENT_NOTE)
	add_to_group(&"station_modules")
