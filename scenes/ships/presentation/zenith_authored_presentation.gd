class_name ZenithAuthoredPresentation
extends Node3D

## Visual-only boundary for the B7-observed Zenith authored-art package.
##
## Imported art never owns collision, cameras, weapons, docking, damage, flight,
## boarding or other gameplay state. `SourceCore` is the evidence-bounded pale
## macroform; every inferred functional design lives in removable sibling
## `ModernSystems`.

signal lod_changed(lod_index: int)

const SCHEMA_VERSION := 1
const ASSET_ID := &"mudds.ship.zenith.b7_authored.v1"
const ASSET_PATH := "res://assets/models/zenith/zenith_authored_art.glb"
const SOURCE_PATH := "res://art_source/zenith/zenith_authored_v1.blend"
const MANIFEST_PATH := "res://assets/models/zenith/zenith_authored_asset_manifest.json"
const EVIDENCE_SCOPE := &"B7_frames_373_467_only"
const HULL_ALBEDO_PATH := "res://assets/materials/torrent-hull-albedo-v1.png"
const HULL_NORMAL_PATH := "res://assets/materials/torrent-hull-normal-v1.png"
const HULL_ROUGHNESS_PATH := "res://assets/materials/torrent-hull-roughness-v1.png"

const EXPECTED_MINIMUM := Vector3(-7.20, -1.05, -5.35)
const EXPECTED_MAXIMUM := Vector3(7.20, 3.20, 5.30)
const CLOSE_TRIANGLE_RANGE := Vector2i(45_000, 75_000)
const FAR_TRIANGLE_RANGE := Vector2i(5_000, 10_000)
const RUNTIME_MESH_BUDGET := 30
const RUNTIME_SURFACE_BUDGET := 30
const CANOPY_OPEN_ANGLE_RADIANS := deg_to_rad(63.0)

const MATERIAL_ROLES := [
	"PaleCeramicHull",
	"PaleFacetSecondary",
	"GraphitePanel",
	"EngineGraphite",
	"ExposedAlloy",
	"CanopyGlass",
	"EngineEmission",
	"PortNavRed",
	"StarboardNavGreen",
	"CockpitEmission",
]
const SOURCE_MATERIAL_ROLES := [&"PaleCeramicHull", &"PaleFacetSecondary"]
const MODERN_MATERIAL_ROLES := [
	&"GraphitePanel", &"EngineGraphite", &"ExposedAlloy", &"CanopyGlass", &"EngineEmission",
	&"PortNavRed", &"StarboardNavGreen", &"CockpitEmission",
]
const REQUIRED_ANCHORS := {
	&"PilotSeatAnchor": Vector3(0.0, 1.58, -0.55),
	&"BoardingEntry": Vector3(-1.18, 1.62, -0.32),
	&"BoardingPoint": Vector3(-7.65, -0.55, 0.55),
	&"ExitPoint": Vector3(-7.85, -0.55, 0.85),
	&"LeftMuzzle": Vector3(-1.25, 0.34, -4.25),
	&"RightMuzzle": Vector3(1.25, 0.34, -4.25),
	&"CockpitCamera": Vector3(0.0, 2.28, -1.24),
	&"DockingReceiver": Vector3(0.0, -0.82, 1.05),
	&"DamageCenter": Vector3(0.0, 0.48, 0.0),
	&"DamagePortWing": Vector3(-4.55, 0.18, 0.20),
	&"DamageStarboardWing": Vector3(4.55, 0.18, 0.20),
	&"PortEnginePlume": Vector3(-2.20, 0.38, 4.95),
	&"StarboardEnginePlume": Vector3(2.20, 0.38, 4.95),
}
const PROTECTED_PLUMES := [
	"PortEnginePlume",
	"StarboardEnginePlume",
	"LOD1PortEnginePlume",
	"LOD1StarboardEnginePlume",
]

@export_range(15.0, 150.0, 0.5) var lod_switch_distance := 48.0
@export_range(0.0, 20.0, 0.5) var lod_hysteresis := 5.0

var _imported_container: Node3D
var _asset_root: Node3D
var _source_core: Node3D
var _modern_systems: Node3D
var _source_lod0: Node3D
var _source_lod1: Node3D
var _modern_lod0: Node3D
var _modern_lod1: Node3D
var _canopy_pivot: Node3D
var _semantic_anchors: Node3D
var _runtime_materials: Dictionary = {}
var _manifest: Dictionary = {}
var _integrity_nodes: Dictionary = {}
var _integrity_meshes: Dictionary = {}
var _integrity_materials: Dictionary = {}
var _plume_base_poses: Dictionary = {}
var _canopy_base_transform := Transform3D.IDENTITY
var _authored_bounds: Dictionary = {}
var _active_lod := 0
var _canopy_fraction := 0.0
var _built := false
var _built_lod_switch_distance := 0.0
var _built_lod_hysteresis := 0.0


func _ready() -> void:
	_build_once()
	_apply_lod(0)
	set_process(true)


func _process(_delta: float) -> void:
	if not _built or _asset_root == null:
		return
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null:
		update_lod_for_distance(camera.global_position.distance_to(global_position))


func _build_once() -> void:
	if _built:
		return
	_built = true
	_manifest = _read_json(MANIFEST_PATH)
	var packed := load(ASSET_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load the Blender-authored Zenith asset")
		return
	_imported_container = packed.instantiate() as Node3D
	if _imported_container == null:
		push_error("Unable to instantiate the Blender-authored Zenith asset")
		return
	_imported_container.name = "ZenithAuthoredImport"
	add_child(_imported_container)
	_asset_root = _imported_container.get_node_or_null(^"ZenithAuthoredArt") as Node3D
	if _asset_root == null:
		_asset_root = _imported_container.find_child("ZenithAuthoredArt", true, false) as Node3D
	if _asset_root == null:
		push_error("Blender-authored Zenith hierarchy root is missing")
		return
	_source_core = _asset_root.get_node_or_null(^"SourceCore") as Node3D
	_modern_systems = _asset_root.get_node_or_null(^"ModernSystems") as Node3D
	_source_lod0 = _source_core.get_node_or_null(^"LOD0") as Node3D if _source_core != null else null
	_source_lod1 = _source_core.get_node_or_null(^"LOD1") as Node3D if _source_core != null else null
	# Godot's glTF importer makes duplicate names globally unique even though the
	# two LOD pairs are in different branches. Normalize those imported aliases
	# back to the public hierarchy contract on this private scene instance.
	if _modern_systems != null:
		_modern_lod0 = _modern_systems.get_node_or_null(^"LOD0") as Node3D
		if _modern_lod0 == null:
			_modern_lod0 = _modern_systems.get_node_or_null(^"LOD0_001") as Node3D
		if _modern_lod0 != null:
			_modern_lod0.name = "LOD0"
		_modern_lod1 = _modern_systems.get_node_or_null(^"LOD1") as Node3D
		if _modern_lod1 == null:
			_modern_lod1 = _modern_systems.get_node_or_null(^"LOD1_001") as Node3D
		if _modern_lod1 != null:
			_modern_lod1.name = "LOD1"
		_canopy_pivot = _modern_systems.get_node_or_null(^"CanopyPivot") as Node3D
		_semantic_anchors = _modern_systems.get_node_or_null(^"SemanticAnchors") as Node3D
	if _semantic_anchors != null:
		for anchor_name: StringName in [&"PortEnginePlume", &"StarboardEnginePlume"]:
			if _semantic_anchors.get_node_or_null(NodePath(String(anchor_name))) == null:
				var imported_alias := _semantic_anchors.get_node_or_null(
					NodePath(String(anchor_name) + "_001")
				) as Node3D
				if imported_alias != null:
					imported_alias.name = String(anchor_name)
	_configure_runtime_materials()
	_disable_per_surface_lod()
	_authored_bounds = _runtime_bounds(_asset_root)
	_canopy_base_transform = _canopy_pivot.transform if _canopy_pivot != null else Transform3D.IDENTITY
	_built_lod_switch_distance = lod_switch_distance
	_built_lod_hysteresis = lod_hysteresis
	_capture_integrity_contract()


func _configure_runtime_materials() -> void:
	_runtime_materials = {
		# B7 supports a pale off-white/light-grey dominant exterior as a relative
		# value only; it establishes no albedo swatch, paint system or weathering
		# level (docs/ZENITH_B7_RECONSTRUCTION_SPEC.md). These modern tints stay
		# inside that pale read while moving off the fleet's shared warm ivory so
		# the four craft separate at a glance; see the frozen floors in
		# tests/fleet_role_differentiation_test.gd.
		&"PaleCeramicHull": _hull_material(Color("bac8d6"), 0.10, 0.43, 0.18),
		&"PaleFacetSecondary": _hull_material(Color("97a3ad"), 0.14, 0.49, 0.10),
		&"GraphitePanel": _pbr_material(Color(0.075, 0.095, 0.105), 0.48, 0.43),
		&"EngineGraphite": _pbr_material(Color(0.115, 0.140, 0.150), 0.46, 0.52),
		&"ExposedAlloy": _pbr_material(Color("384244"), 0.82, 0.24),
		&"CanopyGlass": _canopy_material(),
		&"EngineEmission": _emissive_material(Color("05343c"), Color("07bddc"), 3.1),
		&"PortNavRed": _emissive_material(Color("6b0506"), Color("ff0305"), 2.6),
		&"StarboardNavGreen": _emissive_material(Color("03501a"), Color("04f230"), 2.6),
		&"CockpitEmission": _emissive_material(Color("052d35"), Color("06a8c2"), 1.9),
	}
	if _asset_root == null:
		return
	for candidate in _asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var imported_material := mesh_instance.get_active_material(0)
		var role := StringName(imported_material.resource_name) if imported_material != null else &""
		var replacement := _runtime_materials.get(role) as Material
		if replacement != null:
			mesh_instance.material_override = replacement
			mesh_instance.set_meta("zenith_material_role", role)
			mesh_instance.set_meta("presentation_only", true)
			mesh_instance.set_meta("gameplay_authority", false)
			if role in [&"CanopyGlass", &"EngineEmission", &"PortNavRed", &"StarboardNavGreen", &"CockpitEmission"]:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pbr_material(color: Color, metallic_value: float, roughness_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material


func _hull_material(
	color: Color,
	metallic_value: float,
	roughness_value: float,
	normal_strength: float
) -> StandardMaterial3D:
	var material := _pbr_material(color, metallic_value, roughness_value)
	material.albedo_texture = load(HULL_ALBEDO_PATH) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(HULL_NORMAL_PATH) as Texture2D
	material.normal_scale = normal_strength
	material.roughness_texture = load(HULL_ROUGHNESS_PATH) as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.clearcoat_enabled = true
	material.clearcoat = 0.25
	material.clearcoat_roughness = 0.32
	return material


func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _pbr_material(color, 0.10, 0.25)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _canopy_material() -> StandardMaterial3D:
	var material := _pbr_material(Color(0.035, 0.16, 0.19, 0.22), 0.14, 0.07)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


func _disable_per_surface_lod() -> void:
	if _asset_root == null:
		return
	for candidate in _asset_root.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		geometry.visibility_range_begin = 0.0
		geometry.visibility_range_end = 0.0
		geometry.visibility_range_begin_margin = 0.0
		geometry.visibility_range_end_margin = 0.0
		geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func update_lod_for_distance(distance_metres: float) -> void:
	if not is_finite(distance_metres):
		return
	var safe_hysteresis := clampf(lod_hysteresis, 0.0, maxf(0.0, lod_switch_distance - 0.5))
	if _active_lod == 0 and distance_metres > lod_switch_distance + safe_hysteresis:
		_apply_lod(1)
	elif _active_lod == 1 and distance_metres < lod_switch_distance - safe_hysteresis:
		_apply_lod(0)


func _apply_lod(lod_index: int) -> void:
	var previous := _active_lod
	_active_lod = clampi(lod_index, 0, 1)
	if _source_lod0 != null:
		_source_lod0.visible = _active_lod == 0
	if _modern_lod0 != null:
		_modern_lod0.visible = _active_lod == 0
	if _canopy_pivot != null:
		_canopy_pivot.visible = _active_lod == 0
	if _source_lod1 != null:
		_source_lod1.visible = _active_lod == 1
	if _modern_lod1 != null:
		_modern_lod1.visible = _active_lod == 1
	if previous != _active_lod:
		lod_changed.emit(_active_lod)


func get_active_lod() -> int:
	return _active_lod


func get_asset_root() -> Node3D:
	return _asset_root if _asset_root != null and is_instance_valid(_asset_root) else null


func get_source_core_root() -> Node3D:
	return _source_core if _source_core != null and is_instance_valid(_source_core) else null


func get_modern_systems_root() -> Node3D:
	return _modern_systems if _modern_systems != null and is_instance_valid(_modern_systems) else null


func get_lod0_roots() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for root_node in [_source_lod0, _modern_lod0]:
		if root_node != null and is_instance_valid(root_node):
			result.append(root_node)
	return result


func get_lod1_roots() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for root_node in [_source_lod1, _modern_lod1]:
		if root_node != null and is_instance_valid(root_node):
			result.append(root_node)
	return result


func get_canopy_pivot() -> Node3D:
	return _canopy_pivot if _canopy_pivot != null and is_instance_valid(_canopy_pivot) else null


func set_canopy_fraction(open_fraction: float) -> void:
	if _canopy_pivot == null or not is_instance_valid(_canopy_pivot):
		return
	_canopy_fraction = clampf(open_fraction, 0.0, 1.0)
	var rotation_value := _canopy_pivot.rotation
	rotation_value.x = _canopy_base_transform.basis.get_euler().x + CANOPY_OPEN_ANGLE_RADIANS * _canopy_fraction
	_canopy_pivot.rotation = rotation_value


func get_semantic_anchor(anchor_name: StringName) -> Node3D:
	if _semantic_anchors == null or not is_instance_valid(_semantic_anchors):
		return null
	return _semantic_anchors.get_node_or_null(NodePath(String(anchor_name))) as Node3D


func get_engine_plumes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if _asset_root == null:
		return result
	for plume_name in PROTECTED_PLUMES:
		var plume := _asset_root.find_child(plume_name, true, false) as MeshInstance3D
		if plume != null:
			result.append(plume)
	return result


func get_runtime_material(material_role: StringName) -> StandardMaterial3D:
	return _runtime_materials.get(material_role) as StandardMaterial3D


func get_asset_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var live_root := get_asset_root()
	if (
		_imported_container == null
		or not is_instance_valid(_imported_container)
		or get_node_or_null(^"ZenithAuthoredImport") != _imported_container
		or _imported_container.get_parent() != self
		or _imported_container.top_level
		or not _imported_container.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		errors.append("imported_container_identity_or_transform_drift")
	if top_level or not transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("presentation_adapter_transform_authority_drift")
	if live_root == null or not is_ancestor_of(live_root):
		errors.append("missing_blender_authored_asset_root")
	else:
		if not live_root.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("asset_root_transform_drift")
		if _direct_child_names(live_root) != PackedStringArray(["ModernSystems", "SourceCore"]):
			errors.append("asset_root_exact_child_roster_drift")
	if _source_core == null or _source_core.get_parent() != live_root:
		errors.append("source_core_identity_or_parent_drift")
	elif _direct_child_names(_source_core) != PackedStringArray(["LOD0", "LOD1"]):
		errors.append("source_core_exact_child_roster_drift")
	if _modern_systems == null or _modern_systems.get_parent() != live_root:
		errors.append("modern_systems_identity_or_parent_drift")
	elif _direct_child_names(_modern_systems) != PackedStringArray(["CanopyPivot", "LOD0", "LOD1", "SemanticAnchors"]):
		errors.append("modern_systems_exact_child_roster_drift")
	var expected_anchor_names := PackedStringArray()
	for anchor_name: StringName in REQUIRED_ANCHORS:
		expected_anchor_names.append(String(anchor_name))
	expected_anchor_names.sort()
	if _semantic_anchors == null or _direct_child_names(_semantic_anchors) != expected_anchor_names:
		errors.append("semantic_anchor_exact_roster_drift")
	for anchor_name: StringName in REQUIRED_ANCHORS:
		var anchor := get_semantic_anchor(anchor_name)
		if anchor == null:
			errors.append("missing_semantic_anchor:%s" % anchor_name)
		elif anchor.position.distance_to(REQUIRED_ANCHORS[anchor_name]) > 0.002:
			errors.append("semantic_anchor_transform_drift:%s" % anchor_name)

	var forbidden_authority_node_count := 0
	for type_name in [
		"PhysicsBody3D", "CollisionShape3D", "Area3D", "Camera3D",
		"AnimationPlayer", "AudioStreamPlayer3D", "NavigationRegion3D",
	]:
		forbidden_authority_node_count += find_children("*", type_name, true, false).size()
	if forbidden_authority_node_count != 0:
		errors.append("visual_subtree_contains_gameplay_authority_nodes")

	var close_triangle_count := (
		_subtree_triangle_count(_source_lod0)
		+ _subtree_triangle_count(_modern_lod0)
		+ _subtree_triangle_count(_canopy_pivot)
	)
	var far_triangle_count := _subtree_triangle_count(_source_lod1) + _subtree_triangle_count(_modern_lod1)
	var runtime_mesh_count := live_root.find_children("*", "MeshInstance3D", true, false).size() if live_root != null else 0
	var runtime_surface_count := _subtree_surface_count(live_root)
	var collision_proposal := _manifest.get("collision_proposal", {}) as Dictionary
	var structural_collision := collision_proposal.get("structural_art_coverage", {}) as Dictionary
	var reverse_collision := collision_proposal.get("reverse_fit", {}) as Dictionary
	var pod_contract := _manifest.get("pod_like_form_contract", {}) as Dictionary
	var removed_pattern_contract := _manifest.get("removed_surface_pattern_contract", {}) as Dictionary
	var canopy_contract := _manifest.get("canopy_contract", {}) as Dictionary
	if close_triangle_count < CLOSE_TRIANGLE_RANGE.x or close_triangle_count > CLOSE_TRIANGLE_RANGE.y:
		errors.append("close_triangle_density_outside_contract")
	if far_triangle_count < FAR_TRIANGLE_RANGE.x or far_triangle_count > FAR_TRIANGLE_RANGE.y:
		errors.append("far_triangle_density_outside_contract")
	if runtime_mesh_count > RUNTIME_MESH_BUDGET or runtime_surface_count > RUNTIME_SURFACE_BUDGET:
		errors.append("runtime_mesh_or_surface_budget_exceeded")
	if _manifest.is_empty() or str(_manifest.get("asset_id", "")) != String(ASSET_ID):
		errors.append("missing_or_wrong_asset_manifest")
	else:
		var quality := _manifest.get("art_quality_contract", {}) as Dictionary
		var runtime := _manifest.get("runtime_metrics", {}) as Dictionary
		if int(quality.get("close_triangle_count", -1)) != close_triangle_count:
			errors.append("manifest_close_triangle_count_drift")
		if int(quality.get("far_triangle_count", -1)) != far_triangle_count:
			errors.append("manifest_far_triangle_count_drift")
		if int(runtime.get("mesh_instance_count", -1)) != runtime_mesh_count:
			errors.append("manifest_runtime_mesh_count_drift")
		if int(runtime.get("surface_count", -1)) != runtime_surface_count:
			errors.append("manifest_runtime_surface_count_drift")
	if (
		not bool(collision_proposal.get("ready", false))
		or bool(collision_proposal.get("authority", true))
		or bool(collision_proposal.get("collision_authority", true))
		or int(collision_proposal.get("shape_count", -1)) != 24
		or int(collision_proposal.get("maximum_shape_count", -1)) != 24
		or (collision_proposal.get("shapes", []) as Array).size() != 24
		or (collision_proposal.get("non_solid_exclusions", []) as Array).size() != 5
		or (collision_proposal.get("non_contact_decorative_trim", []) as Array).size() != 19
		or int(structural_collision.get("included_object_count", -1)) != 65
		or int(structural_collision.get("audited_vertex_count", -1)) != 19_378
		or int(structural_collision.get("vertices_over_20mm", -1)) != 0
		or float(structural_collision.get("maximum_observed_miss_m", INF)) > .020
		or float(reverse_collision.get("conservative_continuous_upper_bound_m", INF)) > .150
		or int(reverse_collision.get("sampled_cell_count", 0)) <= 0
		or str(reverse_collision.get("distance_semantics", "")) != "conservative_distance_to_included_art_solid_not_unsigned_surface_only"
	):
		errors.append("non_authoritative_collision_proposal_contract_drift")
	var boarding_capsule := collision_proposal.get("production_boarding_capsule", {}) as Dictionary
	var boarding_route := collision_proposal.get("boarding_route", {}) as Dictionary
	var marker_collision := boarding_capsule.get("collision_marker_witness", {}) as Dictionary
	var grounding_sweep := boarding_route.get("vertical_grounding_sweep", {}) as Dictionary
	var grounded_walk := boarding_route.get("grounded_walk_sweep", {}) as Dictionary
	var boarding_area := collision_proposal.get("boarding_area_witness", {}) as Dictionary
	var cannon_attachment := collision_proposal.get("cannon_attachment", {}) as Dictionary
	if (
		_array_to_vector3(boarding_capsule.get("root_position", [])) != REQUIRED_ANCHORS[&"BoardingPoint"]
		or _array_to_vector3(boarding_capsule.get("center_offset", [])) != Vector3(0.0, .97, 0.0)
		or _array_to_vector3(boarding_capsule.get("center_position", [])) != Vector3(-7.65, .42, .55)
		or not is_equal_approx(float(boarding_capsule.get("radius", 0.0)), .38)
		or not is_equal_approx(float(boarding_capsule.get("total_height", 0.0)), 1.94)
		or float(boarding_capsule.get("conservative_art_clearance_m", 0.0)) < .05
		or float(marker_collision.get("conservative_continuous_clearance_m", 0.0)) < .05
		or str(boarding_capsule.get("art_clearance_method", "")) != "1001_axis_samples_mesh_bvh_1_lipschitz_lower_bound"
	):
		errors.append("boarding_capsule_clearance_contract_drift")
	if (
		not bool(boarding_route.get("clear", false))
		or _array_to_vector3(boarding_route.get("initial_root_position", [])) != Vector3(-7.65, -.50, 4.75)
		or _array_to_vector3(boarding_route.get("grounded_root_position", [])) != Vector3(-7.65, -1.08, 4.75)
		or _array_to_vector3(boarding_route.get("grounded_end_root_position", [])) != Vector3(-7.65, -1.08, .55)
		or float(grounding_sweep.get("conservative_continuous_clearance_m", 0.0)) < .05
		or float(grounded_walk.get("conservative_continuous_clearance_m", 0.0)) < .05
	):
		errors.append("production_boarding_route_contract_drift")
	if (
		_array_to_vector3(boarding_area.get("center", [])) != Vector3(-7.65, -.05, .55)
		or not is_equal_approx(float(boarding_area.get("radius", 0.0)), 4.5)
		or float(boarding_area.get("art_surface_center_clearance_m", 0.0)) <= 0.0
		or float(boarding_area.get("collision_center_clearance_m", 0.0)) <= 0.0
	):
		errors.append("boarding_area_clearance_witness_drift")
	if cannon_attachment.size() != 4:
		errors.append("cannon_attachment_roster_drift")
	else:
		for cannon_name in [
			"PortCannonBarrel", "PortCannonShroud",
			"StarboardCannonBarrel", "StarboardCannonShroud",
		]:
			var contact := cannon_attachment.get(cannon_name, {}) as Dictionary
			if (
				not bool(contact.get("attached", false))
				or float(contact.get("minimum_distance_to_source_solid_m", INF)) > .020
			):
				errors.append("cannon_attachment_clearance_drift:%s" % cannon_name)
	if (
		not bool(pod_contract.get("historical_function_unresolved", false))
		or not bool(pod_contract.get("count_placement_function_unauthenticated", false))
		or not bool(pod_contract.get("aggregate_evidence_survives_runtime_batching", false))
		or (pod_contract.get("source_object_records", []) as Array).size() != 4
	):
		errors.append("pod_like_form_uncertainty_contract_drift")
	if (
		int(removed_pattern_contract.get("removed_lod0_source_surface_cell_count", -1)) != 28
		or int(removed_pattern_contract.get("removed_lod1_silhouette_cell_count", -1)) != 24
		or int(canopy_contract.get("glass_source_triangle_count", 99999)) >= 3500
		or not bool(canopy_contract.get("readable_coaming", false))
	):
		errors.append("acceptance_art_revision_contract_drift")

	var raw_glb_sha256 := _raw_source_sha256(ASSET_PATH)
	var raw_blend_sha256 := _raw_source_sha256(SOURCE_PATH)
	if raw_glb_sha256.is_empty() or raw_glb_sha256 != str(_manifest.get("glb_sha256", "")):
		errors.append("raw_source_glb_hash_mismatch")
	if raw_blend_sha256.is_empty() or raw_blend_sha256 != str(_manifest.get("blend_sha256", "")):
		errors.append("raw_source_blend_hash_mismatch")
	_append_lod_errors(errors)
	_append_material_errors(errors)
	_append_geometry_array_errors(errors)
	_append_integrity_errors(errors)

	var bounds_minimum := _authored_bounds.get("minimum", Vector3.INF) as Vector3
	var bounds_maximum := _authored_bounds.get("maximum", Vector3.INF) as Vector3
	if bounds_minimum.distance_to(EXPECTED_MINIMUM) > 0.002 or bounds_maximum.distance_to(EXPECTED_MAXIMUM) > 0.002:
		errors.append("authored_visual_bounds_drift")
	var source_core_removable := _source_core != null and _source_core.get_parent() == live_root
	var modern_systems_removable := _modern_systems != null and _modern_systems.get_parent() == live_root
	if not source_core_removable or not modern_systems_removable:
		errors.append("source_modern_removability_boundary_drift")

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"asset_id": ASSET_ID,
		"asset_path": ASSET_PATH,
		"source_path": SOURCE_PATH,
		"authorship": &"original_script_assisted_blender",
		"historical_geometry_authenticated": false,
		"evidence_scope": EVIDENCE_SCOPE,
		"presentation_only": true,
		"gameplay_authority": false,
		"collision_authority": false,
		"collision_proposal_ready": bool(collision_proposal.get("ready", false)),
		"collision_proposal_shape_count": int(collision_proposal.get("shape_count", 0)),
		"collision_proposal_box_count": int(collision_proposal.get("shape_count", 0)),
		"collision_proposal_maximum_miss_m": float(structural_collision.get("maximum_observed_miss_m", INF)),
		"collision_proposal_reverse_bound_m": float(reverse_collision.get("conservative_continuous_upper_bound_m", INF)),
		"boarding_capsule_clearance_m": float(boarding_capsule.get("conservative_art_clearance_m", 0.0)),
		"boarding_collision_clearance_m": float(marker_collision.get("conservative_continuous_clearance_m", 0.0)),
		"boarding_route_clear": bool(boarding_route.get("clear", false)),
		"boarding_route_clearance_m": float(grounded_walk.get("conservative_continuous_clearance_m", 0.0)),
		"boarding_area_center": _array_to_vector3(boarding_area.get("center", [])),
		"pod_like_form_count": (pod_contract.get("source_object_records", []) as Array).size(),
		"pod_historical_function_unresolved": bool(pod_contract.get("historical_function_unresolved", false)),
		"pod_count_placement_function_unauthenticated": bool(pod_contract.get("count_placement_function_unauthenticated", false)),
		"forbidden_authority_node_count": forbidden_authority_node_count,
		"source_core_removable": source_core_removable,
		"modern_systems_removable": modern_systems_removable,
		"whole_ship_lod_atomic": true,
		"far_lod_unbounded": true,
		"active_lod": _active_lod,
		"close_triangle_count": close_triangle_count,
		"far_triangle_count": far_triangle_count,
		"runtime_mesh_count": runtime_mesh_count,
		"runtime_surface_count": runtime_surface_count,
		"runtime_mesh_budget": RUNTIME_MESH_BUDGET,
		"runtime_surface_budget": RUNTIME_SURFACE_BUDGET,
		"bounds_minimum": bounds_minimum,
		"bounds_maximum": bounds_maximum,
		"material_roles": MATERIAL_ROLES.duplicate(),
		"material_role_count": _runtime_materials.size(),
		"anchors": REQUIRED_ANCHORS.duplicate(true),
		"hull_texture_coordinate": &"UV0/TEXCOORD_0",
		"hull_triplanar": false,
		"hull_maps": {
			"albedo": HULL_ALBEDO_PATH,
			"normal": HULL_NORMAL_PATH,
			"roughness": HULL_ROUGHNESS_PATH,
		},
		"glb_sha256": raw_glb_sha256,
		"blend_sha256": raw_blend_sha256,
		"raw_source_glb_hash_checked": not raw_glb_sha256.is_empty(),
		"raw_source_glb_hash_verified": raw_glb_sha256 == str(_manifest.get("glb_sha256", "")),
	}.duplicate(true)


func _append_lod_errors(errors: PackedStringArray) -> void:
	if (
		not is_finite(lod_switch_distance)
		or not is_finite(lod_hysteresis)
		or not is_equal_approx(lod_switch_distance, _built_lod_switch_distance)
		or not is_equal_approx(lod_hysteresis, _built_lod_hysteresis)
		or lod_switch_distance < 15.0
		or lod_hysteresis < 0.0
		or lod_hysteresis >= lod_switch_distance
	):
		errors.append("whole_ship_lod_configuration_drift")
	for root_node in [_source_lod0, _source_lod1, _modern_lod0, _modern_lod1, _canopy_pivot]:
		if root_node == null:
			errors.append("missing_whole_ship_lod_root")
			continue
		for candidate in root_node.find_children("*", "GeometryInstance3D", true, false):
			var geometry := candidate as GeometryInstance3D
			if not is_zero_approx(geometry.visibility_range_begin) or not is_zero_approx(geometry.visibility_range_end):
				errors.append("per_mesh_visibility_lod_reintroduced:%s" % geometry.name)
				break
			var mesh_instance := geometry as MeshInstance3D
			var array_mesh := mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
			if array_mesh != null:
				for surface_value: Variant in array_mesh.get("_surfaces"):
					if surface_value is Dictionary and not (surface_value as Dictionary).get("lods", {}).is_empty():
						errors.append("per_surface_auto_lod_reintroduced:%s" % geometry.name)
						break


func _append_material_errors(errors: PackedStringArray) -> void:
	if _runtime_materials.size() != MATERIAL_ROLES.size():
		errors.append("runtime_material_role_count_drift")
	for role in MATERIAL_ROLES:
		if not _runtime_materials.has(StringName(role)):
			errors.append("missing_runtime_material:%s" % role)
	for root_node in [_source_lod0, _source_lod1]:
		if root_node == null:
			continue
		for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
			var role := StringName((candidate as MeshInstance3D).get_meta("zenith_material_role", &""))
			if role not in SOURCE_MATERIAL_ROLES:
				errors.append("modern_material_leaked_into_source_core:%s" % candidate.name)
	for root_node in [_modern_lod0, _modern_lod1, _canopy_pivot]:
		if root_node == null:
			continue
		for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
			var role := StringName((candidate as MeshInstance3D).get_meta("zenith_material_role", &""))
			if role not in MODERN_MATERIAL_ROLES:
				errors.append("source_material_leaked_into_modern_systems:%s" % candidate.name)
	for role in SOURCE_MATERIAL_ROLES:
		var hull := _runtime_materials.get(role) as StandardMaterial3D
		if (
			hull == null
			or hull.albedo_texture != load(HULL_ALBEDO_PATH)
			or hull.normal_texture != load(HULL_NORMAL_PATH)
			or hull.roughness_texture != load(HULL_ROUGHNESS_PATH)
			or hull.uv1_triplanar
		):
			errors.append("registered_uv0_hull_material_drift:%s" % role)


func _append_geometry_array_errors(errors: PackedStringArray) -> void:
	if _asset_root == null:
		return
	for candidate in _asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			errors.append("missing_runtime_mesh:%s" % mesh_instance.name)
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			if vertices.is_empty() or normals.size() != vertices.size() or uvs.size() != vertices.size():
				errors.append("missing_uv0_or_normals:%s" % mesh_instance.name)
				continue
			for normal in normals:
				if not normal.is_finite() or absf(normal.length() - 1.0) > 0.001:
					errors.append("non_unit_runtime_normal:%s" % mesh_instance.name)
					break
			var unique_uvs := {}
			for uv in uvs:
				if not uv.is_finite():
					errors.append("non_finite_uv0:%s" % mesh_instance.name)
					break
				unique_uvs[Vector2(snappedf(uv.x, .000001), snappedf(uv.y, .000001))] = true
			if unique_uvs.size() < 3:
				errors.append("collapsed_uv0:%s" % mesh_instance.name)


func _capture_integrity_contract() -> void:
	if _asset_root == null:
		return
	for node in _asset_root.find_children("*", "Node3D", true, false):
		var node3d := node as Node3D
		_integrity_nodes[node3d.get_instance_id()] = {
			"node": node3d,
			"parent": node3d.get_parent(),
			"name": String(node3d.name),
			"transform": node3d.transform,
		}
	for candidate in _asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		_integrity_meshes[mesh_instance.get_instance_id()] = mesh_instance.mesh
		_integrity_materials[mesh_instance.get_instance_id()] = mesh_instance.material_override
		if String(mesh_instance.name) in PROTECTED_PLUMES:
			_plume_base_poses[mesh_instance.get_instance_id()] = {
				"position": mesh_instance.position,
				"rotation": mesh_instance.basis.get_rotation_quaternion(),
			}


func _append_integrity_errors(errors: PackedStringArray) -> void:
	for record_value: Variant in _integrity_nodes.values():
		var record := record_value as Dictionary
		var node := record.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			errors.append("authored_node_removed")
			continue
		if node.get_parent() != record.get("parent") or String(node.name) != str(record.get("name", "")):
			errors.append("authored_node_identity_or_parent_drift:%s" % record.get("name", ""))
			continue
		if node == _canopy_pivot:
			var expected := _canopy_base_transform
			var expected_rotation := expected.basis.get_euler()
			expected_rotation.x += CANOPY_OPEN_ANGLE_RADIANS * _canopy_fraction
			var expected_transform := Transform3D(Basis.from_euler(expected_rotation), expected.origin)
			if not node.transform.is_equal_approx(expected_transform):
				errors.append("canopy_pivot_unsupported_transform_drift")
		elif node is MeshInstance3D and String(node.name) in PROTECTED_PLUMES:
			var pose := _plume_base_poses.get(node.get_instance_id(), {}) as Dictionary
			var scale_value := node.scale
			if (
				node.position.distance_to(pose.get("position", Vector3.INF)) > .0001
				or node.basis.get_rotation_quaternion().angle_to(
					pose.get("rotation", Quaternion.IDENTITY)
				) > .0001
				or not scale_value.is_finite()
				or scale_value.x < 0.0 or scale_value.y < 0.0 or scale_value.z < 0.0
			):
				errors.append("protected_plume_pose_contract_drift:%s" % node.name)
		elif node in [_source_lod0, _source_lod1, _modern_lod0, _modern_lod1]:
			if node.transform != record.get("transform"):
				errors.append("lod_root_transform_drift:%s" % node.name)
		elif not node.transform.is_equal_approx(record.get("transform", Transform3D.IDENTITY)):
			errors.append("authored_node_transform_drift:%s" % node.name)
	for instance_id: int in _integrity_meshes:
		var record := _integrity_nodes.get(instance_id, {}) as Dictionary
		var mesh_instance := record.get("node") as MeshInstance3D
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		if mesh_instance.mesh != _integrity_meshes[instance_id]:
			errors.append("authored_mesh_resource_substituted:%s" % mesh_instance.name)
		if mesh_instance.material_override != _integrity_materials[instance_id]:
			errors.append("runtime_material_substituted:%s" % mesh_instance.name)


func _direct_child_names(node: Node) -> PackedStringArray:
	var names := PackedStringArray()
	if node == null:
		return names
	for child in node.get_children():
		names.append(String(child.name))
	names.sort()
	return names


func _subtree_triangle_count(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface_index in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	return total


func _subtree_surface_count(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh != null:
			total += mesh.get_surface_count()
	return total


func _runtime_bounds(node: Node3D) -> Dictionary:
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	if node == null:
		return {"minimum": minimum, "maximum": maximum}
	var root_inverse := node.global_transform.affine_inverse()
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative := root_inverse * mesh_instance.global_transform
		var aabb := mesh_instance.get_aabb()
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var point := relative * Vector3(x, y, z)
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return {"minimum": minimum, "maximum": maximum}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _array_to_vector3(value: Variant) -> Vector3:
	if value is not Array or (value as Array).size() != 3:
		return Vector3.INF
	var array := value as Array
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


func _raw_source_sha256(resource_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	return FileAccess.get_sha256(absolute_path) if FileAccess.file_exists(absolute_path) else ""
