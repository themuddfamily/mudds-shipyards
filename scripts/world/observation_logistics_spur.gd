class_name ObservationLogisticsSpur
extends Node3D

## Standalone NEW station expansion: a long exposed connector feeding two
## separated pads whose far bridge closes a second return path.
##
## Nothing here is reconstructed. The layout, dimensions, station function,
## fittings and adjacency are project-original modern interpretation. The module
## deliberately owns no berth, interaction, activity, audio, spawn, lease or
## network authority.

const SCHEMA_VERSION := 1
const MODULE_ID: StringName = &"observation-logistics-spur"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD

const ORIGIN_SLOT: StringName = &"observation-logistics-spur-origin"
const DEFERRED_CONNECTION_ROUTE_IDS := [&"observation-pad", &"logistics-pad"]

const FOOTPRINT_MIN := Vector3(-13.4, -0.3, 0.0)
const FOOTPRINT_MAX := Vector3(13.4, 4.4, 39.5)
const WALKABLE_AREA_M2 := 426.0
## This is the first source-current, production-integrated continuation of the
## exposed deck language beyond the bounded historical modules.  The report is
## intentionally an evidence gate rather than a topology claim: it freezes the
## sparse, separated-deck composition and makes the void/safety rules auditable
## before another exposed module is allowed to grow the station footprint.
const SAFETY_RAIL_COUNT := 15
const FOOTPRINT_HORIZONTAL_AREA_M2 := 1058.6
const NEGATIVE_SPACE_RATIO := 0.597586611

## The five rectangles touch at their boundaries without overlapping in plan,
## so their exact union equals the sum of their horizontal areas: 88 + 80 + 120
## + 120 + 18 = 426 m².
const WALKABLE_SURFACE_SPECS := [
	{
		"id": &"exposed-connector",
		"node_name": "ExposedConnectorDeck",
		"center": Vector3(0.0, -0.15, 11.0),
		"size": Vector3(4.0, 0.30, 22.0),
		"area_m2": 88.0,
	},
	{
		"id": &"pad-cross-landing",
		"node_name": "PadCrossLanding",
		"center": Vector3(0.0, -0.15, 24.0),
		"size": Vector3(20.0, 0.30, 4.0),
		"area_m2": 80.0,
	},
	{
		"id": &"observation-pad",
		"node_name": "ObservationPad",
		"center": Vector3(-8.0, -0.15, 32.0),
		"size": Vector3(10.0, 0.30, 12.0),
		"area_m2": 120.0,
	},
	{
		"id": &"logistics-pad",
		"node_name": "LogisticsPad",
		"center": Vector3(8.0, -0.15, 32.0),
		"size": Vector3(10.0, 0.30, 12.0),
		"area_m2": 120.0,
	},
	{
		"id": &"far-return-bridge",
		"node_name": "FarReturnBridge",
		"center": Vector3(0.0, -0.15, 38.0),
		"size": Vector3(6.0, 0.30, 3.0),
		"area_m2": 18.0,
	},
]

const CONNECTION_SLOT_SPECS := {
	&"origin": {
		"slot_id": ORIGIN_SLOT,
		"local_transform": Transform3D(Basis.IDENTITY, Vector3.ZERO),
	},
}

## Repeated authored families must keep readable, stable runtime paths. Godot's
## default duplicate-name fallback uses transient `@Type@id` names, so every
## repeated copy is indexed at authoring time and frozen here for audit.
const INDEXED_RUNTIME_CHILD_PATHS := [
	"Structure/SafetyRails/ConnectorRail01",
	"Structure/SafetyRails/ConnectorRail02",
	"Structure/SafetyRails/PadOuterRail01",
	"Structure/SafetyRails/PadInnerRail01",
	"Structure/SafetyRails/PadFarRail01",
	"Structure/SafetyRails/PadOuterRail02",
	"Structure/SafetyRails/PadInnerRail02",
	"Structure/SafetyRails/PadFarRail02",
	"Structure/Dressing/ObservationConsole01",
	"Structure/Dressing/ObservationLens01",
	"Structure/Dressing/ObservationConsole02",
	"Structure/Dressing/ObservationLens02",
	"Structure/Dressing/ObservationConsole03",
	"Structure/Dressing/ObservationLens03",
	"Structure/Dressing/LogisticsPallet01",
	"Structure/Dressing/LogisticsCase01",
	"Structure/Dressing/LogisticsCase02",
	"Structure/Dressing/LogisticsPallet02",
	"Structure/Dressing/LogisticsCase03",
	"Structure/Dressing/LogisticsCase04",
	"Structure/Dressing/LogisticsPallet03",
	"Structure/Dressing/LogisticsCase05",
	"Structure/Dressing/LogisticsCase06",
	"Structure/Dressing/LightMast01",
	"Structure/Dressing/LightLens01",
	"Structure/Dressing/LightMast02",
	"Structure/Dressing/LightLens02",
	"Structure/Dressing/LightMast03",
	"Structure/Dressing/LightLens03",
	"Structure/Dressing/LightMast04",
	"Structure/Dressing/LightLens04",
	"Structure/Dressing/LightMast05",
	"Structure/Dressing/LightLens05",
	"Structure/Dressing/LightMast06",
	"Structure/Dressing/LightLens06",
]

## Visual-only observation lenses retain their stable authored paths as empty
## anchors while one bounded renderer draws the three exact copies.
const OBSERVATION_LENS_SIZE := Vector3(0.035, 0.26, 0.92)
const OBSERVATION_LENS_POSITIONS := [
	Vector3(-11.05, 0.76, 28.6),
	Vector3(-11.05, 0.76, 31.4),
	Vector3(-11.05, 0.76, 34.2),
]
const OBSERVATION_LENS_CULLING_BOUNDS := AABB(
	Vector3(-11.0675, 0.63, 28.14), Vector3(0.035, 0.26, 6.52)
)
const BASELINE_VISUAL_DESCENDANT_NODE_COUNT := 133
const VISUAL_DESCENDANT_NODE_COUNT := 143
const BASELINE_RENDERER_NODE_COUNT := 46
const RENDERER_NODE_COUNT := 44
const BASELINE_DRAWN_COPY_COUNT := 232
const DRAWN_COPY_COUNT := 270
const BASELINE_SURFACE_SUBMISSION_COUNT := 46
const SURFACE_SUBMISSION_COUNT := 44
const BASELINE_MESH_RESOURCE_COUNT := 46
const MESH_RESOURCE_COUNT := 34
const BASELINE_MATERIAL_RESOURCE_COUNT := 9
const MATERIAL_RESOURCE_COUNT := 10
const BASELINE_OBSERVATION_LENS_MESH_RESOURCE_COUNT := 3
const OBSERVATION_LENS_MESH_RESOURCE_COUNT := 1
const OBSERVATION_LENS_COPY_COUNT := 3
const BASELINE_OBSERVATION_LENS_RENDERER_NODE_COUNT := 3
const OBSERVATION_LENS_RENDERER_NODE_COUNT := 1
const OBSERVATION_CONSOLE_SIZE := Vector3(0.72, 0.96, 1.35)
const OBSERVATION_CONSOLE_POSITIONS := [
	Vector3(-11.45, 0.48, 28.6),
	Vector3(-11.45, 0.48, 31.4),
	Vector3(-11.45, 0.48, 34.2),
]
const OBSERVATION_CONSOLE_CULLING_BOUNDS := AABB(
	Vector3(-11.81, 0.0, 27.925), Vector3(0.72, 0.96, 6.95)
)
const OBSERVATION_CONSOLE_COPY_COUNT := 3
const BASELINE_OBSERVATION_CONSOLE_RENDERER_NODE_COUNT := 3
const OBSERVATION_CONSOLE_RENDERER_NODE_COUNT := 1
const PRACTICAL_LENS_SIZE := Vector3(0.28, 0.12, 0.28)
const PRACTICAL_LENS_COPY_COUNT := 6
const PRACTICAL_LENS_MESH_RESOURCE_COUNT := 1
const LOGISTICS_CASE_SIZE := Vector3(2.1, 0.52, 1.28)
const LOGISTICS_CASE_COPY_COUNT := 6
const LOGISTICS_CASE_MESH_RESOURCE_COUNT := 1
const LIGHT_MAST_SIZE := Vector3(0.16, 2.8, 0.16)
const LIGHT_MAST_POSITIONS := [
	Vector3(2.32, 1.4, 7.0),
	Vector3(-2.32, 1.4, 18.0),
	Vector3(-9.55, 1.4, 23.5),
	Vector3(-12.72, 1.4, 32.0),
	Vector3(12.72, 1.4, 32.0),
	Vector3(2.72, 1.4, 38.0),
]
const LIGHT_MAST_COPY_COUNT := 6
const BASELINE_LIGHT_MAST_RENDERER_NODE_COUNT := 6
const LIGHT_MAST_RENDERER_NODE_COUNT := 1
const BASELINE_LIGHT_MAST_MESH_RESOURCE_COUNT := 6
const LIGHT_MAST_MESH_RESOURCE_COUNT := 1

const CONTENT_NOTE := (
	"NEW project-original station content. No source establishes an observation/logistics "
	+ "spur, these functions, this exposed 24 m approach, two-pad plan, alternate return "
	+ "bridge, dimensions, materials, fittings, or adjacency. Every authored claim is "
	+ "modern_interpretation and no historical reconstruction is asserted."
)

@onready var _module_anchor: Marker3D = %ModuleAnchor
@onready var _origin_connection: Marker3D = %OriginConnection
@onready var _connector_midpoint: Marker3D = %ConnectorMidpoint
@onready var _cross_landing: Marker3D = %CrossLanding
@onready var _observation_pad: Marker3D = %ObservationPadMarker
@onready var _logistics_pad: Marker3D = %LogisticsPadMarker
@onready var _far_return: Marker3D = %FarReturn

var _materials: Dictionary = {}
var _observation_lens_mesh: BoxMesh
var _practical_lens_mesh: BoxMesh
## Immutable visual resource only; every named case retains its StaticBody3D
## and CollisionShape3D while the six identical cargo-case renderers share it.
var _logistics_case_mesh: BoxMesh
var _route_markers: Dictionary = {}
var _walkable_surfaces: Array[StaticBody3D] = []
var _visible_rail_bar_transforms: Array[Transform3D] = []
var _visible_rail_post_transforms: Array[Transform3D] = []
var _built := false
var _module_enabled := true


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	if not _built:
		_built = true
		_create_materials()
		_index_routes()
		_build_module()
		_apply_metadata()
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


func get_connection_slots() -> Dictionary:
	var result := {}
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		result[route_id] = {
			"slot_id": StringName(spec.slot_id),
			"local_transform": (spec.local_transform as Transform3D),
			"world_transform": global_transform * (spec.local_transform as Transform3D),
		}
	return result.duplicate(true)


func get_walkable_surface_roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		result.append({
			"surface_id": StringName(spec.id),
			"node_name": str(spec.node_name),
			"local_center": spec.center as Vector3,
			"size": spec.size as Vector3,
			"horizontal_area_m2": float(spec.area_m2),
			"kind": &"level",
		})
	return result.duplicate(true)


func get_walkable_area_m2() -> float:
	return WALKABLE_AREA_M2


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
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": false,
		"references": PackedStringArray(),
		"content_note": CONTENT_NOTE,
		"supported_invariants": PackedStringArray(),
		"modern_interpretations": PackedStringArray([
			"the complete module and its location",
			"observation and logistics functions",
			"all geometry, dimensions, materials, fittings, lighting and dressing",
		]),
	}


func get_component_roster() -> Dictionary:
	var roster := StationModuleContract.build_component_roster(self)
	roster["schema_version"] = SCHEMA_VERSION
	roster["module_id"] = MODULE_ID
	roster["walkable_surface_count"] = _walkable_surfaces.size()
	roster["walkable_area_m2"] = WALKABLE_AREA_M2
	roster["connection_slot_count"] = CONNECTION_SLOT_SPECS.size()
	return roster


func get_collision_contract() -> Dictionary:
	var contract := StationModuleContract.build_collision_contract(self, WORLD_LAYER, _module_enabled)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_authority_contract() -> Dictionary:
	var contract := StationModuleContract.build_authority_contract(self)
	contract["schema_version"] = SCHEMA_VERSION
	return contract


func get_performance_contract() -> Dictionary:
	# Exact standalone build census, frozen rather than estimated: 143 descendant
	# nodes, 21 MeshInstance3D nodes plus twenty-three visual-only MultiMesh batches,
	# 33 bodies/shapes, four Label3Ds and six practicals. The fifteen conservative
	# safety volumes deliberately retain collision shapes but no solid renderer.
	# owns no processing callback. The practical lenses reuse three exact recipes,
	# reducing repeated practical recipes while retaining one dedicated dark view
	# band material for the two perimeter pavilions.
	# Any later content must declare its cost here.
	var contract := StationModuleContract.build_performance_contract(self, {
		"mesh_instances": 21,
		"static_bodies": 33,
		"collision_shapes": 33,
		"labels": 4,
		"lights": 6,
		"process_loops": 0,
		"physics_process_loops": 0,
	})
	contract["schema_version"] = SCHEMA_VERSION
	contract["visual_resources"] = get_visual_resource_contract()
	return contract


## Headless-safe component-local allocation census. Stable authored paths,
## visible copies/transforms, materials, collision and lifecycle behavior stay
## fixed while repeated presentation-only renderers may be batched.
func get_visual_resource_contract() -> Dictionary:
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

	var lens_batch := get_node_or_null(
		^"Structure/Dressing/ObservationLensRenderBatch"
	) as MultiMeshInstance3D
	var lens_mesh_resource_ids := {}
	var lens_identities_exact := lens_batch != null and is_instance_valid(_observation_lens_mesh)
	var authored_lens_transforms: Array = []
	var expected_lens_transforms: Array[Transform3D] = []
	for lens_position in OBSERVATION_LENS_POSITIONS:
		expected_lens_transforms.append(Transform3D(Basis.IDENTITY, lens_position))
	if lens_batch != null and lens_batch.multimesh != null:
		var lens_mesh := lens_batch.multimesh.mesh as BoxMesh
		if lens_mesh != null:
			lens_mesh_resource_ids[lens_mesh.get_instance_id()] = true
		authored_lens_transforms = lens_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		lens_identities_exact = (
			lens_identities_exact
			and lens_mesh == _observation_lens_mesh
			and lens_mesh.size.is_equal_approx(OBSERVATION_LENS_SIZE)
			and lens_batch.material_override == _materials.get("cyan")
			and lens_batch.transform.is_equal_approx(Transform3D.IDENTITY)
			and lens_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and lens_batch.layers == 1
			and is_zero_approx(lens_batch.extra_cull_margin)
			and not lens_batch.ignore_occlusion_culling
			and is_zero_approx(lens_batch.visibility_range_begin)
			and is_zero_approx(lens_batch.visibility_range_end)
			and lens_batch.visibility_range_fade_mode
				== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			and lens_batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
			and lens_batch.multimesh.instance_count == OBSERVATION_LENS_COPY_COUNT
			and lens_batch.multimesh.visible_instance_count == OBSERVATION_LENS_COPY_COUNT
			and lens_batch.multimesh.buffer == _encode_multimesh_transforms(
				expected_lens_transforms
			)
			and lens_batch.multimesh.custom_aabb.is_equal_approx(
				OBSERVATION_LENS_CULLING_BOUNDS
			)
			and authored_lens_transforms.size() == OBSERVATION_LENS_COPY_COUNT
			and bool(lens_batch.get_meta("visual_detail_only", false))
		)
	else:
		lens_identities_exact = false
	for lens_index in OBSERVATION_LENS_COPY_COUNT:
		var lens_anchor := get_node_or_null(NodePath(
			"Structure/Dressing/ObservationLens%02d" % (lens_index + 1)
		)) as Marker3D
		var expected_transform := Transform3D(
			Basis.IDENTITY, OBSERVATION_LENS_POSITIONS[lens_index]
		)
		lens_identities_exact = (
			lens_identities_exact
			and lens_anchor != null
			and lens_anchor.position.is_equal_approx(OBSERVATION_LENS_POSITIONS[lens_index])
			and lens_anchor.get_child_count() == 0
			and bool(lens_anchor.get_meta("visual_detail_only", false))
			and bool(lens_anchor.get_meta("batched_visual_anchor", false))
			and authored_lens_transforms[lens_index] is Transform3D
			and (authored_lens_transforms[lens_index] as Transform3D).is_equal_approx(
				expected_transform
			)
		)
	var console_batch := get_node_or_null(
		^"Structure/Dressing/ObservationConsoleRenderBatch"
	) as MultiMeshInstance3D
	var console_mesh_resource_ids := {}
	var authored_console_transforms: Array = []
	var console_identities_exact := console_batch != null and console_batch.multimesh != null
	var expected_console_transforms: Array[Transform3D] = []
	for console_position in OBSERVATION_CONSOLE_POSITIONS:
		expected_console_transforms.append(Transform3D(Basis.IDENTITY, console_position))
	if console_identities_exact:
		var console_mesh := console_batch.multimesh.mesh as BoxMesh
		if console_mesh != null:
			console_mesh_resource_ids[console_mesh.get_instance_id()] = true
		authored_console_transforms = console_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		console_identities_exact = (
			console_mesh != null
			and console_mesh.size.is_equal_approx(OBSERVATION_CONSOLE_SIZE)
			and console_batch.material_override == _materials.get("shell")
			and console_batch.transform.is_equal_approx(Transform3D.IDENTITY)
			and console_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and console_batch.layers == 1
			and is_zero_approx(console_batch.extra_cull_margin)
			and not console_batch.ignore_occlusion_culling
			and is_zero_approx(console_batch.visibility_range_begin)
			and is_zero_approx(console_batch.visibility_range_end)
			and console_batch.visibility_range_fade_mode
				== GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			and console_batch.multimesh.transform_format == MultiMesh.TRANSFORM_3D
			and console_batch.multimesh.instance_count == OBSERVATION_CONSOLE_COPY_COUNT
			and console_batch.multimesh.visible_instance_count == OBSERVATION_CONSOLE_COPY_COUNT
			and console_batch.multimesh.buffer == _encode_multimesh_transforms(
				expected_console_transforms
			)
			and console_batch.multimesh.custom_aabb.is_equal_approx(
				OBSERVATION_CONSOLE_CULLING_BOUNDS
			)
			and authored_console_transforms.size() == OBSERVATION_CONSOLE_COPY_COUNT
			and bool(console_batch.get_meta("visual_detail_only", false))
		)
	for console_index in OBSERVATION_CONSOLE_COPY_COUNT:
		var console_body := get_node_or_null(NodePath(
			"Structure/Dressing/ObservationConsole%02d" % (console_index + 1)
		)) as StaticBody3D
		var console_anchor := (
			console_body.get_node_or_null(^"Mesh") as Marker3D
			if console_body != null else null
		)
		var collision := (
			console_body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
			if console_body != null else null
		)
		console_identities_exact = (
			console_identities_exact
			and console_body != null
			and console_body.position.is_equal_approx(OBSERVATION_CONSOLE_POSITIONS[console_index])
			and console_anchor != null
			and console_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
			and console_anchor.get_child_count() == 0
			and bool(console_anchor.get_meta("visual_detail_only", false))
			and bool(console_anchor.get_meta("batched_visual_anchor", false))
			and collision != null
			and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(OBSERVATION_CONSOLE_SIZE)
			and authored_console_transforms.size() == OBSERVATION_CONSOLE_COPY_COUNT
			and (authored_console_transforms[console_index] as Transform3D).is_equal_approx(
				expected_console_transforms[console_index]
			)
		)
	var practical_lens_mesh_resource_ids := {}
	var practical_lens_identities_exact := is_instance_valid(_practical_lens_mesh)
	for lens_index in PRACTICAL_LENS_COPY_COUNT:
		var lens := get_node_or_null(NodePath(
			"Structure/Dressing/LightLens%02d" % (lens_index + 1)
		)) as MeshInstance3D
		if lens == null or lens.mesh == null:
			practical_lens_identities_exact = false
			continue
		practical_lens_mesh_resource_ids[lens.mesh.get_instance_id()] = true
		practical_lens_identities_exact = (
			practical_lens_identities_exact
			and lens.mesh == _practical_lens_mesh
			and (lens.mesh as BoxMesh).size.is_equal_approx(PRACTICAL_LENS_SIZE)
			and lens.get_child_count() == 0
			and bool(lens.get_meta("visual_detail_only", false))
		)
	var logistics_case_mesh_resource_ids := {}
	var logistics_case_identities_exact := is_instance_valid(_logistics_case_mesh)
	for case_index in LOGISTICS_CASE_COPY_COUNT:
		var case_body := get_node_or_null(NodePath(
			"Structure/Dressing/LogisticsCase%02d" % (case_index + 1)
		)) as StaticBody3D
		var case_mesh := (
			case_body.get_node_or_null("Mesh") as MeshInstance3D
			if case_body != null else null
		)
		if case_mesh == null or case_mesh.mesh == null:
			logistics_case_identities_exact = false
			continue
		logistics_case_mesh_resource_ids[case_mesh.mesh.get_instance_id()] = true
		logistics_case_identities_exact = (
			logistics_case_identities_exact
			and case_mesh.mesh == _logistics_case_mesh
			and (case_mesh.mesh as BoxMesh).size.is_equal_approx(LOGISTICS_CASE_SIZE)
			and case_mesh.material_override == _materials.get("cargo")
			and case_mesh.get_parent() == case_body
			and case_body.get_node_or_null("CollisionShape3D") is CollisionShape3D
		)

	var light_mast_batch := get_node_or_null(
		^"Structure/Dressing/LightMastRenderBatch"
	) as MultiMeshInstance3D
	var light_mast_identities_exact := light_mast_batch != null
	var light_mast_mesh_resource_ids := {}
	var authored_mast_transforms: Array = []
	if light_mast_batch != null and light_mast_batch.multimesh != null:
		var mast_mesh := light_mast_batch.multimesh.mesh as BoxMesh
		if mast_mesh != null:
			light_mast_mesh_resource_ids[mast_mesh.get_instance_id()] = true
		authored_mast_transforms = light_mast_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		light_mast_identities_exact = (
			light_mast_identities_exact
			and mast_mesh != null
			and mast_mesh.size.is_equal_approx(LIGHT_MAST_SIZE)
			and light_mast_batch.material_override == _materials.get("rail")
			and light_mast_batch.multimesh.instance_count == LIGHT_MAST_COPY_COUNT
			and authored_mast_transforms.size() == LIGHT_MAST_COPY_COUNT
			and bool(light_mast_batch.get_meta("visual_detail_only", false))
		)
	else:
		light_mast_identities_exact = false
	for mast_index in LIGHT_MAST_COPY_COUNT:
		var mast_anchor := get_node_or_null(NodePath(
			"Structure/Dressing/LightMast%02d" % (mast_index + 1)
		)) as Marker3D
		var expected_transform := Transform3D(Basis.IDENTITY, LIGHT_MAST_POSITIONS[mast_index])
		light_mast_identities_exact = (
			light_mast_identities_exact
			and mast_anchor != null
			and mast_anchor.position.is_equal_approx(LIGHT_MAST_POSITIONS[mast_index])
			and mast_anchor.get_child_count() == 0
			and bool(mast_anchor.get_meta("visual_detail_only", false))
			and bool(mast_anchor.get_meta("batched_visual_anchor", false))
			and authored_mast_transforms[mast_index] is Transform3D
			and (authored_mast_transforms[mast_index] as Transform3D).is_equal_approx(
				expected_transform
			)
		)

	var descendant_nodes := find_children("*", "Node", true, false).size()
	var renderer_nodes := mesh_nodes.size() + batch_nodes.size()
	var exact := (
		descendant_nodes == VISUAL_DESCENDANT_NODE_COUNT
		and renderer_nodes == RENDERER_NODE_COUNT
		and drawn_copies == DRAWN_COPY_COUNT
		and surface_submissions == SURFACE_SUBMISSION_COUNT
		and mesh_resource_ids.size() == MESH_RESOURCE_COUNT
		and material_resource_ids.size() == MATERIAL_RESOURCE_COUNT
		and lens_mesh_resource_ids.size() == OBSERVATION_LENS_MESH_RESOURCE_COUNT
		and lens_identities_exact
		and console_mesh_resource_ids.size() == 1
		and console_identities_exact
		and practical_lens_mesh_resource_ids.size() == PRACTICAL_LENS_MESH_RESOURCE_COUNT
		and practical_lens_identities_exact
		and logistics_case_mesh_resource_ids.size() == LOGISTICS_CASE_MESH_RESOURCE_COUNT
		and logistics_case_identities_exact
		and light_mast_mesh_resource_ids.size() == LIGHT_MAST_MESH_RESOURCE_COUNT
		and light_mast_identities_exact
	)
	return {
		"exact": exact,
		"headless_safe": true,
		"scope": &"ObservationLogisticsSpur_static_visuals",
		"selected_family": &"observation_console_render_batch",
		"baseline_descendant_nodes": BASELINE_VISUAL_DESCENDANT_NODE_COUNT,
		"descendant_nodes": descendant_nodes,
		"baseline_renderer_nodes": BASELINE_RENDERER_NODE_COUNT,
		"renderer_nodes": renderer_nodes,
		"baseline_drawn_copies": BASELINE_DRAWN_COPY_COUNT,
		"drawn_copies": drawn_copies,
		"baseline_surface_submissions": BASELINE_SURFACE_SUBMISSION_COUNT,
		"surface_submissions": surface_submissions,
		"baseline_mesh_resources": BASELINE_MESH_RESOURCE_COUNT,
		"mesh_resources": mesh_resource_ids.size(),
		"mesh_resource_delta": mesh_resource_ids.size() - BASELINE_MESH_RESOURCE_COUNT,
		"baseline_material_resources": BASELINE_MATERIAL_RESOURCE_COUNT,
		"material_resources": material_resource_ids.size(),
		"baseline_family_nodes": BASELINE_OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"family_nodes": OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"baseline_family_submissions": BASELINE_OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"family_submissions": OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"baseline_family_mesh_resources": OBSERVATION_CONSOLE_COPY_COUNT,
		"family_mesh_resources": console_mesh_resource_ids.size(),
		"family_copies": OBSERVATION_CONSOLE_COPY_COUNT,
		"family_identities_exact": console_identities_exact,
		"observation_lens_anchor_nodes": OBSERVATION_LENS_COPY_COUNT,
		"baseline_observation_lens_renderer_nodes": BASELINE_OBSERVATION_LENS_RENDERER_NODE_COUNT,
		"observation_lens_renderer_nodes": OBSERVATION_LENS_RENDERER_NODE_COUNT,
		"observation_lens_renderer_delta": (
			OBSERVATION_LENS_RENDERER_NODE_COUNT
			- BASELINE_OBSERVATION_LENS_RENDERER_NODE_COUNT
		),
		"observation_lens_culling_bounds": (
			lens_batch.multimesh.custom_aabb
			if lens_batch != null and lens_batch.multimesh != null else AABB()
		),
		"observation_lens_identities_exact": lens_identities_exact,
		"baseline_observation_console_renderer_nodes": BASELINE_OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"observation_console_renderer_nodes": OBSERVATION_CONSOLE_RENDERER_NODE_COUNT,
		"observation_console_renderer_delta": (
			OBSERVATION_CONSOLE_RENDERER_NODE_COUNT
			- BASELINE_OBSERVATION_CONSOLE_RENDERER_NODE_COUNT
		),
		"observation_console_copies": OBSERVATION_CONSOLE_COPY_COUNT,
		"observation_console_mesh_resources": console_mesh_resource_ids.size(),
		"observation_console_identities_exact": console_identities_exact,
		"practical_lens_copies": PRACTICAL_LENS_COPY_COUNT,
		"practical_lens_mesh_resources": practical_lens_mesh_resource_ids.size(),
		"practical_lens_identities_exact": practical_lens_identities_exact,
		"logistics_case_copies": LOGISTICS_CASE_COPY_COUNT,
		"logistics_case_mesh_resources": logistics_case_mesh_resource_ids.size(),
		"logistics_case_identities_exact": logistics_case_identities_exact,
		"baseline_light_mast_renderer_nodes": BASELINE_LIGHT_MAST_RENDERER_NODE_COUNT,
		"light_mast_renderer_nodes": LIGHT_MAST_RENDERER_NODE_COUNT,
		"light_mast_renderer_delta": (
			LIGHT_MAST_RENDERER_NODE_COUNT - BASELINE_LIGHT_MAST_RENDERER_NODE_COUNT
		),
		"light_mast_copies": LIGHT_MAST_COPY_COUNT,
		"baseline_light_mast_mesh_resources": BASELINE_LIGHT_MAST_MESH_RESOURCE_COUNT,
		"light_mast_mesh_resources": light_mast_mesh_resource_ids.size(),
		"light_mast_mesh_resource_delta": (
			light_mast_mesh_resource_ids.size() - BASELINE_LIGHT_MAST_MESH_RESOURCE_COUNT
		),
		"light_mast_identities_exact": light_mast_identities_exact,
	}.duplicate(true)


func get_exposed_lattice_language_contract() -> Dictionary:
	"""Return the bounded, evidence-aware contract for this exposed expansion.

	The module is a player-visible continuation (connector, separated pads and a
	return bridge), but it must not be mistaken for recovered station topology.
	All geometry and function remain NEW/modern interpretation; future additions
	must preserve the measured void ratio, real deck collision and fall-protection
	edge rule or provide a new evidence-backed contract.
	"""
	var rail_count := 0
	for candidate in find_children("*", "StaticBody3D", true, false):
		if bool(candidate.get_meta("station_safety_edge", false)):
			rail_count += 1
	return {
		"schema_version": 1,
		"player_visible_outcome": "walk a narrow exposed connector across separated decks and return over the far bridge",
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": false,
		"evidence_gate": "modern_interpretation_only_until_new_source_resolves_adjacency_and_scale",
		"walkable_surface_ids": PackedStringArray(["exposed-connector", "pad-cross-landing", "observation-pad", "logistics-pad", "far-return-bridge"]),
		"walkable_surface_count": WALKABLE_SURFACE_SPECS.size(),
		"walkable_area_m2": WALKABLE_AREA_M2,
		"footprint_horizontal_area_m2": FOOTPRINT_HORIZONTAL_AREA_M2,
		"negative_space_ratio": NEGATIVE_SPACE_RATIO,
		"negative_space_preserved": is_equal_approx(1.0 - WALKABLE_AREA_M2 / FOOTPRINT_HORIZONTAL_AREA_M2, NEGATIVE_SPACE_RATIO),
		"safety_rail_count": rail_count,
		"safety_edges_complete": rail_count == SAFETY_RAIL_COUNT,
		"owns_gameplay_authority": false,
		"future_expansion_rule": "do not fill deliberate voids, widen decks, or infer historical adjacency from this module",
	}.duplicate(true)


func get_material_retention_contract() -> Dictionary:
	var retained_ids := {}
	for candidate in find_children("*", "", true, false):
		if candidate is GeometryInstance3D:
			var material := (candidate as GeometryInstance3D).material_override
			if material != null:
				retained_ids[material.get_instance_id()] = true
	var lens_material_ids := PackedInt64Array()
	for fixture_index in 6:
		var lens := get_node_or_null(NodePath(
			"Structure/Dressing/LightLens%02d" % (fixture_index + 1)
		)) as MeshInstance3D
		lens_material_ids.append(
			lens.material_override.get_instance_id()
			if lens != null and lens.material_override != null else 0
		)
	var expected_lens_ids := PackedInt64Array([
		(_materials["practical_cyan"] as Material).get_instance_id(),
		(_materials["practical_cyan"] as Material).get_instance_id(),
		(_materials["practical_white"] as Material).get_instance_id(),
		(_materials["practical_cyan"] as Material).get_instance_id(),
		(_materials["practical_amber"] as Material).get_instance_id(),
		(_materials["practical_white"] as Material).get_instance_id(),
	])
	var practical_recipe_ids := {}
	for material_id in lens_material_ids:
		practical_recipe_ids[material_id] = true
	return {
		"catalog_entry_count": _materials.size(),
		"retained_unique_materials": retained_ids.size(),
		"practical_lens_recipe_count": practical_recipe_ids.size(),
		"practical_lens_material_ids": lens_material_ids,
		"expected_practical_lens_material_ids": expected_lens_ids,
		"practical_lens_identities_exact": lens_material_ids == expected_lens_ids,
	}


func set_module_enabled(enabled: bool) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_module_enabled = enabled
	_apply_enabled_state()


func is_module_enabled() -> bool:
	return _module_enabled


func get_lifecycle_contract() -> Dictionary:
	var contract := StationModuleContract.build_lifecycle_contract(
		self, WORLD_LAYER, _module_enabled, self
	)
	contract["schema_version"] = SCHEMA_VERSION
	contract["built"] = _built
	contract["build_generation"] = 1
	return contract


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _module_anchor == null or not _module_anchor.global_transform.is_finite():
		errors.append("module anchor is missing or non-finite")
	if _route_markers.size() != 6:
		errors.append("route registry must expose exactly six loop waypoints")
	if _walkable_surfaces.size() != WALKABLE_SURFACE_SPECS.size():
		errors.append("walkable surface roster must contain exactly five bodies")
	var area := 0.0
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		area += float(spec.area_m2)
		var body := get_node_or_null(NodePath("Structure/Walkable/%s" % str(spec.node_name))) as StaticBody3D
		if body == null:
			errors.append("walkable surface is missing: %s" % str(spec.id))
			continue
		if StringName(body.get_meta("walkable_surface_id", &"")) != StringName(spec.id) \
				or StringName(body.get_meta("walkable_surface_kind", &"")) != &"level" \
				or not bool(body.get_meta("walkable_surface", false)):
			errors.append("walkable surface metadata drifted: %s" % str(spec.id))
		if not body.position.is_equal_approx(spec.center as Vector3):
			errors.append("walkable surface transform drifted: %s" % str(spec.id))
		var shape := body.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		if box == null or not box.size.is_equal_approx(spec.size as Vector3):
			errors.append("walkable surface extent drifted: %s" % str(spec.id))
	if not is_equal_approx(area, WALKABLE_AREA_M2):
		errors.append("walkable surface area roster no longer totals exactly 426 m2")
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var marker := get_route_marker(route_id)
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		if marker == null \
				or not marker.transform.is_equal_approx(spec.local_transform as Transform3D) \
			or StationModuleContract.new().read_connection_slot_id(marker) != StringName(spec.slot_id):
			errors.append("connection slot transform or identity drifted: %s" % route_id)
	for route_id: StringName in DEFERRED_CONNECTION_ROUTE_IDS:
		var marker := get_route_marker(route_id)
		if marker == null \
				or not bool(marker.get_meta("deferred_connection_route", false)) \
				or StringName(marker.get_meta("connection_status", &"")) != &"internal_route_only_no_geometry" \
				or StationModuleContract.new().read_connection_slot_id(marker) != &"":
			errors.append("deferred internal route incorrectly claims a connection slot: %s" % route_id)
	var authority := get_authority_contract()
	if not (authority.authority_ids as PackedStringArray).is_empty() \
			or int(authority.ship_berth_count) != 0 \
			or int(authority.landing_or_interaction_area_count) != 0 \
			or int(authority.audio_node_count) != 0 \
			or int(authority.activity_node_count) != 0 \
			or int(authority.lease_authority_count) != 0 \
			or int(authority.spawn_authority_count) != 0 \
			or StringName(authority.network_authority_role) != &"none":
		errors.append("standalone spur must own zero gameplay authorities")
	var collision := get_collision_contract()
	if not bool(collision.all_layers_match_lifecycle) \
			or not bool(collision.all_masks_zero) \
			or not bool(collision.all_shapes_present_and_enabled):
		errors.append("collision contract does not match lifecycle")
	if not bool(get_performance_contract().within_budget):
		errors.append("module exceeds its frozen performance budgets")
	if not bool(get_visual_resource_contract().exact):
		errors.append("static visual resource or batching contract drifted")
	var materials := get_material_retention_contract()
	if int(materials.catalog_entry_count) != 10 \
			or int(materials.retained_unique_materials) != 10 \
			or int(materials.practical_lens_recipe_count) != 3 \
			or not bool(materials.practical_lens_identities_exact):
		errors.append("retained material or shared practical-lens identity drifted")
	for child_path in INDEXED_RUNTIME_CHILD_PATHS:
		if get_node_or_null(NodePath(child_path)) == null:
			errors.append("indexed runtime child path drifted: %s" % child_path)
	for candidate in find_children("*", "", true, false):
		if str(candidate.name).begins_with("@"):
			errors.append("runtime child has an auto-generated name: %s" % candidate.get_path())
	var lifecycle := get_lifecycle_contract()
	if not bool(lifecycle.reversible) \
			or not bool(lifecycle.visible_matches_enabled) \
			or not bool(lifecycle.collision_matches_enabled) \
			or not bool(lifecycle.process_matches_lifecycle):
		errors.append("lifecycle state is not reversible and quiescent")
	return errors


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"module_id": MODULE_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"connection_slots": get_connection_slots(),
		"surface_roster": get_walkable_surface_roster(),
		"walkable_area_m2": WALKABLE_AREA_M2,
		"alternate_return_path": true,
		"authority": get_authority_contract(),
		"performance": get_performance_contract(),
		"materials": get_material_retention_contract(),
		"footprint": get_integration_footprint(),
	}


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _apply_enabled_state() -> void:
	StationModuleContract.apply_enabled_state(
		StationModuleContract.collect_static_bodies(self), WORLD_LAYER, _module_enabled, self
	)
	set_process(false)
	set_physics_process(false)


func _index_routes() -> void:
	_route_markers = {
		&"origin": _origin_connection,
		&"connector-midpoint": _connector_midpoint,
		&"cross-landing": _cross_landing,
		&"observation-pad": _observation_pad,
		&"logistics-pad": _logistics_pad,
		&"far-return": _far_return,
	}
	for route_id: StringName in _route_markers.keys():
		var marker := _route_markers[route_id] as Marker3D
		marker.set_meta("station_route_marker", true)
		marker.set_meta("route_id", route_id)
	for route_id: StringName in CONNECTION_SLOT_SPECS.keys():
		var marker := get_route_marker(route_id)
		var spec := CONNECTION_SLOT_SPECS[route_id] as Dictionary
		marker.set_meta(StationModuleContract.CONNECTION_SLOT_META, StringName(spec.slot_id))
	for route_id: StringName in DEFERRED_CONNECTION_ROUTE_IDS:
		var marker := get_route_marker(route_id)
		marker.set_meta("deferred_connection_route", true)
		marker.set_meta("connection_status", &"internal_route_only_no_geometry")


func _build_module() -> void:
	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)
	var walkable := Node3D.new()
	walkable.name = "Walkable"
	structure.add_child(walkable)
	for spec_variant in WALKABLE_SURFACE_SPECS:
		var spec := spec_variant as Dictionary
		var body := _box(
			walkable,
			str(spec.node_name),
			spec.center as Vector3,
			spec.size as Vector3,
			_materials["deck"],
			true
		) as StaticBody3D
		body.set_meta("walkable_surface", true)
		body.set_meta("walkable_surface_id", StringName(spec.id))
		body.set_meta("walkable_surface_kind", &"level")
		body.set_meta("walkable_surface_owner", MODULE_ID)
		body.set_meta("horizontal_area_m2", float(spec.area_m2))
		_walkable_surfaces.append(body)

	var safety := Node3D.new()
	safety.name = "SafetyRails"
	structure.add_child(safety)
	_build_safety_rails(safety)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	structure.add_child(dressing)
	_build_dressing(dressing)
	_build_lighting(dressing)


func _build_safety_rails(parent: Node3D) -> void:
	# Connector sides and the exposed cross-landing perimeter. Gaps coincide only
	# with a touching walkable rectangle, never with open void.
	for side_index in 2:
		var side := -1.0 + float(side_index) * 2.0
		_safety_rail(parent, "ConnectorRail%02d" % (side_index + 1), Vector3(side * 2.12, 0.62, 11.0), Vector3(0.16, 1.24, 21.8))
	_safety_rail(parent, "CrossSouthWest", Vector3(-6.1, 0.62, 21.88), Vector3(7.8, 1.24, 0.16))
	_safety_rail(parent, "CrossSouthEast", Vector3(6.1, 0.62, 21.88), Vector3(7.8, 1.24, 0.16))
	_safety_rail(parent, "CrossNorthVoid", Vector3(0.0, 0.62, 26.12), Vector3(5.7, 1.24, 0.16))
	_safety_rail(parent, "CrossWest", Vector3(-10.12, 0.62, 24.0), Vector3(0.16, 1.24, 4.0))
	_safety_rail(parent, "CrossEast", Vector3(10.12, 0.62, 24.0), Vector3(0.16, 1.24, 4.0))
	# Pad outside edges and inner edges up to the far bridge opening.
	for side_index in 2:
		var side := -1.0 + float(side_index) * 2.0
		_safety_rail(parent, "PadOuterRail%02d" % (side_index + 1), Vector3(side * 13.12, 0.62, 32.0), Vector3(0.16, 1.24, 12.0))
		_safety_rail(parent, "PadInnerRail%02d" % (side_index + 1), Vector3(side * 2.88, 0.62, 31.1), Vector3(0.16, 1.24, 10.2))
		_safety_rail(parent, "PadFarRail%02d" % (side_index + 1), Vector3(side * 8.5, 0.62, 38.12), Vector3(9.0, 1.24, 0.16))
	# The far bridge itself has north/south rails and turns the two pad routes into
	# a loop instead of two dead ends.
	_safety_rail(parent, "FarBridgeSouthRail", Vector3(0.0, 0.62, 36.38), Vector3(5.7, 1.24, 0.16))
	_safety_rail(parent, "FarBridgeNorthRail", Vector3(0.0, 0.62, 39.62), Vector3(6.2, 1.24, 0.16))
	_multimesh_scaled_boxes(parent, "VisibleRailBars", _materials["rail"], _visible_rail_bar_transforms)
	_multimesh_scaled_boxes(parent, "VisibleRailPosts", _materials["rail"], _visible_rail_post_transforms)


func _safety_rail(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> void:
	var rail := _box(parent, node_name, position, size, _materials["rail"], true) as StaticBody3D
	rail.set_meta("station_safety_edge", true)
	rail.set_meta("non_walkable_reason", "physical fall-protection rail at exposed deck edge")
	# The full-height box is intentionally conservative collision, not architecture.
	# Remove its renderer and describe a real open rail with two bars and regularly
	# spaced posts; the body and BoxShape3D remain completely unchanged.
	var solid_renderer := rail.get_node_or_null(^"Mesh") as MeshInstance3D
	if solid_renderer != null:
		rail.remove_child(solid_renderer)
		solid_renderer.free()
	for bar_y in [0.66, 1.15]:
		_visible_rail_bar_transforms.append(Transform3D(
			Basis.from_scale(Vector3(size.x, 0.10, size.z)),
			Vector3(position.x, bar_y, position.z)
		))
	var rail_runs_along_x := size.x >= size.z
	var run_length := size.x if rail_runs_along_x else size.z
	var segment_count := ceili(run_length / 2.4)
	for post_index in segment_count + 1:
		var offset := -run_length * 0.5 + run_length * float(post_index) / float(segment_count)
		var post_position := position
		if rail_runs_along_x:
			post_position.x += offset
		else:
			post_position.z += offset
		post_position.y = 0.62
		_visible_rail_post_transforms.append(Transform3D(
			Basis.from_scale(Vector3(0.12, 1.24, 0.12)), post_position
		))


func _build_dressing(parent: Node3D) -> void:
	# Observation pad: three low, outboard instruments and one backed bench. The
	# centre and inner edge stay clear for the alternate-return circulation.
	_observation_lens_mesh = BoxMesh.new()
	_observation_lens_mesh.size = OBSERVATION_LENS_SIZE
	var observation_lens_transforms: Array[Transform3D] = []
	var observation_console_transforms: Array[Transform3D] = []
	for console_index in 3:
		var console_position: Vector3 = OBSERVATION_CONSOLE_POSITIONS[console_index]
		var console_body := _box(
			parent,
			"ObservationConsole%02d" % (console_index + 1),
			console_position,
			OBSERVATION_CONSOLE_SIZE,
			_materials["shell"],
			true
		) as StaticBody3D
		var console_renderer := console_body.get_node(^"Mesh") as MeshInstance3D
		console_body.remove_child(console_renderer)
		console_renderer.free()
		var console_anchor := Marker3D.new()
		console_anchor.name = "Mesh"
		console_anchor.set_meta("visual_detail_only", true)
		console_anchor.set_meta("batched_visual_anchor", true)
		console_body.add_child(console_anchor)
		observation_console_transforms.append(Transform3D(Basis.IDENTITY, console_position))
		var lens_position: Vector3 = OBSERVATION_LENS_POSITIONS[console_index]
		var lens_anchor := Marker3D.new()
		lens_anchor.name = "ObservationLens%02d" % (console_index + 1)
		lens_anchor.position = lens_position
		lens_anchor.set_meta("visual_detail_only", true)
		lens_anchor.set_meta("batched_visual_anchor", true)
		parent.add_child(lens_anchor)
		observation_lens_transforms.append(Transform3D(Basis.IDENTITY, lens_position))
	var observation_console_batch := _multimesh_boxes(
		parent,
		"ObservationConsoleRenderBatch",
		OBSERVATION_CONSOLE_SIZE,
		_materials["shell"],
		observation_console_transforms
	)
	observation_console_batch.multimesh.visible_instance_count = OBSERVATION_CONSOLE_COPY_COUNT
	observation_console_batch.multimesh.buffer = _encode_multimesh_transforms(
		observation_console_transforms
	)
	observation_console_batch.multimesh.custom_aabb = OBSERVATION_CONSOLE_CULLING_BOUNDS
	var observation_lens_batch := _multimesh_boxes(
		parent,
		"ObservationLensRenderBatch",
		OBSERVATION_LENS_SIZE,
		_materials["cyan"],
		observation_lens_transforms,
		_observation_lens_mesh
	)
	observation_lens_batch.multimesh.visible_instance_count = OBSERVATION_LENS_COPY_COUNT
	observation_lens_batch.multimesh.buffer = _encode_multimesh_transforms(
		observation_lens_transforms
	)
	observation_lens_batch.multimesh.custom_aabb = OBSERVATION_LENS_CULLING_BOUNDS
	_box(parent, "ObservationBench", Vector3(-5.0, 0.30, 28.0), Vector3(2.6, 0.60, 0.62), _materials["shell"], true)
	# Logistics pad: restrained pallet stacks remain along the outboard edge.
	_logistics_case_mesh = BoxMesh.new()
	_logistics_case_mesh.size = LOGISTICS_CASE_SIZE
	for stack_index in 3:
		var stack_z := 28.8 + float(stack_index) * 2.75
		_box(parent, "LogisticsPallet%02d" % (stack_index + 1), Vector3(11.15, 0.12, stack_z), Vector3(2.4, 0.24, 1.55), _materials["rail"], true)
		for tier_index in 2:
			var case_index := stack_index * 2 + tier_index + 1
			_box(parent, "LogisticsCase%02d" % case_index, Vector3(11.15, 0.48 + float(tier_index) * 0.58, stack_z), LOGISTICS_CASE_SIZE, _materials["cargo"], true, _logistics_case_mesh)
	# Sparse connector rhythm provides scale without narrowing its 4 m lane.
	var connector_marker_transforms: Array[Transform3D] = []
	for bay_index in 5:
		var bay_z := 3.0 + float(bay_index) * 4.0
		for side in [-1.0, 1.0]:
			connector_marker_transforms.append(
				Transform3D(Basis.IDENTITY, Vector3(float(side) * 1.88, 0.22, bay_z))
			)
	_multimesh_boxes(
		parent, "ConnectorMarkers", Vector3(0.10, 0.44, 0.62), _materials["amber"], connector_marker_transforms
	)
	# The district identity belongs to the final connector portal rather than
	# floating at eye height across the cross-landing sightline.
	_label(parent, "AreaIdentity", "OBSERVATION  //  LOGISTICS", Vector3(0.0, 3.18, 21.82), Color("dbe8e4"))
	_build_finishing_details(parent)


func _build_finishing_details(parent: Node3D) -> void:
	# Five open portals give the long approach a deliberate station silhouette
	# without adding walls, floor or collision across its exposed negative space.
	var portal_posts: Array[Transform3D] = []
	var portal_beams: Array[Transform3D] = []
	for bay_z in [2.0, 7.0, 12.0, 17.0, 22.0]:
		for side in [-1.0, 1.0]:
			portal_posts.append(Transform3D(Basis.IDENTITY, Vector3(side * 2.42, 1.80, bay_z)))
		portal_beams.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 3.55, bay_z)))
	_multimesh_boxes(parent, "ConnectorPortalPosts", Vector3(0.22, 3.60, 0.22), _materials["rail"], portal_posts)
	_multimesh_boxes(parent, "ConnectorPortalBeams", Vector3(5.05, 0.22, 0.34), _materials["shell"], portal_beams)

	# Perforated ribbon roofs shelter the working zones but keep the two pads and
	# the void between them visually legible from the approach and from space.
	var canopy_slats: Array[Transform3D] = []
	for pad_x in [-8.0, 8.0]:
		for slat_index in 6:
			canopy_slats.append(Transform3D(
				Basis.IDENTITY,
				Vector3(pad_x - 2.5 + float(slat_index), 3.72, 32.0)
			))
	var canopy_ribs: Array[Transform3D] = []
	for pad_x in [-8.0, 8.0]:
		for rib_z in [28.15, 30.7, 33.3, 35.85]:
			canopy_ribs.append(Transform3D(Basis.IDENTITY, Vector3(pad_x, 3.58, rib_z)))
	var canopy_supports: Array[Transform3D] = []
	# Supports sit directly outside the pad edges against the safety rails, so a
	# player never encounters a visual-only post in either walkable route.
	for support_x in [-13.18, -2.82, 2.82, 13.18]:
		for support_z in [28.4, 35.6]:
			canopy_supports.append(Transform3D(Basis.IDENTITY, Vector3(support_x, 1.78, support_z)))
	_multimesh_boxes(parent, "PadCanopySlats", Vector3(0.62, 0.12, 8.0), _materials["shell"], canopy_slats)
	_multimesh_boxes(parent, "PadCanopyRibs", Vector3(9.35, 0.20, 0.24), _materials["rail"], canopy_ribs)
	_multimesh_boxes(parent, "PadCanopySupports", Vector3(0.20, 3.56, 0.20), _materials["rail"], canopy_supports)

	# The two pads terminate in compact perimeter pavilions. Their wall panels sit
	# between each outboard safety rail and the footprint boundary, so they add a
	# convincing enclosed destination without consuming or faking walkable area.
	# Dark view bands and repeated mullions distinguish the observation gallery
	# from the cargo wall while keeping both sides in one manufactured family.
	var pavilion_panels: Array[Transform3D] = []
	var pavilion_windows: Array[Transform3D] = []
	var pavilion_mullions: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for panel_z in [28.45, 31.95, 35.45]:
			pavilion_panels.append(Transform3D(
				Basis.from_scale(Vector3(0.24, 3.25, 2.75)),
				Vector3(side * 13.27, 1.63, panel_z)
			))
			pavilion_windows.append(Transform3D(
				Basis.from_scale(Vector3(0.04, 0.92, 2.18)),
				Vector3(side * 13.135, 2.03, panel_z)
			))
		for mullion_z in [27.05, 29.85, 33.35, 36.85]:
			pavilion_mullions.append(Transform3D(
				Basis.from_scale(Vector3(0.08, 1.12, 0.10)),
				Vector3(side * 13.10, 2.03, mullion_z)
			))
	_multimesh_scaled_boxes(parent, "PadPavilionBulkheads", _materials["shell"], pavilion_panels)
	_multimesh_scaled_boxes(parent, "PadPavilionWindows", _materials["window"], pavilion_windows)
	_multimesh_scaled_boxes(parent, "PadPavilionMullions", _materials["rail"], pavilion_mullions)

	# Deep fascia and a low service plinth visually join each slatted canopy to its
	# pavilion. All pieces are overhead or outboard of the conservative rail, so
	# the clear loop remains exactly the one validated by the player traversal.
	var pavilion_fascias: Array[Transform3D] = []
	var pavilion_plinths: Array[Transform3D] = []
	for pad_x in [-8.0, 8.0]:
		pavilion_fascias.append(Transform3D(
			Basis.from_scale(Vector3(9.75, 0.48, 0.22)),
			Vector3(pad_x, 3.34, 27.92)
		))
	var plinth_side := -1.0
	for _side_index in 2:
		for plinth_z in [29.0, 32.0, 35.0]:
			pavilion_plinths.append(Transform3D(
				Basis.from_scale(Vector3(0.42, 0.72, 2.15)),
				Vector3(plinth_side * 13.16, 0.36, plinth_z)
			))
		plinth_side *= -1.0
	_multimesh_scaled_boxes(parent, "PadPavilionFascias", _materials["rail"], pavilion_fascias)
	_multimesh_scaled_boxes(parent, "PadPavilionPlinths", _materials["rail"], pavilion_plinths)

	# Recessed canopy strips give each pad a readable pool and reduce dependence
	# on the formerly over-bright mast lenses. They are fixture presentation only;
	# the six bounded practical lights remain the sole illumination nodes.
	var canopy_task_strips: Array[Transform3D] = []
	for pad_x in [-8.0, 8.0]:
		for strip_z in [29.4, 32.0, 34.6]:
			canopy_task_strips.append(Transform3D(
				Basis.IDENTITY,
				Vector3(pad_x, 3.49, strip_z)
			))
	_multimesh_boxes(parent, "PadCanopyTaskStrips", Vector3(1.55, 0.045, 0.16), _materials["practical_white"], canopy_task_strips)

	# Backing plates bind every label to architecture and stop white text from
	# tangling with rails, stars and cargo when read from player height.
	var sign_backs: Array[Transform3D] = [
		Transform3D(Basis.from_scale(Vector3(5.20, 0.64, 0.12)), Vector3(0.0, 3.18, 21.96)),
		Transform3D(Basis.from_scale(Vector3(4.65, 0.58, 0.12)), Vector3(-8.0, 2.98, 27.96)),
		Transform3D(Basis.from_scale(Vector3(4.65, 0.58, 0.12)), Vector3(8.0, 2.98, 27.96)),
		Transform3D(Basis.from_scale(Vector3(2.75, 0.50, 0.12)), Vector3(0.0, 2.84, 37.84)),
	]
	_multimesh_scaled_boxes(parent, "DistrictSignBacks", _materials["rail"], sign_backs)

	# Small functional accents resolve the existing consoles and cargo stacks at
	# player distance while staying visual-only and out of the circulation lane.
	var console_trim: Array[Transform3D] = []
	for console_z in [28.6, 31.4, 34.2]:
		console_trim.append(Transform3D(Basis.IDENTITY, Vector3(-11.02, 1.00, console_z)))
	_multimesh_boxes(parent, "ObservationConsoleTrim", Vector3(0.07, 0.12, 1.08), _materials["cyan"], console_trim)
	var cargo_bands: Array[Transform3D] = []
	for stack_index in 3:
		var stack_z := 28.8 + float(stack_index) * 2.75
		for tier_index in 2:
			var tier_y := 0.48 + float(tier_index) * 0.58
			for band_offset in [-0.34, 0.34]:
				cargo_bands.append(Transform3D(Basis.IDENTITY, Vector3(11.15 + band_offset, tier_y + 0.27, stack_z)))
	_multimesh_boxes(parent, "CargoCaseBands", Vector3(0.12, 0.05, 1.34), _materials["amber"], cargo_bands)

	# Colour-coded deck ticks and bridge chevrons create a readable material and
	# wayfinding hierarchy without increasing the five walkable surface extents.
	var observation_ticks: Array[Transform3D] = []
	var logistics_ticks: Array[Transform3D] = []
	for tick_index in 6:
		var tick_z := 27.2 + float(tick_index) * 1.75
		observation_ticks.append(Transform3D(Basis.IDENTITY, Vector3(-4.25, 0.025, tick_z)))
		logistics_ticks.append(Transform3D(Basis.IDENTITY, Vector3(4.25, 0.025, tick_z)))
	_multimesh_boxes(parent, "ObservationZoneTicks", Vector3(0.14, 0.035, 0.92), _materials["cyan"], observation_ticks)
	_multimesh_boxes(parent, "LogisticsZoneTicks", Vector3(0.14, 0.035, 0.92), _materials["amber"], logistics_ticks)
	var return_chevrons: Array[Transform3D] = []
	for chevron_index in 5:
		return_chevrons.append(Transform3D(Basis.IDENTITY, Vector3(-2.0 + float(chevron_index), 0.025, 38.0)))
	_multimesh_boxes(parent, "ReturnBridgeChevrons", Vector3(0.48, 0.035, 0.12), _materials["practical_white"], return_chevrons)

	_label(parent, "ObservationArraySign", "OBS  //  ARRAY  04", Vector3(-8.0, 2.98, 27.82), Color("8fe8ef"))
	_label(parent, "LogisticsManifestSign", "LOG  //  MANIFEST", Vector3(8.0, 2.98, 27.82), Color("f4bf72"))
	_label(parent, "ReturnLoopSign", "RETURN LOOP", Vector3(0.0, 2.84, 37.70), Color("dbe8e4"))


func _build_lighting(parent: Node3D) -> void:
	_practical_lens_mesh = BoxMesh.new()
	_practical_lens_mesh.size = PRACTICAL_LENS_SIZE
	var fixtures := [
		[Vector3(2.32, 2.8, 7.0), Color("8fe8ef"), "practical_cyan"],
		[Vector3(-2.32, 2.8, 18.0), Color("8fe8ef"), "practical_cyan"],
		[Vector3(-9.55, 2.8, 23.5), Color("dbe8e4"), "practical_white"],
		[Vector3(-12.72, 2.8, 32.0), Color("8fe8ef"), "practical_cyan"],
		[Vector3(12.72, 2.8, 32.0), Color("f4bf72"), "practical_amber"],
		[Vector3(2.72, 2.8, 38.0), Color("dbe8e4"), "practical_white"],
	]
	var mast_transforms: Array[Transform3D] = []
	for fixture_index in fixtures.size():
		var fixture := fixtures[fixture_index] as Array
		var fixture_position := fixture[0] as Vector3
		var fixture_color := fixture[1] as Color
		var fixture_material_key := str(fixture[2])
		var mast_position := fixture_position + Vector3(0, -1.4, 0)
		var mast_anchor := Marker3D.new()
		mast_anchor.name = "LightMast%02d" % (fixture_index + 1)
		mast_anchor.position = mast_position
		mast_anchor.set_meta("visual_detail_only", true)
		mast_anchor.set_meta("batched_visual_anchor", true)
		parent.add_child(mast_anchor)
		mast_transforms.append(Transform3D(Basis.IDENTITY, mast_position))
		_box(parent, "LightLens%02d" % (fixture_index + 1), fixture_position, PRACTICAL_LENS_SIZE, _materials[fixture_material_key], false, _practical_lens_mesh)
		var light := OmniLight3D.new()
		light.name = "Practical%02d" % (fixture_index + 1)
		light.position = fixture_position + Vector3(0, -0.16, 0)
		light.light_color = fixture_color
		light.light_energy = 0.48
		light.omni_range = 7.5
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 55.0
		light.distance_fade_length = 18.0
		parent.add_child(light)
	_multimesh_boxes(
		parent,
		"LightMastRenderBatch",
		LIGHT_MAST_SIZE,
		_materials["rail"],
		mast_transforms
	)


func _apply_metadata() -> void:
	add_to_group("station_modules")
	set_meta("station_module", true)
	set_meta("module_id", MODULE_ID)
	set_meta("content_class", CONTENT_CLASS)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("authenticated_original_geometry", false)
	set_meta("content_note", CONTENT_NOTE)


func _create_materials() -> void:
	_materials["deck"] = _material(Color("59666b"), 0.34, 0.46)
	_materials["rail"] = _material(Color("60767d"), 0.54, 0.46)
	_materials["shell"] = _material(Color("9ca7a6"), 0.42, 0.30)
	_materials["cargo"] = _material(Color("735c3d"), 0.66, 0.18)
	_materials["cyan"] = _emissive_material(Color("58dce5"))
	_materials["amber"] = _emissive_material(Color("e5a94e"))
	_materials["practical_cyan"] = _emissive_material(Color("8fe8ef"))
	_materials["practical_white"] = _emissive_material(Color("dbe8e4"))
	_materials["practical_amber"] = _emissive_material(Color("f4bf72"))
	_materials["window"] = _material(Color("10272e"), 0.18, 0.22)
	(_materials["window"] as StandardMaterial3D).emission_enabled = true
	(_materials["window"] as StandardMaterial3D).emission = Color("103b43")
	(_materials["window"] as StandardMaterial3D).emission_energy_multiplier = 0.32
	for practical_key in ["practical_cyan", "practical_white", "practical_amber"]:
		(_materials[practical_key] as StandardMaterial3D).emission_energy_multiplier = 0.9
	StationSurfaceKit.apply_panel_triplanar(
		_materials["deck"] as StandardMaterial3D,
		0.30,
		StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	StationSurfaceKit.apply_panel_triplanar(_materials["shell"] as StandardMaterial3D, 0.30)


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color.darkened(0.30), 0.28, 0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	return material


func _box(
		parent: Node3D,
		node_name: String,
		position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool,
		shared_mesh: BoxMesh = null
	) -> Node3D:
	var mesh := shared_mesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = position
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var visible := MeshInstance3D.new()
		visible.name = "Mesh"
		visible.mesh = mesh
		visible.material_override = material
		body.add_child(visible)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		return body
	var visible := MeshInstance3D.new()
	visible.name = node_name
	visible.position = position
	visible.mesh = mesh
	visible.material_override = material
	visible.set_meta("visual_detail_only", true)
	parent.add_child(visible)
	return visible


func _multimesh_boxes(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		material: Material,
		transforms: Array[Transform3D],
		shared_mesh: BoxMesh = null
	) -> MultiMeshInstance3D:
	var box := shared_mesh
	if box == null:
		box = BoxMesh.new()
		box.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = transforms.size()
	for transform_index in transforms.size():
		multi.set_instance_transform(transform_index, transforms[transform_index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.set_meta("visual_detail_only", true)
	instance.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(instance)
	return instance


func _multimesh_scaled_boxes(
		parent: Node3D,
		node_name: String,
		material: Material,
		transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	# A unit box plus per-instance scale allows every differently sized rail run
	# to remain in one submission instead of creating a renderer per segment.
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = transforms.size()
	for transform_index in transforms.size():
		multi.set_instance_transform(transform_index, transforms[transform_index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.set_meta("visual_detail_only", true)
	instance.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(instance)
	return instance


func _label(parent: Node3D, node_name: String, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.rotation_degrees = Vector3(0, 180, 0)
	label.font_size = 36
	label.modulate = color
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)


static func _encode_multimesh_transforms(
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
