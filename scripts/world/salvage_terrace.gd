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

## Exact non-overlapping horizontal projection. Shared boundaries have zero area.
const LEVEL_WALKABLE_AREA_M2 := 384.0
const RAMP_PROJECTED_AREA_M2 := 72.0
const HORIZONTAL_WALKABLE_AREA_M2 := 456.0
const MAIN_RAMP_TRUE_AREA_M2 := 52.636109
const INSPECTION_RAMP_TRUE_AREA_M2 := 26.318054
const RAMP_TRUE_AREA_M2 := 78.954163

const FOOTPRINT_MIN := Vector3(-18.1, -1.8, -0.1)
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

## Exact focused-census budgets. These are frozen to the standalone build rather
## than padded during integration, so any added submission/node turns audit red.
const PERFORMANCE_BUDGET := {
	"mesh_instances": 30,
	"multimesh_batches": 3,
	"multimesh_instances": 20,
	"static_bodies": 26,
	"collision_shapes": 26,
	"labels": 1,
	"lights": 0,
	"nodes": 96,
	"process_loops": 0,
	"physics_process_loops": 0,
}

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
var _rounded_box_cache: Dictionary = {}


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
	return _surface_contracts.duplicate(true)


func get_walkable_area_contract() -> Dictionary:
	var by_surface := {}
	for surface in _surface_contracts:
		by_surface[surface.surface_id] = {
			"kind": surface.kind,
			"horizontal_area_m2": surface.horizontal_area_m2,
			"true_area_m2": surface.true_area_m2,
		}
	return {
		"schema_version": SCHEMA_VERSION,
		"surface_union": &"non_overlapping_shared_boundaries_only",
		"surface_count": _surface_contracts.size(),
		"level_area_m2": LEVEL_WALKABLE_AREA_M2,
		"ramp_projected_area_m2": RAMP_PROJECTED_AREA_M2,
		"horizontal_walkable_area_m2": HORIZONTAL_WALKABLE_AREA_M2,
		"ramp_true_area_m2": RAMP_TRUE_AREA_M2,
		"main_ramp_true_area_m2": MAIN_RAMP_TRUE_AREA_M2,
		"inspection_ramp_true_area_m2": INSPECTION_RAMP_TRUE_AREA_M2,
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
	for raw_batch in multimeshes:
		var batch := raw_batch as MultiMeshInstance3D
		if batch.multimesh != null:
			multimesh_instances += batch.multimesh.instance_count
	contract["schema_version"] = SCHEMA_VERSION
	contract["multimesh_batches"] = multimeshes.size()
	contract["multimesh_instances"] = multimesh_instances
	contract["nodes"] = 1 + find_children("*", "", true, false).size()
	contract["budgets"] = PERFORMANCE_BUDGET.duplicate(true)
	contract["within_budget"] = (
		bool(contract.within_budget)
		and int(contract.multimesh_batches) <= int(PERFORMANCE_BUDGET.multimesh_batches)
		and int(contract.multimesh_instances) <= int(PERFORMANCE_BUDGET.multimesh_instances)
		and int(contract.nodes) <= int(PERFORMANCE_BUDGET.nodes)
	)
	return contract


func set_module_enabled(enabled: bool) -> void:
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
		"source_bounded": true,
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
		not is_equal_approx(float(area.level_area_m2), 384.0)
		or not is_equal_approx(float(area.ramp_projected_area_m2), 72.0)
		or not is_equal_approx(float(area.horizontal_walkable_area_m2), 456.0)
		or not is_equal_approx(float(area.ramp_true_area_m2), RAMP_TRUE_AREA_M2)
	):
		errors.append("walkable-area union differs from the exact 456 square metre contract")
	if PAD_IDS.size() < 2 or _surface_nodes.get(&"lower-salvage-pad") == _surface_nodes.get(&"upper-inspection-pad"):
		errors.append("module requires spatially distinct usable terrace pads")
	if _rail_nodes.size() < 12 or not _rails_are_live_and_physical():
		errors.append("exposed terrace and ramp edges require live physical safety rails")
	if not _dressing_is_batched_and_route_clear():
		errors.append("salvage/service dressing must stay batched and outside traversal routes")
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
	if not bool(get_performance_contract().within_budget):
		errors.append("module exceeds its mesh, batch, collision, light, node, label, or loop budget")
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
	_add_level_surface(&"connection-apron", Vector3(0.0, LOWER_ELEVATION, 4.0), Vector2(12.0, 8.0), 96.0)
	_add_level_surface(&"lower-salvage-pad", Vector3(-12.0, LOWER_ELEVATION, 8.0), Vector2(12.0, 12.0), 144.0)
	_add_ramp_surface(
		&"main-service-ramp",
		Vector3(6.0, LOWER_ELEVATION, 5.0),
		Vector3(14.0, UPPER_ELEVATION, 5.0),
		MAIN_RAMP_WIDTH,
		48.0,
		MAIN_RAMP_TRUE_AREA_M2
	)
	_add_level_surface(&"upper-inspection-pad", Vector3(20.0, UPPER_ELEVATION, 5.0), Vector2(12.0, 10.0), 120.0)
	_add_ramp_surface(
		&"inspection-ramp",
		Vector3(23.0, UPPER_ELEVATION, 10.0),
		Vector3(23.0, INSPECTION_ELEVATION, 14.0),
		INSPECTION_RAMP_WIDTH,
		24.0,
		INSPECTION_RAMP_TRUE_AREA_M2
	)
	_add_level_surface(&"top-inspection-pad", Vector3(23.0, INSPECTION_ELEVATION, 16.0), Vector2(6.0, 4.0), 24.0)


func _add_level_surface(
		surface_id: StringName,
		top_center: Vector3,
		plan_size: Vector2,
		horizontal_area_m2: float
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
		"horizontal_area_m2": horizontal_area_m2,
		"true_area_m2": horizontal_area_m2,
	})


func _add_ramp_surface(
		surface_id: StringName,
		start: Vector3,
		finish: Vector3,
		width: float,
		horizontal_area_m2: float,
		true_area_m2: float
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
		"horizontal_area_m2": horizontal_area_m2,
		"true_area_m2": true_area_m2,
	})


func _tag_walkable_surface(body: StaticBody3D, surface_id: StringName, kind: StringName) -> void:
	body.set_meta("walkable_surface", true)
	body.set_meta("walkable_surface_id", surface_id)
	body.set_meta("walkable_surface_kind", kind)
	body.set_meta("walkable_surface_owner", MODULE_ID)


func _build_safety_rails() -> void:
	# Every exposed edge is a continuous physical barrier. Gates exist only where
	# another declared walkable surface meets it, plus the 4 m local-origin entry.
	_add_rail("EntryFrontPort", Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.65, 0.0)), Vector3(4.0, 1.3, 0.16))
	_add_rail("EntryFrontStarboard", Transform3D(Basis.IDENTITY, Vector3(4.0, 0.65, 0.0)), Vector3(4.0, 1.3, 0.16))
	_add_rail("EntryPortForward", Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.65, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail("EntryStarboardForward", Transform3D(Basis.IDENTITY, Vector3(6.0, 0.65, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail("LowerOutboard", Transform3D(Basis.IDENTITY, Vector3(-18.0, 0.65, 8.0)), Vector3(0.16, 1.3, 12.0))
	_add_rail("LowerForward", Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.65, 2.0)), Vector3(12.0, 1.3, 0.16))
	_add_rail("LowerAft", Transform3D(Basis.IDENTITY, Vector3(-12.0, 0.65, 14.0)), Vector3(12.0, 1.3, 0.16))
	_add_rail("LowerInboardAft", Transform3D(Basis.IDENTITY, Vector3(-6.0, 0.65, 11.0)), Vector3(0.16, 1.3, 6.0))
	_add_sloped_rail("MainRampForward", Vector3(6.0, 0.0, 2.0), Vector3(14.0, 3.6, 2.0))
	_add_sloped_rail("MainRampAft", Vector3(6.0, 0.0, 8.0), Vector3(14.0, 3.6, 8.0))
	_add_rail("UpperOutboard", Transform3D(Basis.IDENTITY, Vector3(26.0, 4.25, 5.0)), Vector3(0.16, 1.3, 10.0))
	_add_rail("UpperForward", Transform3D(Basis.IDENTITY, Vector3(20.0, 4.25, 0.0)), Vector3(12.0, 1.3, 0.16))
	_add_rail("UpperAftPort", Transform3D(Basis.IDENTITY, Vector3(17.0, 4.25, 10.0)), Vector3(6.0, 1.3, 0.16))
	_add_rail("UpperInboardForward", Transform3D(Basis.IDENTITY, Vector3(14.0, 4.25, 1.0)), Vector3(0.16, 1.3, 2.0))
	_add_rail("UpperInboardAft", Transform3D(Basis.IDENTITY, Vector3(14.0, 4.25, 9.0)), Vector3(0.16, 1.3, 2.0))
	_add_sloped_rail("InspectionRampPort", Vector3(20.0, 3.6, 10.0), Vector3(20.0, 5.4, 14.0))
	_add_sloped_rail("InspectionRampStarboard", Vector3(26.0, 3.6, 10.0), Vector3(26.0, 5.4, 14.0))
	_add_rail("TopAft", Transform3D(Basis.IDENTITY, Vector3(23.0, 6.05, 18.0)), Vector3(6.0, 1.3, 0.16))
	_add_rail("TopPort", Transform3D(Basis.IDENTITY, Vector3(20.0, 6.05, 16.0)), Vector3(0.16, 1.3, 4.0))
	_add_rail("TopStarboard", Transform3D(Basis.IDENTITY, Vector3(26.0, 6.05, 16.0)), Vector3(0.16, 1.3, 4.0))


func _add_rail(node_name: String, transform: Transform3D, size: Vector3) -> void:
	var rail := _box_body(_build_root, node_name, transform, size, _materials.rail)
	rail.set_meta("safety_rail", true)
	var mesh := rail.get_node(^"Mesh") as MeshInstance3D
	mesh.set_meta("non_walkable_reason", "physical safety rail, not a route surface")
	_rail_nodes.append(rail)


func _add_sloped_rail(node_name: String, start: Vector3, finish: Vector3) -> void:
	var direction := finish - start
	var basis := _basis_with_local_back_along(direction)
	var transform := Transform3D(basis, (start + finish) * 0.5 + Vector3.UP * 0.65)
	_add_rail(node_name, transform, Vector3(0.16, 1.3, direction.length()))


func _build_batched_supports_and_dressing() -> void:
	var support_transforms: Array[Transform3D] = []
	for support in [
		Vector3(-16, -0.9, 4), Vector3(-16, -0.9, 12), Vector3(-8, -0.9, 4),
		Vector3(-8, -0.9, 12), Vector3(16, 1.8, 2), Vector3(24, 1.8, 2),
		Vector3(16, 1.8, 8), Vector3(24, 1.8, 8), Vector3(21, 4.5, 16),
		Vector3(25, 4.5, 16),
	]:
		support_transforms.append(Transform3D(Basis.IDENTITY, support as Vector3))
	_add_multimesh_batch("TerraceSupportBatch", Vector3(0.65, 1.8, 0.65), support_transforms, _materials.frame, "structural support below walkable decks")

	# Salvage cages sit outside the walkable union over the lower pad's aft/outboard
	# edge. They read as stored service stock without consuming route submissions.
	var salvage_transforms: Array[Transform3D] = []
	for position_value in [
		Vector3(-17.1, 0.65, 15.2), Vector3(-15.5, 0.65, 15.2),
		Vector3(-13.9, 0.65, 15.2), Vector3(16.0, 4.25, 11.0),
		Vector3(17.6, 4.25, 11.0), Vector3(19.2, 4.25, 11.0),
	]:
		salvage_transforms.append(Transform3D(Basis.IDENTITY, position_value as Vector3))
	_add_multimesh_batch("SalvageCageBatch", Vector3(1.3, 1.3, 1.3), salvage_transforms, _materials.salvage, "batched salvage cage outside every traversal corridor")

	var beacon_transforms: Array[Transform3D] = []
	for position_value in [Vector3(-17.5, 1.55, 2.4), Vector3(-17.5, 1.55, 13.6), Vector3(25.5, 5.15, 0.4), Vector3(25.5, 6.95, 17.6)]:
		beacon_transforms.append(Transform3D(Basis.IDENTITY, position_value as Vector3))
	_add_multimesh_batch("ServiceBeaconBatch", Vector3(0.22, 0.22, 0.22), beacon_transforms, _materials.emissive, "emissive route-edge marker with no dynamic light")

	# One outboard inspection gantry over void, intentionally collision-free and
	# outside the surface union. Its compact silhouette makes the service role read
	# without placing furniture in any route.
	_visual_box("InspectionGantryMast", Vector3(27.0, 3.0, 7.5), Vector3(0.45, 6.0, 0.45), _materials.frame, "outboard inspection gantry over void")
	_visual_box("InspectionGantryBoom", Vector3(24.5, 5.8, 7.5), Vector3(5.0, 0.35, 0.35), _materials.hazard, "overhead inspection boom outside capsule height")
	_visual_box("SuspendedSalvageClamp", Vector3(26.6, 5.0, 7.5), Vector3(0.8, 1.2, 0.8), _materials.salvage, "suspended service clamp beyond the upper terrace rail")


func _build_identity_sign() -> void:
	var sign_back := _visual_box("IdentitySignBack", Vector3(-5.7, 2.1, 0.5), Vector3(0.25, 1.6, 3.8), _materials.frame, "vertical identity sign outside the origin gate")
	sign_back.rotation.y = PI * 0.5
	var label := Label3D.new()
	label.name = "SalvageTerraceIdentity"
	label.text = "SALVAGE\nTERRACE"
	label.font_size = 52
	label.outline_size = 8
	label.modulate = Color("b9f4ee")
	label.outline_modulate = Color("10252b")
	label.position = Vector3(-5.82, 2.1, 0.5)
	label.rotation.y = PI * 0.5
	label.set_meta("non_walkable_reason", "bounded vertical area identity label")
	_build_root.add_child(label)


func _add_multimesh_batch(
		node_name: String,
		size: Vector3,
		transforms: Array[Transform3D],
		material: Material,
		reason: String
	) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = transforms.size()
	multimesh.mesh = mesh
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.set_meta("non_walkable_reason", reason)
	_build_root.add_child(batch)


func _box_body(
		parent: Node3D,
		node_name: String,
		transform: Transform3D,
		size: Vector3,
		material: Material
	) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = transform
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
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


func _create_materials() -> void:
	_materials["deck"] = _material(Color("334f59"), 0.68, 0.34)
	_materials["frame"] = _material(Color("172930"), 0.76, 0.3)
	_materials["rail"] = _material(Color("789097"), 0.7, 0.27)
	_materials["salvage"] = _material(Color("7a5132"), 0.42, 0.5)
	_materials["hazard"] = _material(Color("dc7f2d"), 0.28, 0.38)
	_materials["emissive"] = _material(Color("76e6dc"), 0.12, 0.25, Color("36c9c2"), 1.2)
	for key in ["deck", "frame", "rail", "salvage"]:
		StationSurfaceKit.apply_panel_triplanar(_materials[key] as StandardMaterial3D, 0.3)


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
	if batches.size() != 3:
		return false
	for raw_batch in batches:
		var batch := raw_batch as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.instance_count <= 0:
			return false
		if str(batch.get_meta("non_walkable_reason", "")).is_empty():
			return false
	# All three free-standing visual boxes are above/outboard of the declared
	# centreline corridors; their exact transforms are held by the build contract.
	return true


func _capture_built_contract() -> void:
	_built_node_ids.clear()
	_built_node_transforms.clear()
	for candidate in find_children("*", "", true, false):
		var path := str(get_path_to(candidate))
		_built_node_ids[path] = candidate.get_instance_id()
		if candidate is Node3D:
			_built_node_transforms[path] = (candidate as Node3D).transform


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
	set_meta("source_bounded", true)
	set_meta("authenticated_original_geometry", false)
	set_meta("owns_ship_authority", false)
	set_meta("owns_berth_authority", false)
	set_meta("owns_combat_authority", false)
	set_meta("owns_activity_authority", false)
	set_meta("horizontal_walkable_area_m2", HORIZONTAL_WALKABLE_AREA_M2)
	set_meta("content_note", CONTENT_NOTE)
	add_to_group(&"station_modules")
	add_to_group(&"source_bounded_station_modules")
