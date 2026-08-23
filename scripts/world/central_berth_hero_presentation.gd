class_name CentralBerthHeroPresentation
extends Node3D

## Visual-only adapter for the Blender-authored central-berth shell.  Gameplay,
## walking, collision, landing, docking, utilities and lighting remain owned by
## the existing world nodes layered above this presentation.

const SCHEMA_VERSION := 1
const ASSET_PATH := "res://assets/models/station/central_berth_hero_v1.glb"
const MANIFEST_PATH := "res://assets/models/station/central_berth_hero_v1_asset_manifest.json"
const ASSET_ID := &"mudds.station.central_berth_hero.v1"
const DECK_ALBEDO_PATH := "res://assets/materials/shipyard-deck-albedo-v1.png"
const DECK_NORMAL_PATH := "res://assets/materials/shipyard-deck-normal-v1.png"
const DECK_ROUGHNESS_PATH := "res://assets/materials/shipyard-deck-roughness-v1.png"
const STRUCTURAL_TRIPLANAR_SCALE := 0.3
const REQUIRED_ROOTS := [
	"deck_panels",
	"edge_fascia",
	"primary_structure",
	"secondary_structure",
	"service_channels",
]
const MATERIAL_ROLES := [
	"DeckComposite",
	"EdgeIvory",
	"GuidanceCyan",
	"ServiceGraphite",
	"StructuralAlloy",
]
const EXPECTED_MINIMUM := Vector3(-12.75, -2.58, -27.75)
const EXPECTED_MAXIMUM := Vector3(12.75, 0.095, 7.75)
const MAXIMUM_RUNTIME_MESHES := 12
const MAXIMUM_RUNTIME_SURFACES := 12

var _imported_container: Node3D
var _asset_root: Node3D
var _semantic_roots: Dictionary = {}
var _runtime_materials: Dictionary = {}
var _integrity_nodes: Dictionary = {}
var _integrity_meshes: Dictionary = {}
var _integrity_materials: Dictionary = {}
var _asset_root_parent_id := 0
var _manifest: Dictionary = {}
var _built := false


func _ready() -> void:
	_build_once()


func _build_once() -> void:
	if _built:
		return
	_built = true
	var packed := load(ASSET_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load the Blender-authored central berth asset")
		return
	_imported_container = packed.instantiate() as Node3D
	if _imported_container == null:
		push_error("Unable to instantiate the Blender-authored central berth asset")
		return
	_imported_container.name = "CentralBerthHeroImport"
	add_child(_imported_container)
	_asset_root = _imported_container.get_node_or_null("CentralBerthHeroArt") as Node3D
	if _asset_root == null:
		_asset_root = _imported_container.find_child("CentralBerthHeroArt", true, false) as Node3D
	if _asset_root == null and _imported_container.has_node("deck_panels"):
		_asset_root = _imported_container
	if _asset_root == null:
		push_error("Blender-authored central berth hierarchy root is missing")
		return
	for root_name in REQUIRED_ROOTS:
		_semantic_roots[StringName(root_name)] = _asset_root.get_node_or_null(NodePath(root_name)) as Node3D
	_manifest = _read_manifest()
	_configure_runtime_materials()
	_capture_integrity_contract()


func _configure_runtime_materials() -> void:
	var structural_alloy := _pbr_material(Color("213843"), 0.72, 0.29)
	StationSurfaceKit.apply_panel_triplanar(
		structural_alloy,
		STRUCTURAL_TRIPLANAR_SCALE,
		StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY,
	)
	_runtime_materials = {
		&"DeckComposite": _deck_material(),
		&"EdgeIvory": _pbr_material(Color("b4b8a9"), 0.18, 0.34),
		&"StructuralAlloy": structural_alloy,
		&"ServiceGraphite": _pbr_material(Color("081014"), 0.42, 0.48),
		&"GuidanceCyan": _emissive_material(Color("045c6b"), Color("04bacd"), 2.1),
	}
	if _asset_root == null:
		return
	for candidate in _asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var source := mesh_instance.get_active_material(0)
		var role := StringName(source.resource_name) if source != null else &""
		var replacement := _runtime_materials.get(role) as Material
		if replacement != null:
			mesh_instance.material_override = replacement
			mesh_instance.set_meta("central_berth_material_role", role)
			mesh_instance.set_meta("presentation_only", true)
			if role == &"GuidanceCyan":
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


func _deck_material() -> StandardMaterial3D:
	var material := _pbr_material(Color("26373d"), 0.52, 0.38)
	material.albedo_texture = load(DECK_ALBEDO_PATH) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(DECK_NORMAL_PATH) as Texture2D
	material.normal_scale = 0.42
	material.roughness_texture = load(DECK_ROUGHNESS_PATH) as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = false
	material.uv1_scale = Vector3.ONE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _pbr_material(color, 0.16, 0.25)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func get_asset_root() -> Node3D:
	return _asset_root if _asset_root != null and is_instance_valid(_asset_root) else null


func get_semantic_root(root_name: StringName) -> Node3D:
	var root := _semantic_roots.get(root_name) as Node3D
	return root if root != null and is_instance_valid(root) else null


func get_runtime_material(material_role: StringName) -> StandardMaterial3D:
	return _runtime_materials.get(material_role) as StandardMaterial3D


func get_asset_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var live_root := get_asset_root()
	if get_child_count() != 1 or get_child(0) != _imported_container:
		errors.append("presentation_adapter_child_roster_drift")
	if (
		_imported_container == null
		or not is_instance_valid(_imported_container)
		or get_node_or_null(^"CentralBerthHeroImport") != _imported_container
		or _imported_container.get_parent() != self
		or _imported_container.top_level
		or not _imported_container.visible
		or not _imported_container.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		errors.append("imported_container_identity_or_transform_drift")
	if (
		is_instance_valid(_imported_container)
		and live_root != _imported_container
		and (
			_imported_container.get_child_count() != 1
			or _imported_container.get_child(0) != live_root
		)
	):
		errors.append("imported_container_child_roster_drift")
	if top_level or not transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("presentation_adapter_transform_authority_drift")
	if live_root == null or not is_ancestor_of(live_root):
		errors.append("missing_blender_authored_asset_root")
	elif (
		not live_root.transform.is_equal_approx(Transform3D.IDENTITY)
		or live_root.get_parent() == null
		or live_root.get_parent().get_instance_id() != _asset_root_parent_id
	):
		errors.append("asset_root_identity_or_transform_drift")

	for root_name in REQUIRED_ROOTS:
		var cached := get_semantic_root(StringName(root_name))
		var live := live_root.get_node_or_null(NodePath(root_name)) if live_root != null else null
		if cached == null or live == null:
			errors.append("missing_semantic_root:%s" % root_name)
		elif cached != live or cached.get_parent() != live_root:
			errors.append("semantic_root_identity_or_parent_drift:%s" % root_name)

	var forbidden_authority_node_count := 0
	for type_name in [
		"PhysicsBody3D", "CollisionShape3D", "Area3D", "Camera3D",
		"AudioStreamPlayer3D", "NavigationRegion3D", "VehicleBody3D",
	]:
		forbidden_authority_node_count += find_children("*", type_name, true, false).size()
	if forbidden_authority_node_count != 0:
		errors.append("visual_subtree_contains_gameplay_authority_nodes")

	var mesh_count := live_root.find_children("*", "MeshInstance3D", true, false).size() if live_root != null else 0
	var whole_wrapper_mesh_count := find_children("*", "MeshInstance3D", true, false).size()
	if whole_wrapper_mesh_count != mesh_count:
		errors.append("visual_mesh_exists_outside_authored_asset_root")
	var surface_count := _subtree_surface_count(live_root)
	var triangle_count := _subtree_triangle_count(live_root)
	if mesh_count > MAXIMUM_RUNTIME_MESHES:
		errors.append("runtime_mesh_draw_budget_exceeded")
	if surface_count > MAXIMUM_RUNTIME_SURFACES:
		errors.append("runtime_surface_draw_budget_exceeded")
	var bounds := _runtime_bounds(live_root)
	if (
		(bounds.get("minimum", Vector3.INF) as Vector3).distance_to(EXPECTED_MINIMUM) > 0.002
		or (bounds.get("maximum", Vector3.INF) as Vector3).distance_to(EXPECTED_MAXIMUM) > 0.002
	):
		errors.append("platform_envelope_or_deck_top_drift")

	_append_manifest_errors(errors, mesh_count, surface_count, triangle_count)
	_append_integrity_errors(errors)
	_append_deck_material_errors(errors)
	_append_material_role_errors(errors)

	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"asset_id": ASSET_ID,
		"asset_path": ASSET_PATH,
		"source_path": "res://art_source/station/central_berth_hero_v1.blend",
		"authorship": &"original_script_assisted_blender",
		"historical_geometry_authenticated": false,
		"presentation_only": true,
		"gameplay_authority": false,
		"collision_authority": false,
		"walking_surface_authority": false,
		"forbidden_authority_node_count": forbidden_authority_node_count,
		"semantic_roots": REQUIRED_ROOTS.duplicate(),
		"semantic_root_count": REQUIRED_ROOTS.size(),
		"material_roles": MATERIAL_ROLES.duplicate(),
		"material_role_count": _runtime_materials.size(),
		"runtime_mesh_count": mesh_count,
		"whole_wrapper_mesh_count": whole_wrapper_mesh_count,
		"runtime_surface_count": surface_count,
		"runtime_triangle_count": triangle_count,
		"runtime_mesh_budget": MAXIMUM_RUNTIME_MESHES,
		"runtime_surface_budget": MAXIMUM_RUNTIME_SURFACES,
		"bounds_minimum": bounds.get("minimum", Vector3.INF),
		"bounds_maximum": bounds.get("maximum", Vector3.INF),
		"deck_top_y": EXPECTED_MAXIMUM.y,
		"manifest_glb_sha256": str(_manifest.get("glb_sha256", "")),
		"manifest_blend_sha256": str(_manifest.get("blend_sha256", "")),
		"deck_texture_coordinate": &"UV0/TEXCOORD_0",
		"deck_triplanar": false,
		"deck_maps": {
			"albedo": DECK_ALBEDO_PATH,
			"normal": DECK_NORMAL_PATH,
			"roughness": DECK_ROUGHNESS_PATH,
		},
	}.duplicate(true)


func _append_manifest_errors(errors: PackedStringArray, mesh_count: int, surface_count: int, triangle_count: int) -> void:
	if _manifest.is_empty():
		errors.append("missing_or_invalid_asset_manifest")
		return
	if str(_manifest.get("asset_id", "")) != String(ASSET_ID):
		errors.append("manifest_asset_id_drift")
	if str(_manifest.get("authorship", "")) != "original_script_assisted_blender":
		errors.append("manifest_authorship_drift")
	if (
		not bool(_manifest.get("presentation_only", false))
		or bool(_manifest.get("gameplay_authority", true))
		or bool(_manifest.get("collision_authority", true))
		or bool(_manifest.get("walking_surface_authority", true))
	):
		errors.append("manifest_authority_boundary_drift")
	if PackedStringArray(_manifest.get("semantic_roots", [])) != PackedStringArray(REQUIRED_ROOTS):
		errors.append("manifest_semantic_root_roster_drift")
	var roles := PackedStringArray((_manifest.get("material_roles", {}) as Dictionary).keys())
	roles.sort()
	if roles != PackedStringArray(MATERIAL_ROLES):
		errors.append("manifest_material_role_roster_drift")
	var batching := _manifest.get("runtime_static_batching", {}) as Dictionary
	if (
		str(batching.get("strategy", "")) != "per_semantic_root_per_material_static_join"
		or not bool(batching.get("source_preserved_in_blend", false))
		or int(batching.get("runtime_mesh_instance_budget", 0)) != MAXIMUM_RUNTIME_MESHES
		or int(batching.get("runtime_surface_budget", 0)) != MAXIMUM_RUNTIME_SURFACES
		or int(batching.get("runtime_mesh_instance_count", -1)) != mesh_count
	):
		errors.append("manifest_runtime_batching_contract_drift")
	if (
		int(_manifest.get("mesh_triangles_exported_runtime", -1)) != triangle_count
		or int((_manifest.get("uv0_contract", {}) as Dictionary).get("runtime_meshes_with_uv0", -1)) != mesh_count
		or str((_manifest.get("uv0_contract", {}) as Dictionary).get("texture_coordinate", "")) != "UV0/TEXCOORD_0"
		or bool((_manifest.get("uv0_contract", {}) as Dictionary).get("triplanar", true))
		or surface_count != mesh_count
	):
		errors.append("manifest_runtime_geometry_or_uv0_contract_drift")
	var deck_uv_metrics := (
		(_manifest.get("uv0_contract", {}) as Dictionary).get("deck_top_metric_uv0", {})
		as Dictionary
	)
	if (
		int(deck_uv_metrics.get("top_triangle_sample_count", 0)) != 190
		or int(deck_uv_metrics.get("degenerate_top_triangle_count", -1)) != 0
		or float(deck_uv_metrics.get("maximum_singular_value_anisotropy", 99.0)) > 1.25
		or float(deck_uv_metrics.get("p95_singular_value_anisotropy", 99.0)) > 1.25
		or float(deck_uv_metrics.get("density_maximum_relative_deviation", 99.0)) > 0.25
		or PackedInt32Array(deck_uv_metrics.get("source_jacobian_determinant_signs", [])) != PackedInt32Array([1])
		or not bool(deck_uv_metrics.get("runtime_outward_non_mirrored", false))
		or not is_equal_approx(float(deck_uv_metrics.get("metres_per_texture_tile", 0.0)), 7.0)
		or str(deck_uv_metrics.get("runtime_axes_after_gltf_v_flip", "")) != "+U=>Godot +X, +V=>Godot -Z"
	):
		errors.append("manifest_deck_top_metric_uv0_contract_drift")


func _append_integrity_errors(errors: PackedStringArray) -> void:
	var live_root := get_asset_root()
	if live_root == null:
		return
	var nodes: Array[Node] = [live_root]
	nodes.append_array(live_root.find_children("*", "Node", true, false))
	if nodes.size() != _integrity_nodes.size():
		errors.append("imported_node_roster_size_drift")
	for candidate in nodes:
		var relative_path := str(live_root.get_path_to(candidate))
		var expected_value: Variant = _integrity_nodes.get(relative_path)
		if not expected_value is Dictionary:
			errors.append("unexpected_imported_node:%s" % relative_path)
			continue
		var expected := expected_value as Dictionary
		if (
			candidate.get_instance_id() != int(expected.get("instance_id", 0))
			or candidate.get_class() != str(expected.get("class", ""))
			or candidate.get_parent() == null
			or candidate.get_parent().get_instance_id() != int(expected.get("parent_id", 0))
		):
			errors.append("imported_node_identity_or_parent_drift:%s" % relative_path)
		if candidate is Node3D and (
			(candidate as Node3D).top_level != bool(expected.get("top_level", false))
			or not (candidate as Node3D).transform.is_equal_approx(expected.get("transform", Transform3D.IDENTITY))
		):
			errors.append("imported_node_transform_authority_drift:%s" % relative_path)
		if candidate is MeshInstance3D:
			_append_mesh_integrity_errors(candidate as MeshInstance3D, relative_path, errors)
	for role in _runtime_materials:
		if _material_signature(_runtime_materials[role] as StandardMaterial3D) != _integrity_materials.get(role, {}):
			errors.append("runtime_material_content_drift:%s" % String(role))


func _append_mesh_integrity_errors(mesh_instance: MeshInstance3D, path: String, errors: PackedStringArray) -> void:
	var expected_value: Variant = _integrity_meshes.get(path)
	if not expected_value is Dictionary:
		errors.append("unexpected_imported_mesh:%s" % path)
		return
	var expected := expected_value as Dictionary
	var role := StringName(expected.get("material_role", &""))
	if (
		mesh_instance.mesh == null
		or mesh_instance.mesh.get_instance_id() != int(expected.get("mesh_id", 0))
		or mesh_instance.mesh.get_surface_count() != int(expected.get("surface_count", 0))
		or _mesh_triangle_count(mesh_instance.mesh) != int(expected.get("triangle_count", 0))
		or _mesh_content_hash(mesh_instance.mesh) != str(expected.get("content_hash", ""))
	):
		errors.append("imported_mesh_topology_drift:%s" % path)
	if role.is_empty() or mesh_instance.material_override != _runtime_materials.get(role):
		errors.append("imported_mesh_material_membership_drift:%s" % path)
	if (
		mesh_instance.visible != bool(expected.get("visible", true))
		or mesh_instance.layers != int(expected.get("layers", 1))
		or mesh_instance.cast_shadow != int(expected.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	):
		errors.append("imported_mesh_render_contract_drift:%s" % path)


func _append_deck_material_errors(errors: PackedStringArray) -> void:
	var deck := _runtime_materials.get(&"DeckComposite") as StandardMaterial3D
	if (
		deck == null
		or deck.albedo_texture == null
		or deck.albedo_texture.resource_path != DECK_ALBEDO_PATH
		or not deck.normal_enabled
		or deck.normal_texture == null
		or deck.normal_texture.resource_path != DECK_NORMAL_PATH
		or not is_equal_approx(deck.normal_scale, 0.42)
		or deck.roughness_texture == null
		or deck.roughness_texture.resource_path != DECK_ROUGHNESS_PATH
		or deck.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_RED
		or deck.uv1_triplanar
	):
		errors.append("deck_composite_uv0_pbr_map_binding_drift")
	var deck_root := get_semantic_root(&"deck_panels")
	if deck_root == null:
		return
	for candidate in deck_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if StringName(mesh_instance.get_meta("central_berth_material_role", &"")) != &"DeckComposite":
			continue
		if not _mesh_has_meaningful_uv0(mesh_instance.mesh):
			errors.append("deck_composite_runtime_mesh_lacks_authored_uv0")


func _append_material_role_errors(errors: PackedStringArray) -> void:
	var actual_roles := PackedStringArray()
	var live_root := get_asset_root()
	if live_root != null:
		for candidate in live_root.find_children("*", "MeshInstance3D", true, false):
			var role := StringName((candidate as MeshInstance3D).get_meta("central_berth_material_role", &""))
			if not role.is_empty() and role not in actual_roles:
				actual_roles.append(role)
	actual_roles.sort()
	if actual_roles != PackedStringArray(MATERIAL_ROLES):
		errors.append("live_material_role_roster_drift")
	var edge := _runtime_materials.get(&"EdgeIvory") as StandardMaterial3D
	var structure := _runtime_materials.get(&"StructuralAlloy") as StandardMaterial3D
	var service := _runtime_materials.get(&"ServiceGraphite") as StandardMaterial3D
	var guidance := _runtime_materials.get(&"GuidanceCyan") as StandardMaterial3D
	if (
		edge == null or not is_equal_approx(edge.metallic, 0.18) or not is_equal_approx(edge.roughness, 0.34)
		or structure == null or not is_equal_approx(structure.metallic, 0.72) or not is_equal_approx(structure.roughness, 0.29)
		or service == null or not is_equal_approx(service.metallic, 0.42) or not is_equal_approx(service.roughness, 0.48)
		or guidance == null or not guidance.emission_enabled or not is_equal_approx(guidance.emission_energy_multiplier, 2.1)
	):
		errors.append("physically_distinct_material_role_contract_drift")
	if (
		structure == null
		or structure.albedo_texture == null
		or structure.albedo_texture.resource_path != StationSurfaceKit.PANEL_ALBEDO_PATH
		or not structure.normal_enabled
		or structure.normal_texture == null
		or structure.normal_texture.resource_path != StationSurfaceKit.PANEL_NORMAL_PATH
		or structure.roughness_texture == null
		or structure.roughness_texture.resource_path != StationSurfaceKit.PANEL_ROUGHNESS_PATH
		or not structure.uv1_triplanar
		or not structure.uv1_world_triplanar
		or not structure.uv1_scale.is_equal_approx(Vector3.ONE * STRUCTURAL_TRIPLANAR_SCALE)
		or not structure.clearcoat_enabled
		or not is_equal_approx(structure.clearcoat, StationSurfaceKit.STRUCTURAL_CLEARCOAT)
		or not is_equal_approx(
			structure.clearcoat_roughness,
			StationSurfaceKit.STRUCTURAL_CLEARCOAT_ROUGHNESS,
		)
	):
		errors.append("structural_alloy_world_metric_finish_drift")


func _capture_integrity_contract() -> void:
	_integrity_nodes.clear()
	_integrity_meshes.clear()
	_integrity_materials.clear()
	_asset_root_parent_id = (
		_asset_root.get_parent().get_instance_id()
		if _asset_root != null and _asset_root.get_parent() != null else 0
	)
	if _asset_root == null:
		return
	var nodes: Array[Node] = [_asset_root]
	nodes.append_array(_asset_root.find_children("*", "Node", true, false))
	for candidate in nodes:
		var relative_path := str(_asset_root.get_path_to(candidate))
		_integrity_nodes[relative_path] = {
			"instance_id": candidate.get_instance_id(),
			"class": candidate.get_class(),
			"parent_id": candidate.get_parent().get_instance_id() if candidate.get_parent() != null else 0,
			"transform": (candidate as Node3D).transform if candidate is Node3D else Transform3D.IDENTITY,
			"top_level": (candidate as Node3D).top_level if candidate is Node3D else false,
		}
		if candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			var role := StringName(mesh_instance.get_meta("central_berth_material_role", &""))
			_integrity_meshes[relative_path] = {
				"mesh_id": mesh_instance.mesh.get_instance_id() if mesh_instance.mesh != null else 0,
				"surface_count": mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0,
				"triangle_count": _mesh_triangle_count(mesh_instance.mesh),
				"content_hash": _mesh_content_hash(mesh_instance.mesh),
				"material_role": role,
				"visible": mesh_instance.visible,
				"layers": mesh_instance.layers,
				"cast_shadow": mesh_instance.cast_shadow,
			}
	for role in _runtime_materials:
		_integrity_materials[role] = _material_signature(_runtime_materials[role] as StandardMaterial3D)


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _runtime_bounds(root_node: Node3D) -> Dictionary:
	if root_node == null:
		return {"minimum": Vector3.INF, "maximum": Vector3.INF}
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_aabb := mesh_instance.mesh.get_aabb()
		var to_root := root_node.global_transform.affine_inverse() * mesh_instance.global_transform
		for x in [local_aabb.position.x, local_aabb.end.x]:
			for y in [local_aabb.position.y, local_aabb.end.y]:
				for z in [local_aabb.position.z, local_aabb.end.z]:
					var point := to_root * Vector3(x, y, z)
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return {"minimum": minimum, "maximum": maximum}


func _subtree_surface_count(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		count += mesh.get_surface_count() if mesh != null else 0
	return count


func _subtree_triangle_count(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		count += _mesh_triangle_count((candidate as MeshInstance3D).mesh)
	return count


func _mesh_triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var count := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if not indices.is_empty():
			count += indices.size() / 3
		else:
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			count += vertices.size() / 3
	return count


func _mesh_has_meaningful_uv0(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		if uvs.is_empty():
			return false
		var minimum := Vector2.INF
		var maximum := -Vector2.INF
		for uv in uvs:
			minimum = minimum.min(uv)
			maximum = maximum.max(uv)
		if minimum.distance_to(maximum) <= 0.1:
			return false
	return true


func _mesh_content_hash(mesh: Mesh) -> String:
	if mesh == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for surface_index in mesh.get_surface_count():
		context.update(var_to_bytes(mesh.surface_get_primitive_type(surface_index)))
		context.update(var_to_bytes(mesh.surface_get_arrays(surface_index)))
	return context.finish().hex_encode()


func _material_signature(material: StandardMaterial3D) -> Dictionary:
	if material == null:
		return {}
	return {
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"albedo_texture_path": material.albedo_texture.resource_path if material.albedo_texture != null else "",
		"normal_enabled": material.normal_enabled,
		"normal_texture_path": material.normal_texture.resource_path if material.normal_texture != null else "",
		"normal_scale": material.normal_scale,
		"roughness_texture_path": material.roughness_texture.resource_path if material.roughness_texture != null else "",
		"roughness_channel": material.roughness_texture_channel,
		"uv1_triplanar": material.uv1_triplanar,
	}
