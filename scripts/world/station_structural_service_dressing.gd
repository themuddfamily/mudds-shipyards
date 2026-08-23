class_name StationStructuralServiceDressing
extends Node3D

## Static, reusable station-edge structural and service dressing.
##
## Mount the origin at the centre of an arbitrary planar attachment surface. In
## the canonical orientation local X is the segment tangent, local +Z is the
## surface normal pointing away from the host, and local -Y is the cross-face
## direction. Orienting the component root makes the same contract suitable for
## an underside, outer wall, fascia, or keel; no world-up or top-deck assumption
## is built into the geometry.

enum StructuralProfile {
	LIGHT,
	STANDARD,
	DEEP,
}

enum SegmentOrientation {
	ALONG_MOUNT_X,
	ALONG_MOUNT_Y,
}

enum DetailQuality {
	LOW,
	MEDIUM,
	HIGH,
}

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-structural-service-dressing"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MINIMUM_SEGMENT_LENGTH := 6.0
const MAXIMUM_SEGMENT_LENGTH := 24.0
const DEFAULT_SEGMENT_LENGTH := 12.0
const STRUCTURAL_BAY_COUNT := 4
const STRUCTURAL_POST_COUNT := STRUCTURAL_BAY_COUNT + 1
const CROSS_BRACE_COUNT := STRUCTURAL_BAY_COUNT * 2
const CONDUIT_COUNT := 3
const CONDUIT_CLAMP_COUNT := 4
const RADIATOR_VENT_COUNT := 6
const TASK_STRIP_COUNT := 2
const FASCIA_FASTENER_COUNT := 6
const TOTAL_VISIBLE_PRIMITIVE_COUNT := 41
const BATCHED_MESH_INSTANCE_COUNT := TOTAL_VISIBLE_PRIMITIVE_COUNT - RADIATOR_VENT_COUNT
const RENDERER_NODE_COUNT := BATCHED_MESH_INSTANCE_COUNT + 1

## The four resident dressing instances all publish this one material-free,
## immutable fastener recipe. It intentionally lives for the session rather
## than in a caller cache: every node keeps its own material override and no
## collision, lifecycle, or presentation authority is attached to the mesh.
static var _fascia_fastener_mesh_cache: Dictionary = {}

const PERFORMANCE_BUDGET := {
	"node_count": 56,
	"visible_primitives": 45,
	"mesh_instances": 45,
	"multimesh_batches": 1,
	"geometry_submissions": 40,
	"unique_materials": 10,
	"lights": 1,
	"visible_lights": 1,
	"shadow_casting_lights": 0,
	"collision_nodes": 0,
	"particle_emitters": 0,
	"audio_nodes": 0,
	"reflection_probes": 0,
	"animation_players": 0,
	"text_nodes": 0,
}

const CONTENT_NOTE := (
	"This collision-free under-deck keel, fascia, conduit, radiator, vent, task-light, "
	+ "material, profile, dimension, and placement language is original modern remake "
	+ "design. It is suitable for bounded margins around the central berth, Aft Junction, "
	+ "Habitat, and Freight modules, but it is not recovered historical station geometry "
	+ "and does not authenticate any original layout or service system."
)

@export_category("Structural configuration")
@export_range(MINIMUM_SEGMENT_LENGTH, MAXIMUM_SEGMENT_LENGTH, 0.5) var segment_length := DEFAULT_SEGMENT_LENGTH
@export_enum("Light", "Standard", "Deep") var structural_profile: int = StructuralProfile.STANDARD
@export_enum("Along mount X", "Along mount Y") var segment_orientation: int = SegmentOrientation.ALONG_MOUNT_X

@export_category("Presentation")
@export var starts_enabled := true
@export_enum("Low", "Medium", "High") var initial_quality: int = DetailQuality.HIGH

@onready var _mount_anchor: Marker3D = get_node(^"MountAnchor") as Marker3D
@onready var _dressing_center_anchor: Marker3D = get_node(^"DressingCenterAnchor") as Marker3D
@onready var _presentation_root: Node3D = get_node(^"PresentationRoot") as Node3D
@onready var _structural_core_root: Node3D = get_node(^"PresentationRoot/StructuralCoreRoot") as Node3D
@onready var _service_detail_root: Node3D = get_node(^"PresentationRoot/ServiceDetailRoot") as Node3D
@onready var _high_detail_root: Node3D = get_node(^"PresentationRoot/HighDetailRoot") as Node3D

var _materials: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}
var _task_light: OmniLight3D
var _radiator_vent_batch: MultiMeshInstance3D
var _dressing_enabled := true
var _quality_level: int = DetailQuality.HIGH
var _built := false
var _built_configuration: Dictionary = {}
var _built_node_instance_ids: Dictionary = {}
var _built_node_transforms: Dictionary = {}
var _built_mesh_contracts: Dictionary = {}
var _built_material_contracts: Dictionary = {}
var _built_task_light_contract: Dictionary = {}


func _ready() -> void:
	if _built:
		return
	# Geometry-defining exports are authoring inputs. Capture the exact effective
	# values once so later inspector/script writes cannot make reports describe a
	# different envelope from the already-created mesh tree.
	_built_configuration = _make_configuration_snapshot()
	_built = true
	set_process(false)
	set_physics_process(false)
	var orientation_basis := _get_orientation_basis()
	_presentation_root.basis = orientation_basis
	var dimensions := _get_profile_dimensions()
	_dressing_center_anchor.position = orientation_basis * Vector3(
		0.0,
		-float(dimensions["crossface_span"]) * 0.5,
		float(dimensions["outward_depth"]) * 0.5
	)
	_dressing_center_anchor.basis = orientation_basis
	_create_materials()
	_build_structural_core(dimensions)
	_build_service_detail(dimensions)
	_build_high_detail(dimensions)
	_apply_evidence_metadata()
	_dressing_enabled = starts_enabled
	_quality_level = initial_quality if _is_valid_quality(initial_quality) else DetailQuality.HIGH
	_refresh_visibility()
	_capture_built_presentation_contract()


## Applies immutable build configuration before the component enters the tree.
## Runtime rebuilding is intentionally rejected: a live instance is static, and
## quality changes only toggle already-authored subtrees.
func configure(length_metres: float, profile_value: int, orientation_value: int) -> bool:
	if _built:
		return false
	if (
		not is_finite(length_metres)
		or length_metres < MINIMUM_SEGMENT_LENGTH
		or length_metres > MAXIMUM_SEGMENT_LENGTH
		or not _is_valid_profile(profile_value)
		or not _is_valid_orientation(orientation_value)
	):
		return false
	segment_length = length_metres
	structural_profile = profile_value
	segment_orientation = orientation_value
	return true


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_mount_anchor() -> Marker3D:
	return _mount_anchor if is_instance_valid(_mount_anchor) else null


func get_mount_transform() -> Transform3D:
	return (
		_mount_anchor.global_transform
		if (
			is_instance_valid(_mount_anchor)
			and get_node_or_null(^"MountAnchor") == _mount_anchor
			and is_ancestor_of(_mount_anchor)
		)
		else global_transform
	)


func get_dressing_center_anchor() -> Marker3D:
	return _dressing_center_anchor if is_instance_valid(_dressing_center_anchor) else null


func get_dressing_center_transform() -> Transform3D:
	return (
		_dressing_center_anchor.global_transform
		if (
			is_instance_valid(_dressing_center_anchor)
			and get_node_or_null(^"DressingCenterAnchor") == _dressing_center_anchor
			and is_ancestor_of(_dressing_center_anchor)
		)
		else global_transform
	)


func set_dressing_enabled(enabled: bool) -> void:
	if not _is_current():
		return
	_dressing_enabled = enabled
	_refresh_visibility()


func is_dressing_enabled() -> bool:
	return _dressing_enabled


func set_quality_level(level: int) -> bool:
	if not _is_current():
		return false
	if not _is_valid_quality(level):
		return false
	_quality_level = level
	_refresh_visibility()
	return true


func get_quality_level() -> int:
	return _quality_level


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_configuration() -> Dictionary:
	var snapshot := _get_configuration_snapshot()
	var dimensions := snapshot["profile_dimensions"] as Dictionary
	return {
		"segment_length": float(snapshot["segment_length"]),
		"structural_profile": int(snapshot["structural_profile"]),
		"structural_profile_name": snapshot["structural_profile_name"] as StringName,
		"segment_orientation": int(snapshot["segment_orientation"]),
		"segment_orientation_name": snapshot["segment_orientation_name"] as StringName,
		"segment_axis_local": snapshot["segment_axis_local"] as Vector3,
		"outward_axis_local": snapshot["outward_axis_local"] as Vector3,
		"crossface_span": float(dimensions["crossface_span"]),
		"outward_depth": float(dimensions["outward_depth"]),
		"frame_thickness": float(dimensions["frame_thickness"]),
		"runtime_rebuild_allowed": false,
	}.duplicate(true)


## Returns the complete visual envelope in component-local space. The envelope
## never crosses behind the attachment plane. A parent may therefore reserve
## only the bounded volume on the outward side of its chosen mount surface.
func get_local_footprint() -> AABB:
	return _get_configuration_snapshot()["local_footprint"] as AABB


func get_integration_contract() -> Dictionary:
	var footprint := get_local_footprint()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"mount_type": &"planar_attachment_surface_center",
		"mount_transform": get_mount_transform(),
		"dressing_center_transform": get_dressing_center_transform(),
		"local_footprint": footprint,
		"local_min": footprint.position,
		"local_max": footprint.position + footprint.size,
		"local_size": footprint.size,
		"segment_axis_local": _get_segment_axis_local(),
		"crossface_axis_local": _get_crossface_axis_local(),
		"outward_axis_local": _get_outward_axis_local(),
		"attachment_surface_normal_local": _get_outward_axis_local(),
		"maximum_attachment_surface_penetration": 0.0,
		"requires_clear_volume_outside_surface": true,
		"supports_underdeck_mount": true,
		"supports_outer_wall_mount": true,
		"assumes_world_up": false,
		"widens_walkable_surface": false,
		"fills_station_void": false,
		"collision_policy": &"presentation_only_collision_free",
		"compatible_margin_roles": PackedStringArray([
			"central_berth_outer_edge",
			"aft_junction_underdeck",
			"habitat_outer_edge",
			"freight_margin",
		]),
		"production_world_integration_required": false,
	}.duplicate(true)


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"presentation_only": true,
		"provisional": true,
		"authenticated_original_geometry": false,
		"authenticated_original_placement": false,
		"authenticated_original_service_systems": false,
		"supported_direction": PackedStringArray([
			"retain narrow station arms, separated nodes, and substantial negative space",
			"increase modern structural and operational visual density without changing recovered-layout claims",
			"keep clean silhouettes and restrained readable colour within a realistic-stylised presentation",
		]),
		"modern_interpretations": PackedStringArray([
			"X-braced keel and fascia construction",
			"constrained conduit bundle, clamps, manifold, and couplers",
			"radiator backplate, vent blades, materials, dimensions, and mounting",
			"restrained emissive task strips and one bounded non-shadow task light",
			"profile depths, segment orientation, quality tiers, and all placement guidance",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical under-deck structure, service routing, radiator systems, lighting, dimensions, and placement",
			"whether any original or fixed-era station segment used comparable equipment",
		]),
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


func get_performance_audit() -> Dictionary:
	var counts := {
		"node_count": 0,
		"visible_primitives": 0,
		"mesh_instances": 0,
		"multimesh_batches": 0,
		"geometry_submissions": 0,
		"unique_materials": 0,
		"lights": 0,
		"visible_lights": 0,
		"shadow_casting_lights": 0,
		"collision_nodes": 0,
		"particle_emitters": 0,
		"audio_nodes": 0,
		"reflection_probes": 0,
		"animation_players": 0,
		"text_nodes": 0,
	}
	var material_ids: Dictionary = {}
	_count_runtime_resources(self, counts, material_ids)
	counts["unique_materials"] = material_ids.size()
	var errors := PackedStringArray()
	for key: String in PERFORMANCE_BUDGET.keys():
		if int(counts.get(key, 0)) > int(PERFORMANCE_BUDGET[key]):
			errors.append("%s exceeds budget (%d > %d)" % [key, counts.get(key, 0), PERFORMANCE_BUDGET[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"counts": counts.duplicate(true),
		"budgets": PERFORMANCE_BUDGET.duplicate(true),
		"static_component": true,
		"process_enabled": is_processing(),
		"physics_process_enabled": is_physics_processing(),
		"per_frame_allocation": false,
		"runtime_rebuild_allowed": false,
		"quality_changes_allocate": false,
		# True since the plate-stock roles joined the registered station panel
		# family: this component now loads three shared project texture assets.
		# They are shared with the station modules, so they cost no additional
		# VRAM in the production world, but the published audit must not claim a
		# component is asset-free when it is not.
		"uses_external_assets": true,
		"uses_collision": false,
		"uses_movers": false,
		"uses_audio": false,
		"uses_reflection_probes": false,
	}.duplicate(true)


## Per-instance evidence for the session-retained, material-free fascia recipe.
## Six named visual copies remain local; only their immutable ArrayMesh identity
## is shared with the other resident dressing instances.
func get_fascia_fastener_resource_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_ids: Dictionary = {}
	var rows: Array[Dictionary] = []
	for fastener_index in FASCIA_FASTENER_COUNT:
		var fastener: MeshInstance3D = null
		if is_instance_valid(_high_detail_root):
			fastener = _high_detail_root.get_node_or_null(
				NodePath("FasciaFastener%02d" % (fastener_index + 1))
			) as MeshInstance3D
		if fastener == null:
			errors.append("fascia_fastener_node_missing:%02d" % (fastener_index + 1))
			continue
		if fastener.mesh == null:
			errors.append("fascia_fastener_mesh_missing:%02d" % (fastener_index + 1))
			continue
		mesh_ids[fastener.mesh.get_instance_id()] = true
		if fastener.mesh != _shared_fascia_fastener_mesh():
			errors.append("fascia_fastener_mesh_identity_drift:%02d" % (fastener_index + 1))
		if (
			fastener.material_override != _materials.get("frame_edge")
			or not fastener.rotation_degrees.is_equal_approx(Vector3(90.0, 0.0, 0.0))
			or fastener.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			or fastener.get_child_count() != 0
			or fastener.get_script() != null
			or not fastener.get_groups().is_empty()
			or fastener.is_processing()
			or fastener.is_physics_processing()
		):
			errors.append("fascia_fastener_visual_contract_drift:%02d" % (fastener_index + 1))
		rows.append({
			"path": "PresentationRoot/HighDetailRoot/FasciaFastener%02d" % (fastener_index + 1),
			"position": [fastener.position.x, fastener.position.y, fastener.position.z],
			"rotation_degrees": [fastener.rotation_degrees.x, fastener.rotation_degrees.y, fastener.rotation_degrees.z],
			"material_override_id": fastener.material_override.get_instance_id() if fastener.material_override != null else 0,
		})
	if mesh_ids.size() != 1:
		errors.append("fascia_fastener_mesh_identity_count_drift")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"station_structural_fascia_fasteners",
		"copy_count": FASCIA_FASTENER_COUNT,
		"mesh_resource_identity_count": mesh_ids.size(),
		"baseline_mesh_resource_identity_count": FASCIA_FASTENER_COUNT,
		"mesh_resource_identity_delta": mesh_ids.size() - FASCIA_FASTENER_COUNT,
		"session_retained_immutable_mesh": true,
		"batched": false,
		"collision_authority": false,
		"lifecycle_authority": false,
		"rows": rows,
	}.duplicate(true)


## Frozen renderer-cost and visual-equivalence contract for the six repeated
## radiator blades. Their authored copies remain independently transformed in
## the MultiMesh buffer; only their renderer nodes/submissions are consolidated.
func get_radiator_vent_batch_audit() -> Dictionary:
	var errors := PackedStringArray()
	var expected_transforms := _radiator_vent_transforms()
	var expected_mesh := _radiator_vent_mesh()
	var multimesh: MultiMesh = null
	if (
		not is_instance_valid(_radiator_vent_batch)
		or not is_instance_valid(_service_detail_root)
		or _service_detail_root.get_node_or_null(^"RadiatorVentBlades") != _radiator_vent_batch
		or not _service_detail_root.is_ancestor_of(_radiator_vent_batch)
	):
		errors.append("radiator_vent_batch_missing")
	else:
		multimesh = _radiator_vent_batch.multimesh
	if multimesh == null:
		errors.append("radiator_vent_multimesh_missing")
	else:
		if multimesh.mesh != expected_mesh:
			errors.append("radiator_vent_mesh_identity_drift")
		if multimesh.instance_count != RADIATOR_VENT_COUNT or multimesh.visible_instance_count != RADIATOR_VENT_COUNT:
			errors.append("radiator_vent_copy_count_drift")
		if multimesh.buffer != _encode_multimesh_transforms(expected_transforms):
			errors.append("radiator_vent_transform_buffer_drift")
		if not multimesh.custom_aabb.is_equal_approx(
			_transformed_mesh_bounds(expected_mesh.get_aabb(), expected_transforms)
		):
			errors.append("radiator_vent_culling_bounds_drift")
	if is_instance_valid(_radiator_vent_batch) and (
		_radiator_vent_batch.material_override != _materials.get("frame_edge")
		or _radiator_vent_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		or _radiator_vent_batch.layers != 1
		or not _radiator_vent_batch.transform.is_equal_approx(Transform3D.IDENTITY)
		or _radiator_vent_batch.get_child_count() != 0
		or _radiator_vent_batch.get_script() != null
		or not _radiator_vent_batch.get_groups().is_empty()
	):
		errors.append("radiator_vent_visual_contract_drift")
	if is_instance_valid(_radiator_vent_batch):
		var authored_transforms := _radiator_vent_batch.get_meta(
			"authored_instance_transforms", []
		) as Array
		if authored_transforms.size() != expected_transforms.size():
			errors.append("radiator_vent_authored_transform_metadata_drift")
		else:
			for transform_index in expected_transforms.size():
				if (
					not authored_transforms[transform_index] is Transform3D
					or not (authored_transforms[transform_index] as Transform3D).is_equal_approx(
						expected_transforms[transform_index]
					)
				):
					errors.append("radiator_vent_authored_transform_metadata_drift")
					break
	if is_instance_valid(_service_detail_root) and not _service_detail_root.find_children(
		"RadiatorVentBlade*", "MeshInstance3D", true, false
	).is_empty():
		errors.append("radiator_vent_legacy_renderer_nodes_present")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"station_structural_radiator_vent_blades",
		"copy_count": RADIATOR_VENT_COUNT,
		"baseline_renderer_nodes": RADIATOR_VENT_COUNT,
		"renderer_nodes": 1 if is_instance_valid(_radiator_vent_batch) else 0,
		"baseline_geometry_submissions": RADIATOR_VENT_COUNT,
		"geometry_submissions": 1 if multimesh != null else 0,
		"baseline_mesh_resource_count": 1,
		"mesh_resource_count": 1 if multimesh != null and multimesh.mesh != null else 0,
		"baseline_drawn_copies": RADIATOR_VENT_COUNT,
		"drawn_copies": multimesh.instance_count if multimesh != null else 0,
		"exact_transforms_preserved": multimesh != null and multimesh.buffer == _encode_multimesh_transforms(expected_transforms),
		"collision_authority": false,
		"interaction_authority": false,
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if (
		_mount_anchor == null
		or _dressing_center_anchor == null
		or _presentation_root == null
		or _structural_core_root == null
		or _service_detail_root == null
		or _high_detail_root == null
	):
		errors.append("required mount, footprint, or quality-tier nodes are missing")
	if not _required_node_contract_is_live():
		errors.append("required live mount, quality-tier, or task-light identities changed")
	elif not _required_node_transforms_match_build():
		errors.append("required mount, presentation, or task-light transforms diverged from the built contract")
	if not is_finite(segment_length) or segment_length < MINIMUM_SEGMENT_LENGTH or segment_length > MAXIMUM_SEGMENT_LENGTH:
		errors.append("segment length is outside the supported finite range")
	if not _is_valid_profile(structural_profile):
		errors.append("structural profile is invalid")
	if not _is_valid_orientation(segment_orientation):
		errors.append("segment orientation is invalid")
	if _built and not _live_structural_configuration_matches_build_snapshot():
		errors.append("live structural authoring configuration diverges from immutable build snapshot")
	if not _is_valid_quality(initial_quality):
		errors.append("initial quality is invalid")
	var footprint := get_local_footprint()
	var footprint_end := footprint.position + footprint.size
	if not footprint.position.is_finite() or not footprint.size.is_finite() or footprint.size.x <= 0.0 or footprint.size.y <= 0.0 or footprint.size.z <= 0.0:
		errors.append("local footprint must be finite and non-empty")
	if footprint.position.z < -0.001:
		errors.append("visual footprint penetrates behind the planar attachment surface")
	if footprint_end.z <= 0.0:
		errors.append("visual footprint does not extend outward from the attachment surface")
	var features := _get_feature_counts()
	if int(features["cross_braces"]) != CROSS_BRACE_COUNT:
		errors.append("X-braced structural keel is incomplete")
	if int(features["conduits"]) != CONDUIT_COUNT or int(features["conduit_clamps"]) != CONDUIT_CLAMP_COUNT:
		errors.append("constrained conduit bundle is incomplete")
	if int(features["radiator_vents"]) != RADIATOR_VENT_COUNT:
		errors.append("radiator and vent bank is incomplete")
	if int(features["task_strips"]) != TASK_STRIP_COUNT:
		errors.append("restrained task strips are incomplete")
	if _task_light == null or _task_light.shadow_enabled:
		errors.append("bounded non-shadow task light is missing or casts shadows")
	elif (
		not is_equal_approx(_task_light.light_energy, 0.22)
		or not is_equal_approx(_task_light.omni_range, 2.6)
		or not is_equal_approx(_task_light.omni_attenuation, 2.0)
		or not _task_light.light_color.is_equal_approx(Color("d8c89a"))
	):
		errors.append("bounded task-light presentation settings diverged from the built contract")
	var performance := get_performance_audit()
	if not bool(performance["within_budget"]):
		errors.append_array(performance["errors"] as PackedStringArray)
	var counts := performance["counts"] as Dictionary
	if (
		int(counts["mesh_instances"]) != BATCHED_MESH_INSTANCE_COUNT
		or int(counts["multimesh_batches"]) != 1
		or int(counts["geometry_submissions"]) != RENDERER_NODE_COUNT
	):
		errors.append("stable maximum-detail primitive contract changed")
	if int(counts["lights"]) != 1:
		errors.append("component must retain exactly one live bounded task light")
	if int(counts["collision_nodes"]) != 0:
		errors.append("presentation dressing must remain collision-free")
	if (
		int(counts["audio_nodes"]) != 0
		or int(counts["reflection_probes"]) != 0
		or int(counts["animation_players"]) != 0
		or int(counts["text_nodes"]) != 0
	):
		errors.append("component contains prohibited audio, mover, reflection, or text content")
	if is_processing() or is_physics_processing():
		errors.append("static dressing must not run per-frame callbacks")
	if not _visibility_contract_matches_lifecycle():
		errors.append("quality-tier visibility diverged from enabled and quality lifecycle state")
	if not bool(get_fascia_fastener_resource_audit().get("valid", false)):
		errors.append("fascia fastener shared-resource contract diverged")
	if not bool(get_radiator_vent_batch_audit().get("valid", false)):
		errors.append("radiator vent batch contract diverged")
	if not _all_live_meshes_fit_published_footprint():
		errors.append("live dressing mesh geometry exceeds the immutable published footprint")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"configuration": get_configuration(),
		"integration": get_integration_contract(),
		"evidence": get_evidence_metadata(),
		"performance": get_performance_audit(),
		"features": _get_feature_counts(),
		"lifecycle": {
			"enabled": _dressing_enabled,
			"quality_level": _quality_level,
			"quality_name": _get_quality_name(_quality_level),
			"presentation_visible": _presentation_root != null and _presentation_root.visible,
			"process_enabled": is_processing(),
			"physics_process_enabled": is_physics_processing(),
		},
		"node_contract": {
			"mount_anchor": NodePath("MountAnchor"),
			"dressing_center_anchor": NodePath("DressingCenterAnchor"),
			"presentation_root": NodePath("PresentationRoot"),
			"structural_core": NodePath("PresentationRoot/StructuralCoreRoot"),
			"service_detail": NodePath("PresentationRoot/ServiceDetailRoot"),
			"high_detail": NodePath("PresentationRoot/HighDetailRoot"),
			"task_light": NodePath("PresentationRoot/HighDetailRoot/RestrainedTaskLight"),
		},
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


## Compatibility alias for generic component validators. Every invocation is a
## recursive deep copy; callers cannot mutate component-owned audit state.
func audit() -> Dictionary:
	return get_audit_report().duplicate(true)


func _build_structural_core(dimensions: Dictionary) -> void:
	var length := _get_effective_segment_length()
	var crossface_span := float(dimensions["crossface_span"])
	var depth := float(dimensions["outward_depth"])
	var thickness := float(dimensions["frame_thickness"])
	_tag_visual_detail(
		_box(
			_structural_core_root,
			"UpperFascia",
			Vector3(0.0, -thickness * 0.75, thickness * 0.75),
			Vector3(length, thickness * 1.5, thickness * 1.5),
			_materials["frame"]
		),
		&"fascia",
		DetailQuality.LOW
	)
	_tag_visual_detail(
		_box(
			_structural_core_root,
			"OuterKeelChord",
			Vector3(0.0, -crossface_span * 0.54, depth - thickness * 0.62),
			Vector3(length * 0.96, thickness, thickness),
			_materials["frame_edge"]
		),
		&"keel_chord",
		DetailQuality.LOW
	)
	_tag_visual_detail(
		_box(
			_structural_core_root,
			"LowerKeelChord",
			Vector3(0.0, -crossface_span + thickness * 0.6, depth * 0.56),
			Vector3(length - thickness * 2.0, thickness * 1.1, thickness * 1.4),
			_materials["frame"]
		),
		&"keel_chord",
		DetailQuality.LOW
	)
	var first_x := -length * 0.5 + thickness
	var last_x := length * 0.5 - thickness
	var top_y := -thickness * 1.35
	var lower_y := -crossface_span + thickness * 1.3
	var brace_z := depth * 0.58
	for post_index in STRUCTURAL_POST_COUNT:
		var progress := float(post_index) / float(STRUCTURAL_POST_COUNT - 1)
		var post_x := lerpf(first_x, last_x, progress)
		_tag_visual_detail(
			_box(
				_structural_core_root,
				"KeelPost%02d" % (post_index + 1),
				Vector3(post_x, (top_y + lower_y) * 0.5, brace_z),
				Vector3(thickness, top_y - lower_y, thickness),
				_materials["frame_edge"]
			),
			&"keel_post",
			DetailQuality.LOW
		)
	for bay_index in STRUCTURAL_BAY_COUNT:
		var bay_start := lerpf(first_x, last_x, float(bay_index) / float(STRUCTURAL_BAY_COUNT))
		var bay_end := lerpf(first_x, last_x, float(bay_index + 1) / float(STRUCTURAL_BAY_COUNT))
		_tag_visual_detail(
			_cylinder_between(
				_structural_core_root,
				"CrossBraceA%02d" % (bay_index + 1),
				Vector3(bay_start, lower_y, brace_z),
				Vector3(bay_end, top_y, brace_z),
				thickness * 0.3,
				_materials["brace"]
			),
			&"cross_brace",
			DetailQuality.LOW
		)
		_tag_visual_detail(
			_cylinder_between(
				_structural_core_root,
				"CrossBraceB%02d" % (bay_index + 1),
				Vector3(bay_start, top_y, brace_z),
				Vector3(bay_end, lower_y, brace_z),
				thickness * 0.3,
				_materials["brace"]
			),
			&"cross_brace",
			DetailQuality.LOW
		)


func _build_service_detail(dimensions: Dictionary) -> void:
	var length := _get_effective_segment_length()
	var crossface_span := float(dimensions["crossface_span"])
	var depth := float(dimensions["outward_depth"])
	var thickness := float(dimensions["frame_thickness"])
	var conduit_length := length * 0.78
	var conduit_center_y := -minf(crossface_span * 0.34, 0.46)
	var conduit_spacing := maxf(0.09, thickness * 0.72)
	# Keep the deepest 0.25 m manifold box entirely on the outward side of the
	# attachment plane, including the shallow LIGHT profile.
	var conduit_z := maxf(depth * 0.2, 0.125)
	var conduit_materials := [
		_materials["conduit_dark"],
		_materials["conduit_cyan"],
		_materials["conduit_amber"],
	]
	for conduit_index in CONDUIT_COUNT:
		_tag_visual_detail(
			_cylinder(
				_service_detail_root,
				"Conduit%02d" % (conduit_index + 1),
				Vector3(0.0, conduit_center_y - conduit_spacing + conduit_spacing * conduit_index, conduit_z),
				0.032 + float(conduit_index) * 0.008,
				conduit_length,
				conduit_materials[conduit_index],
				Vector3(0.0, 0.0, 90.0)
			),
			&"conduit",
			DetailQuality.MEDIUM
		)
	for clamp_index in CONDUIT_CLAMP_COUNT:
		var clamp_progress := float(clamp_index + 1) / float(CONDUIT_CLAMP_COUNT + 1)
		_tag_visual_detail(
			_box(
				_service_detail_root,
				"ConduitClamp%02d" % (clamp_index + 1),
				Vector3(lerpf(-conduit_length * 0.5, conduit_length * 0.5, clamp_progress), conduit_center_y, conduit_z),
				Vector3(thickness * 0.42, conduit_spacing * 3.0, thickness * 0.58),
				_materials["frame_edge"]
			),
			&"conduit_clamp",
			DetailQuality.MEDIUM
		)
	var manifold_x := -conduit_length * 0.5
	_tag_visual_detail(
		_box(
			_service_detail_root,
			"ServiceManifold",
			Vector3(manifold_x, conduit_center_y, conduit_z),
			Vector3(0.34, conduit_spacing * 3.5, 0.25),
			_materials["frame_edge"]
		),
		&"conduit_manifold",
		DetailQuality.MEDIUM
	)
	for coupler_index in 2:
		_tag_visual_detail(
			_cylinder(
				_service_detail_root,
				"ManifoldCoupler%02d" % (coupler_index + 1),
				Vector3(manifold_x + (-0.22 if coupler_index == 0 else 0.22), conduit_center_y, conduit_z),
				0.07,
				0.18,
				_materials["conduit_amber"] if coupler_index == 0 else _materials["conduit_cyan"],
				Vector3(0.0, 0.0, 90.0)
			),
			&"conduit_coupler",
			DetailQuality.MEDIUM
		)

	var radiator_width := minf(3.1, maxf(1.8, length * 0.28))
	var radiator_height := crossface_span * 0.48
	var radiator_center := Vector3(length * 0.21, -crossface_span * 0.57, depth - 0.035)
	_tag_visual_detail(
		_box(
			_service_detail_root,
			"RadiatorBackplate",
			radiator_center,
			Vector3(radiator_width, radiator_height, 0.07),
			_materials["radiator"]
		),
		&"radiator_backplate",
		DetailQuality.MEDIUM
	)
	_radiator_vent_batch = _multimesh_rounded_box(
		_service_detail_root,
		"RadiatorVentBlades",
		_radiator_vent_mesh(),
		_materials["frame_edge"],
		_radiator_vent_transforms()
	)
	_tag_visual_batch(_radiator_vent_batch, &"radiator_vent", DetailQuality.MEDIUM)


func _build_high_detail(dimensions: Dictionary) -> void:
	var length := _get_effective_segment_length()
	var crossface_span := float(dimensions["crossface_span"])
	var depth := float(dimensions["outward_depth"])
	var thickness := float(dimensions["frame_thickness"])
	var strip_length := minf(1.4, length * 0.14)
	for strip_index in TASK_STRIP_COUNT:
		var side := -1.0 if strip_index == 0 else 1.0
		_tag_visual_detail(
			_box(
				_high_detail_root,
				"TaskStrip%02d" % (strip_index + 1),
				Vector3(side * length * 0.3, -thickness * 0.78, thickness * 1.54),
				Vector3(strip_length, 0.05, 0.025),
				_materials["task_strip"],
				false
			),
			&"task_strip",
			DetailQuality.HIGH
		)
	for fastener_index in FASCIA_FASTENER_COUNT:
		var progress := float(fastener_index + 1) / float(FASCIA_FASTENER_COUNT + 1)
		_tag_visual_detail(
			_fascia_fastener(
				_high_detail_root,
				"FasciaFastener%02d" % (fastener_index + 1),
				Vector3(lerpf(-length * 0.44, length * 0.44, progress), -thickness * 0.76, thickness * 1.57),
				_materials["frame_edge"]
			),
			&"fascia_fastener",
			DetailQuality.HIGH
		)
	_task_light = OmniLight3D.new()
	_task_light.name = "RestrainedTaskLight"
	_task_light.position = Vector3(0.0, -minf(0.3, crossface_span * 0.24), depth * 0.42)
	_task_light.light_color = Color("d8c89a")
	_task_light.light_energy = 0.22
	_task_light.omni_range = 2.6
	_task_light.omni_attenuation = 2.0
	_task_light.shadow_enabled = false
	_task_light.set_meta("presentation_only", true)
	_task_light.set_meta("evidence_status", EVIDENCE_STATUS)
	_task_light.set_meta("quality_tier", DetailQuality.HIGH)
	_high_detail_root.add_child(_task_light)


func _refresh_visibility() -> void:
	if _presentation_root == null:
		return
	_presentation_root.visible = _dressing_enabled
	_structural_core_root.visible = true
	_service_detail_root.visible = _quality_level >= DetailQuality.MEDIUM
	_high_detail_root.visible = _quality_level >= DetailQuality.HIGH


func _create_materials() -> void:
	# Roughness, not hue, is what tells a viewer which of these parts is a
	# galvanised structural member, which is a machined edge cap and which is a
	# thermal fin. The previous set answered light almost identically across the
	# whole component (0.34-0.66, and 0.34-0.42 across everything structural), so
	# the dressing read as one moulded object in several colours. The spread is
	# now 0.24-0.82, and the finish order is deliberate: radiator fin brightest,
	# machined edge next, painted brace and conduit sheath flattest.
	#
	# Metallic moves too, but only part of the way. The shipyard deck palette caps
	# at 0.32 because it is painted pressure panelling; this component is exposed
	# hardware bolted onto the outside of that panelling, so converging on the
	# deck's cap would erase a distinction that is real and worth keeping. What
	# was wrong was the magnitude: at 0.68-0.78 with no texture and no local
	# reflection detail, a StandardMaterial3D returns almost nothing but the sky
	# term and reads as flat dark plastic rather than steel. The structural
	# members now sit at 0.46-0.66 — still clearly above the deck, still legibly
	# metal, no longer black mirrors.
	# `frame`, `frame_edge` and `radiator` are lifted about 1.5x from their former
	# values because the station panel albedo they now bind is a mid-grey tile
	# that multiplies into them. Without the lift the textured members land at
	# roughly half their previous value and the dressing sinks into the deck
	# behind it; with it they hold their original apparent brightness and gain the
	# grain. This is the same reason the module shells author bright base colours
	# under the same tile.
	_materials["frame"] = _material(Color("3b5a68"), 0.52, 0.56)
	_materials["frame_edge"] = _material(Color("96b8c0"), 0.58, 0.31)
	_materials["brace"] = _material(Color("1b2a31"), 0.46, 0.68)
	_materials["conduit_dark"] = _material(Color("121a1f"), 0.24, 0.82)
	_materials["conduit_cyan"] = _material(Color("35747a"), 0.3, 0.42)
	_materials["conduit_amber"] = _material(Color("a46e35"), 0.28, 0.38)
	_materials["radiator"] = _material(Color("243740"), 0.66, 0.24)
	_materials["task_strip"] = _material(Color("665b3d"), 0.14, 0.3, Color("d8b96e"), 0.55)
	# The registered station panel family goes on the plate-stock roles only: the
	# fascia, keel chords and posts, the clamps, manifold, vent blades and
	# radiator backplate. These are the long, repeated, near-eye faces the player
	# reads from the branch arms and from the launch spine looking back, and they
	# are the ones the survey found untextured. The conduits and cross braces keep
	# their own untextured finish: they are extruded pipe and rod a few
	# centimetres across, and a metric plate grain on them would be a texture
	# applied to something that is not plate.
	# 0.22 m is the family's finest frozen scale, which suits members 0.11-0.17 m
	# thick better than the 0.28/0.30 wall scales.
	for panel_key in ["frame", "frame_edge", "radiator"]:
		StationSurfaceKit.apply_panel_triplanar(_materials[panel_key] as StandardMaterial3D, 0.22)


func _apply_evidence_metadata() -> void:
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("presentation_only", true)
	set_meta("provisional", true)
	set_meta("authenticated_original_geometry", false)
	set_meta("collision_free", true)
	set_meta("content_note", CONTENT_NOTE)
	for tier_root in [_structural_core_root, _service_detail_root, _high_detail_root]:
		tier_root.set_meta("component_id", COMPONENT_ID)
		tier_root.set_meta("evidence_status", EVIDENCE_STATUS)
		tier_root.set_meta("presentation_only", true)


func _get_feature_counts() -> Dictionary:
	return {
		"structural_posts": _structural_core_root.find_children("KeelPost*", "MeshInstance3D", true, false).size() if _structural_core_root != null else 0,
		"cross_braces": _structural_core_root.find_children("CrossBrace*", "MeshInstance3D", true, false).size() if _structural_core_root != null else 0,
		"conduits": _service_detail_root.find_children("Conduit??", "MeshInstance3D", true, false).size() if _service_detail_root != null else 0,
		"conduit_clamps": _service_detail_root.find_children("ConduitClamp*", "MeshInstance3D", true, false).size() if _service_detail_root != null else 0,
		"manifold_couplers": _service_detail_root.find_children("ManifoldCoupler*", "MeshInstance3D", true, false).size() if _service_detail_root != null else 0,
		"radiator_backplates": _service_detail_root.find_children("RadiatorBackplate", "MeshInstance3D", true, false).size() if _service_detail_root != null else 0,
		"radiator_vents": _radiator_vent_batch.multimesh.instance_count if is_instance_valid(_radiator_vent_batch) and _radiator_vent_batch.multimesh != null else 0,
		"task_strips": _high_detail_root.find_children("TaskStrip*", "MeshInstance3D", true, false).size() if _high_detail_root != null else 0,
		"fascia_fasteners": _high_detail_root.find_children("FasciaFastener*", "MeshInstance3D", true, false).size() if _high_detail_root != null else 0,
		"task_lights": 1 if is_instance_valid(_task_light) and is_ancestor_of(_task_light) else 0,
	}.duplicate(true)


func _required_node_contract_is_live() -> bool:
	return (
		get_node_or_null(^"MountAnchor") == _mount_anchor
		and get_node_or_null(^"DressingCenterAnchor") == _dressing_center_anchor
		and get_node_or_null(^"PresentationRoot") == _presentation_root
		and get_node_or_null(^"PresentationRoot/StructuralCoreRoot") == _structural_core_root
		and get_node_or_null(^"PresentationRoot/ServiceDetailRoot") == _service_detail_root
		and get_node_or_null(^"PresentationRoot/HighDetailRoot") == _high_detail_root
		and get_node_or_null(^"PresentationRoot/HighDetailRoot/RestrainedTaskLight") == _task_light
		and is_instance_valid(_mount_anchor) and is_ancestor_of(_mount_anchor)
		and is_instance_valid(_dressing_center_anchor) and is_ancestor_of(_dressing_center_anchor)
		and is_instance_valid(_presentation_root) and is_ancestor_of(_presentation_root)
		and is_instance_valid(_structural_core_root) and _presentation_root.is_ancestor_of(_structural_core_root)
		and is_instance_valid(_service_detail_root) and _presentation_root.is_ancestor_of(_service_detail_root)
		and is_instance_valid(_high_detail_root) and _presentation_root.is_ancestor_of(_high_detail_root)
		and is_instance_valid(_task_light) and _high_detail_root.is_ancestor_of(_task_light)
	)


func _required_node_transforms_match_build() -> bool:
	if not _required_node_contract_is_live():
		return false
	var dimensions := _get_profile_dimensions()
	var expected_center := _get_orientation_basis() * Vector3(
		0.0,
		-float(dimensions["crossface_span"]) * 0.5,
		float(dimensions["outward_depth"]) * 0.5
	)
	var expected_light_position := Vector3(
		0.0,
		-minf(0.3, float(dimensions["crossface_span"]) * 0.24),
		float(dimensions["outward_depth"]) * 0.42
	)
	return (
		_mount_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
		and _presentation_root.transform.is_equal_approx(Transform3D(_get_orientation_basis(), Vector3.ZERO))
		and _dressing_center_anchor.transform.is_equal_approx(Transform3D(_get_orientation_basis(), expected_center))
		and _structural_core_root.transform.is_equal_approx(Transform3D.IDENTITY)
		and _service_detail_root.transform.is_equal_approx(Transform3D.IDENTITY)
		and _high_detail_root.transform.is_equal_approx(Transform3D.IDENTITY)
		and _task_light.position.is_equal_approx(expected_light_position)
	)


func _visibility_contract_matches_lifecycle() -> bool:
	if not _required_node_contract_is_live():
		return false
	return (
		_presentation_root.visible == _dressing_enabled
		and _structural_core_root.visible
		and _service_detail_root.visible == (_quality_level >= DetailQuality.MEDIUM)
		and _high_detail_root.visible == (_quality_level >= DetailQuality.HIGH)
		and _task_light.visible
		and (
			not is_inside_tree()
			or _task_light.is_visible_in_tree()
				== (_dressing_enabled and _quality_level >= DetailQuality.HIGH)
		)
	)


func _capture_built_presentation_contract() -> void:
	_built_node_instance_ids.clear()
	_built_node_transforms.clear()
	_built_mesh_contracts.clear()
	_built_material_contracts.clear()
	for candidate in find_children("*", "", true, false):
		var relative_path := str(get_path_to(candidate))
		_built_node_instance_ids[relative_path] = candidate.get_instance_id()
		if candidate is Node3D:
			_built_node_transforms[relative_path] = (candidate as Node3D).transform
		if candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			_built_mesh_contracts[relative_path] = {
				"instance_id": mesh_instance.get_instance_id(),
				"transform": mesh_instance.transform,
				"mesh_instance_id": (
					mesh_instance.mesh.get_instance_id() if mesh_instance.mesh != null else 0
				),
				"mesh_class": mesh_instance.mesh.get_class() if mesh_instance.mesh != null else "",
				"mesh_aabb": mesh_instance.mesh.get_aabb() if mesh_instance.mesh != null else AABB(),
				"mesh_storage": _resource_storage_fingerprint(mesh_instance.mesh),
				"material_instance_id": (
					mesh_instance.material_override.get_instance_id()
					if mesh_instance.material_override != null else 0
				),
				"cast_shadow": mesh_instance.cast_shadow,
				"layers": mesh_instance.layers,
				"visibility_range_begin": mesh_instance.visibility_range_begin,
				"visibility_range_end": mesh_instance.visibility_range_end,
				"visibility_range_begin_margin": mesh_instance.visibility_range_begin_margin,
				"visibility_range_end_margin": mesh_instance.visibility_range_end_margin,
				"visibility_range_fade_mode": mesh_instance.visibility_range_fade_mode,
				"transparency": mesh_instance.transparency,
				"flip_faces": (
					(mesh_instance.mesh as PrimitiveMesh).flip_faces
					if mesh_instance.mesh is PrimitiveMesh else false
				),
			}
	for material_key in _materials:
		var material := _materials[material_key] as StandardMaterial3D
		if material != null:
			_built_material_contracts[material_key] = _standard_material_contract(material)
	_built_task_light_contract = {
		"instance_id": _task_light.get_instance_id(),
		"energy": _task_light.light_energy,
		"range": _task_light.omni_range,
		"attenuation": _task_light.omni_attenuation,
		"color": _task_light.light_color,
		"shadow": _task_light.shadow_enabled,
		"cull_mask": _task_light.light_cull_mask,
		"negative": _task_light.light_negative,
	}


func _built_presentation_hierarchy_is_live() -> bool:
	if not _built or _built_node_instance_ids.is_empty():
		return false
	var live_nodes := find_children("*", "", true, false)
	if live_nodes.size() != _built_node_instance_ids.size():
		return false
	for relative_path_value in _built_node_instance_ids:
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if (
			not is_instance_valid(candidate)
			or candidate.get_instance_id() != int(_built_node_instance_ids[relative_path_value])
			or not is_ancestor_of(candidate)
		):
			return false
	for relative_path_value in _built_node_transforms:
		var candidate := get_node_or_null(NodePath(str(relative_path_value))) as Node3D
		if (
			not is_instance_valid(candidate)
			or not candidate.transform.is_equal_approx(
				_built_node_transforms[relative_path_value] as Transform3D
			)
		):
			return false
	return true


func _built_mesh_contracts_are_live() -> bool:
	if _built_mesh_contracts.is_empty():
		return false
	for relative_path_value in _built_mesh_contracts:
		var contract := _built_mesh_contracts[relative_path_value] as Dictionary
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if not candidate is MeshInstance3D:
			return false
		var mesh_instance := candidate as MeshInstance3D
		if (
			mesh_instance.get_instance_id() != int(contract.get("instance_id", 0))
			or not mesh_instance.visible
			or mesh_instance.mesh == null
			or mesh_instance.mesh.get_instance_id() != int(contract.get("mesh_instance_id", 0))
			or mesh_instance.mesh.get_class() != str(contract.get("mesh_class", ""))
			or not mesh_instance.mesh.get_aabb().is_equal_approx(contract.get("mesh_aabb", AABB()) as AABB)
			or _resource_storage_fingerprint(mesh_instance.mesh)
				!= (contract.get("mesh_storage", PackedStringArray()) as PackedStringArray)
			or not mesh_instance.transform.is_equal_approx(contract.get("transform", Transform3D.IDENTITY) as Transform3D)
			or mesh_instance.material_override == null
			or mesh_instance.material_override.get_instance_id() != int(contract.get("material_instance_id", 0))
			or mesh_instance.cast_shadow != int(contract.get("cast_shadow", -1))
			or mesh_instance.layers != int(contract.get("layers", 0))
			or not is_equal_approx(mesh_instance.visibility_range_begin, float(contract.get("visibility_range_begin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end, float(contract.get("visibility_range_end", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_begin_margin, float(contract.get("visibility_range_begin_margin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end_margin, float(contract.get("visibility_range_end_margin", 0.0)))
			or mesh_instance.visibility_range_fade_mode != int(contract.get("visibility_range_fade_mode", -1))
			or not is_equal_approx(mesh_instance.transparency, float(contract.get("transparency", 0.0)))
			or (
				mesh_instance.mesh is PrimitiveMesh
				and (mesh_instance.mesh as PrimitiveMesh).flip_faces
					!= bool(contract.get("flip_faces", false))
			)
		):
			return false
	return _materials_match_build_contract() and _task_light_matches_build_contract()


func _standard_material_contract(material: StandardMaterial3D) -> Dictionary:
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"transparency": material.transparency,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"cull_mode": material.cull_mode,
		"shading_mode": material.shading_mode,
		"vertex_color_use_as_albedo": material.vertex_color_use_as_albedo,
		"vertex_color_is_srgb": material.vertex_color_is_srgb,
		"distance_fade_mode": material.distance_fade_mode,
		"storage": _resource_storage_fingerprint(material),
	}


func _materials_match_build_contract() -> bool:
	if _built_material_contracts.size() != _materials.size():
		return false
	for material_key in _built_material_contracts:
		var material := _materials.get(material_key) as StandardMaterial3D
		var contract := _built_material_contracts[material_key] as Dictionary
		if (
			material == null
			or material.get_instance_id() != int(contract.get("instance_id", 0))
			or not material.albedo_color.is_equal_approx(contract.get("albedo_color", Color.TRANSPARENT) as Color)
			or not is_equal_approx(material.metallic, float(contract.get("metallic", 0.0)))
			or not is_equal_approx(material.roughness, float(contract.get("roughness", 0.0)))
			or material.transparency != int(contract.get("transparency", -1))
			or material.cull_mode != int(contract.get("cull_mode", -1))
			or material.shading_mode != int(contract.get("shading_mode", -1))
			or material.vertex_color_use_as_albedo != bool(contract.get("vertex_color_use_as_albedo", false))
			or material.vertex_color_is_srgb != bool(contract.get("vertex_color_is_srgb", false))
			or material.distance_fade_mode != int(contract.get("distance_fade_mode", -1))
			or material.emission_enabled != bool(contract.get("emission_enabled", false))
			or not material.emission.is_equal_approx(contract.get("emission", Color.TRANSPARENT) as Color)
			or not is_equal_approx(material.emission_energy_multiplier, float(contract.get("emission_energy", 0.0)))
			or _resource_storage_fingerprint(material)
				!= (contract.get("storage", PackedStringArray()) as PackedStringArray)
		):
			return false
	return true


func _resource_storage_fingerprint(resource: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	if resource == null:
		return result
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		result.append("%s=%s" % [property_name, var_to_str(resource.get(property_name))])
	result.sort()
	return result


func _task_light_matches_build_contract() -> bool:
	return (
		is_instance_valid(_task_light)
		and _task_light.get_instance_id() == int(_built_task_light_contract.get("instance_id", 0))
		and is_equal_approx(_task_light.light_energy, float(_built_task_light_contract.get("energy", 0.0)))
		and is_equal_approx(_task_light.omni_range, float(_built_task_light_contract.get("range", 0.0)))
		and is_equal_approx(_task_light.omni_attenuation, float(_built_task_light_contract.get("attenuation", 0.0)))
		and _task_light.light_color.is_equal_approx(_built_task_light_contract.get("color", Color.TRANSPARENT) as Color)
		and _task_light.shadow_enabled == bool(_built_task_light_contract.get("shadow", true))
		and _task_light.light_cull_mask == int(_built_task_light_contract.get("cull_mask", 0))
		and _task_light.light_negative == bool(_built_task_light_contract.get("negative", true))
	)


func _all_live_meshes_fit_published_footprint() -> bool:
	if (
		not _required_node_contract_is_live()
		or not _built_presentation_hierarchy_is_live()
		or not _built_mesh_contracts_are_live()
	):
		return false
	var footprint := get_local_footprint().grow(0.015)
	var mesh_count := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			return false
		var relative_transform_value: Variant = _node_transform_relative_to_component(mesh_instance)
		if not relative_transform_value is Transform3D:
			return false
		var relative_transform := relative_transform_value as Transform3D
		var bounds := mesh_instance.get_aabb()
		for corner_index in 8:
			var corner := bounds.position + Vector3(
				bounds.size.x if corner_index & 1 else 0.0,
				bounds.size.y if corner_index & 2 else 0.0,
				bounds.size.z if corner_index & 4 else 0.0
			)
			if not footprint.has_point(relative_transform * corner):
				return false
		mesh_count += 1
	for candidate in find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			return false
		var relative_transform_value: Variant = _node_transform_relative_to_component(batch)
		if not relative_transform_value is Transform3D:
			return false
		var relative_transform := relative_transform_value as Transform3D
		var mesh_bounds := batch.multimesh.mesh.get_aabb()
		var authored_transforms := batch.get_meta("authored_instance_transforms", []) as Array
		if authored_transforms.size() != batch.multimesh.instance_count:
			return false
		for instance_index in batch.multimesh.instance_count:
			if not authored_transforms[instance_index] is Transform3D:
				return false
			var instance_transform := authored_transforms[instance_index] as Transform3D
			for corner_index in 8:
				var corner := mesh_bounds.position + Vector3(
					mesh_bounds.size.x if corner_index & 1 else 0.0,
					mesh_bounds.size.y if corner_index & 2 else 0.0,
					mesh_bounds.size.z if corner_index & 4 else 0.0
				)
				if not footprint.has_point(relative_transform * instance_transform * corner):
					return false
		mesh_count += batch.multimesh.instance_count
	return mesh_count == TOTAL_VISIBLE_PRIMITIVE_COUNT


func _node_transform_relative_to_component(node: Node3D) -> Variant:
	if not is_ancestor_of(node):
		return null
	var relative_transform := Transform3D.IDENTITY
	var current: Node = node
	while current != self:
		if not current is Node3D:
			return null
		relative_transform = (current as Node3D).transform * relative_transform
		current = current.get_parent()
		if current == null:
			return null
	return relative_transform


func _count_runtime_resources(node: Node, counts: Dictionary, material_ids: Dictionary) -> void:
	counts["node_count"] = int(counts["node_count"]) + 1
	if node is MeshInstance3D:
		counts["mesh_instances"] = int(counts["mesh_instances"]) + 1
		counts["geometry_submissions"] = int(counts["geometry_submissions"]) + 1
		if (node as MeshInstance3D).is_visible_in_tree():
			counts["visible_primitives"] = int(counts["visible_primitives"]) + 1
		var material := (node as MeshInstance3D).material_override
		if material != null:
			material_ids[material.get_instance_id()] = true
	if node is MultiMeshInstance3D:
		var batch := node as MultiMeshInstance3D
		counts["multimesh_batches"] = int(counts["multimesh_batches"]) + 1
		counts["geometry_submissions"] = int(counts["geometry_submissions"]) + 1
		if batch.is_visible_in_tree() and batch.multimesh != null:
			counts["visible_primitives"] = int(counts["visible_primitives"]) + batch.multimesh.visible_instance_count
		if batch.material_override != null:
			material_ids[batch.material_override.get_instance_id()] = true
	if node is Light3D:
		counts["lights"] = int(counts["lights"]) + 1
		if (node as Light3D).is_visible_in_tree():
			counts["visible_lights"] = int(counts["visible_lights"]) + 1
		if (node as Light3D).shadow_enabled:
			counts["shadow_casting_lights"] = int(counts["shadow_casting_lights"]) + 1
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		counts["collision_nodes"] = int(counts["collision_nodes"]) + 1
	if node is GPUParticles3D or node is CPUParticles3D:
		counts["particle_emitters"] = int(counts["particle_emitters"]) + 1
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		counts["audio_nodes"] = int(counts["audio_nodes"]) + 1
	if node is ReflectionProbe:
		counts["reflection_probes"] = int(counts["reflection_probes"]) + 1
	if node is AnimationPlayer:
		counts["animation_players"] = int(counts["animation_players"]) + 1
	if node is Label3D or (node is MeshInstance3D and (node as MeshInstance3D).mesh is TextMesh):
		counts["text_nodes"] = int(counts["text_nodes"]) + 1
	for child in node.get_children():
		_count_runtime_resources(child, counts, material_ids)


func _get_profile_dimensions() -> Dictionary:
	return (_get_configuration_snapshot()["profile_dimensions"] as Dictionary).duplicate(true)


func _get_profile_dimensions_for(profile_value: int) -> Dictionary:
	match profile_value:
		StructuralProfile.LIGHT:
			return {"crossface_span": 0.82, "outward_depth": 0.58, "frame_thickness": 0.11}
		StructuralProfile.DEEP:
			return {"crossface_span": 1.34, "outward_depth": 1.02, "frame_thickness": 0.17}
		_:
			return {"crossface_span": 1.08, "outward_depth": 0.78, "frame_thickness": 0.14}


func _get_effective_segment_length() -> float:
	return float(_get_configuration_snapshot()["segment_length"])


func _get_orientation_basis() -> Basis:
	return _get_configuration_snapshot()["orientation_basis"] as Basis


func _get_segment_axis_local() -> Vector3:
	return (_get_orientation_basis() * Vector3.RIGHT).normalized()


func _get_crossface_axis_local() -> Vector3:
	return (_get_orientation_basis() * Vector3.DOWN).normalized()


func _get_outward_axis_local() -> Vector3:
	return (_get_orientation_basis() * Vector3.BACK).normalized()


func _get_configuration_snapshot() -> Dictionary:
	return _built_configuration if not _built_configuration.is_empty() else _make_configuration_snapshot()


func _make_configuration_snapshot() -> Dictionary:
	var length := (
		DEFAULT_SEGMENT_LENGTH
		if not is_finite(segment_length)
		else clampf(segment_length, MINIMUM_SEGMENT_LENGTH, MAXIMUM_SEGMENT_LENGTH)
	)
	var profile_value := structural_profile if _is_valid_profile(structural_profile) else StructuralProfile.STANDARD
	var orientation_value := segment_orientation if _is_valid_orientation(segment_orientation) else SegmentOrientation.ALONG_MOUNT_X
	var dimensions := _get_profile_dimensions_for(profile_value)
	var orientation_basis := (
		Basis(Vector3.BACK, PI * 0.5)
		if orientation_value == SegmentOrientation.ALONG_MOUNT_Y
		else Basis.IDENTITY
	)
	var crossface_span := float(dimensions["crossface_span"])
	var depth := float(dimensions["outward_depth"]) + 0.08
	var footprint := (
		AABB(Vector3(0.0, -length * 0.5, 0.0), Vector3(crossface_span + 0.05, length, depth))
		if orientation_value == SegmentOrientation.ALONG_MOUNT_Y
		else AABB(Vector3(-length * 0.5, -crossface_span - 0.05, 0.0), Vector3(length, crossface_span + 0.05, depth))
	)
	return {
		"segment_length": length,
		"structural_profile": profile_value,
		"structural_profile_name": _get_profile_name(profile_value),
		"segment_orientation": orientation_value,
		"segment_orientation_name": _get_orientation_name(orientation_value),
		"orientation_basis": orientation_basis,
		"segment_axis_local": (orientation_basis * Vector3.RIGHT).normalized(),
		"crossface_axis_local": (orientation_basis * Vector3.DOWN).normalized(),
		"outward_axis_local": (orientation_basis * Vector3.BACK).normalized(),
		"profile_dimensions": dimensions.duplicate(true),
		"local_footprint": footprint,
	}.duplicate(true)


func _live_structural_configuration_matches_build_snapshot() -> bool:
	if _built_configuration.is_empty():
		return true
	return (
		segment_length == float(_built_configuration["segment_length"])
		and structural_profile == int(_built_configuration["structural_profile"])
		and segment_orientation == int(_built_configuration["segment_orientation"])
	)


func _is_valid_profile(value: int) -> bool:
	return value in [StructuralProfile.LIGHT, StructuralProfile.STANDARD, StructuralProfile.DEEP]


func _is_valid_orientation(value: int) -> bool:
	return value in [SegmentOrientation.ALONG_MOUNT_X, SegmentOrientation.ALONG_MOUNT_Y]


func _is_valid_quality(value: int) -> bool:
	return value in [DetailQuality.LOW, DetailQuality.MEDIUM, DetailQuality.HIGH]


func _get_profile_name(value: int) -> StringName:
	match value:
		StructuralProfile.LIGHT:
			return &"light"
		StructuralProfile.DEEP:
			return &"deep"
		_:
			return &"standard"


func _get_orientation_name(value: int) -> StringName:
	return &"along_mount_y" if value == SegmentOrientation.ALONG_MOUNT_Y else &"along_mount_x"


func _get_quality_name(value: int) -> StringName:
	match value:
		DetailQuality.LOW:
			return &"low"
		DetailQuality.MEDIUM:
			return &"medium"
		_:
			return &"high"


func _radiator_vent_mesh() -> ArrayMesh:
	var dimensions := _get_profile_dimensions()
	return StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.075, float(dimensions["crossface_span"]) * 0.48 * 0.82, 0.045),
		_rounded_box_cache
	)


func _radiator_vent_transforms() -> Array[Transform3D]:
	var dimensions := _get_profile_dimensions()
	var length := _get_effective_segment_length()
	var crossface_span := float(dimensions["crossface_span"])
	var depth := float(dimensions["outward_depth"])
	var radiator_width := minf(3.1, maxf(1.8, length * 0.28))
	var radiator_center := Vector3(length * 0.21, -crossface_span * 0.57, depth - 0.035)
	var transforms: Array[Transform3D] = []
	for vent_index in RADIATOR_VENT_COUNT:
		var vent_progress := float(vent_index + 1) / float(RADIATOR_VENT_COUNT + 1)
		transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(
				radiator_center.x + lerpf(-radiator_width * 0.5, radiator_width * 0.5, vent_progress),
				radiator_center.y,
				depth + 0.012
			)
		))
	return transforms


func _multimesh_rounded_box(
		parent: Node3D,
		node_name: String,
		mesh: ArrayMesh,
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
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _tag_visual_batch(node: MultiMeshInstance3D, role: StringName, quality_tier: int) -> void:
	node.set_meta("component_id", COMPONENT_ID)
	node.set_meta("evidence_status", EVIDENCE_STATUS)
	node.set_meta("presentation_only", true)
	node.set_meta("collision_free", true)
	node.set_meta("detail_role", role)
	node.set_meta("quality_tier", quality_tier)


static func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	var offset := 0
	for transform_value in transforms:
		for row in 3:
			buffer[offset] = transform_value.basis.x[row]
			buffer[offset + 1] = transform_value.basis.y[row]
			buffer[offset + 2] = transform_value.basis.z[row]
			buffer[offset + 3] = transform_value.origin[row]
			offset += 4
	return buffer


static func _transformed_mesh_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
	var bounds := AABB()
	var initialized := false
	for transform_value in transforms:
		for corner_index in 8:
			var corner := mesh_bounds.position + Vector3(
				mesh_bounds.size.x if corner_index & 1 else 0.0,
				mesh_bounds.size.y if corner_index & 2 else 0.0,
				mesh_bounds.size.z if corner_index & 4 else 0.0
			)
			var point := transform_value * corner
			if initialized:
				bounds = bounds.expand(point)
			else:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
	return bounds


func _tag_visual_detail(node: MeshInstance3D, role: StringName, quality_tier: int) -> void:
	node.set_meta("component_id", COMPONENT_ID)
	node.set_meta("evidence_status", EVIDENCE_STATUS)
	node.set_meta("presentation_only", true)
	node.set_meta("collision_free", true)
	node.set_meta("detail_role", role)
	node.set_meta("quality_tier", quality_tier)


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
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		cast_shadow: bool = true
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	# Chamfered, not raw. This component is the outer face of the modules, so its
	# members are seen end-on and in repetition from the branch arms and from the
	# launch spine looking back; an unbroken 90 degree edge on a repeated member
	# is the loudest untooled-primitive cue the silhouette has. The chamfer is an
	# edge treatment only: `StationSurfaceKit.rounded_box_mesh` keeps the outer
	# extents identical to the equivalent `BoxMesh`, so the published footprint,
	# the mesh-corner AABB and the collision-free contract are all unmoved.
	mesh_instance.mesh = StationSurfaceKit.rounded_box_mesh_cached(size, _rounded_box_cache)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(mesh_instance, true)
	return mesh_instance


func _cylinder(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		radius: float,
		height: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO,
		cast_shadow: bool = true
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_degrees_value
	# Eight segments is a visible octagon on a 0.07 m manifold coupler or a
	# 0.042 m cross brace at the ranges these are seen from. Sixteen still has its
	# cardinal vertices, so the mesh AABB — and therefore the published footprint
	# check — is bit-identical to the eight-segment ring it replaced.
	#
	# The rims are now chamfered too. This is the thinnest stock in the station —
	# 0.025 m conduit — and it is exactly why the kit's rim rule has no minimum
	# bevel: at 0.22 proportional these caps give up 0.0055 m and stay caps,
	# where the box family's 0.012 m floor would have taken half the radius.
	# The chamfer consumes cap radius and lateral height only; the outer radius
	# and the overall height are untouched, so the published footprint still
	# matches.
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 16, _chamfered_cylinder_cache, 1
	)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(mesh_instance, true)
	return mesh_instance


func _fascia_fastener(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		material: Material
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_instance.mesh = _shared_fascia_fastener_mesh()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance, true)
	return mesh_instance


static func _shared_fascia_fastener_mesh() -> ArrayMesh:
	return StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.025, 0.025, 0.025, 16, _fascia_fastener_mesh_cache, 1
	)


func _cylinder_between(
		parent: Node3D,
		node_name: String,
		from: Vector3,
		to: Vector3,
		radius: float,
		material: Material
	) -> MeshInstance3D:
	var direction := to - from
	var beam := _cylinder(parent, node_name, (from + to) * 0.5, radius, direction.length(), material)
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return beam
