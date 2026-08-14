class_name TorrentAuthoredMacroform
extends Node3D

## Immutable presentation seam for the checked-in, imported Torrent macroform.
## Gameplay collision, cockpit interaction and modern systems intentionally live
## outside this scene. No meshes or primitives are constructed at runtime.

const SCHEMA_VERSION := 2
const ASSET_ID := "torrent_b5_observed_authored_macroform"
const ASSET_REVISION := "v2"
const COMPONENT_ID := "torrent_authored_macroform_presentation_v2"
const PRESENTATION_PATH := "res://scenes/ships/presentation/torrent_authored_macroform.tscn"
const MATERIAL_ROLE_ORDER := ["stepped_side_trim_atlas", "warm_ivory", "restrained_graphite"]
const MATERIAL_ROLE_MEMBERS := [
	[
		"PortLowerSidePlane", "PortUpperSidePlane",
		"StarboardLowerSidePlane", "StarboardUpperSidePlane",
	],
	[
		"PointedNose", "CentralPressureKeel", "RaisedSpine", "BlockyAftBody",
		"PortAftRail", "StarboardAftRail", "AftCrossbar",
	],
	["PortAftCircularHousing", "StarboardAftCircularHousing"],
]
const EXPECTED_MATERIAL_PATHS := [
	PRESENTATION_PATH + "::StandardMaterial3D_torrent_atlas",
	PRESENTATION_PATH + "::StandardMaterial3D_torrent_ivory",
	PRESENTATION_PATH + "::StandardMaterial3D_torrent_graphite",
]
const FORBIDDEN_FLAT_STUDY_TEXTURE := "res://assets/models/torrent/textures/torrent-hero-flat-albedo-study-v1.png"
const MANIFEST_PATH := "res://assets/models/torrent/torrent_authored_asset_manifest.json"
const EXPECTED_MANIFEST_SHA256 := "a44136e7d9374206269391a64536a890576ddac29ca1949ef3e57db6c9a8c459"
const LOD_SWITCH_DISTANCE_M := 60.0
const LOD_SWITCH_MARGIN_M := 5.0
const EXPECTED_BOUNDS := AABB(Vector3(-3.60, -0.39, -4.80), Vector3(7.20, 4.54, 8.40))
const EXPECTED_LOD_TRIANGLES := [4636, 632]
const EXPECTED_GEOMETRY_ONLY_SHA256 := [
	"91a24751b27f9e30949241db18914f3ca9820324d0ecf29f5507fc89c9820050",
	"c1da2f93e70fb30d30e2db5da2c1ad75e00988d9339944af49672026548cb856",
]
# Godot's pinned 4.7.1 OBJ importer merges matching attribute tuples while
# preserving every authored triangle. These are the exact imported counts; the
# manifest separately records the deterministic source-OBJ vertex records.
const EXPECTED_LOD_VERTICES := [11419, 1351]
const EXPECTED_COMPONENTS := [
	"PointedNose",
	"CentralPressureKeel",
	"RaisedSpine",
	"BlockyAftBody",
	"PortLowerSidePlane",
	"PortUpperSidePlane",
	"StarboardLowerSidePlane",
	"StarboardUpperSidePlane",
	"PortAftCircularHousing",
	"StarboardAftCircularHousing",
	"PortAftRail",
	"StarboardAftRail",
	"AftCrossbar",
]
const SIGNED_AXIS_ORDER := ["+X", "-X", "+Y", "-Y", "+Z", "-Z"]
const UV_ROLE_ORDER := [
	"forward_pressure_hull", "aft_pressure_hull", "lower_side_planes",
	"upper_side_planes", "aft_circular_housings", "aft_frame",
]
const UV_ROLE_MEMBERS := [
	["PointedNose", "CentralPressureKeel"],
	["RaisedSpine", "BlockyAftBody"],
	["PortLowerSidePlane", "StarboardLowerSidePlane"],
	["PortUpperSidePlane", "StarboardUpperSidePlane"],
	["PortAftCircularHousing", "StarboardAftCircularHousing"],
	["PortAftRail", "StarboardAftRail", "AftCrossbar"],
]
const UV_LAYOUT_ID := "declared_role_weighted_columns_signed_axis_rows_v2"
const UV_ATLAS_OUTER_GUARD := 0.02
const UV_ATLAS_CELL_GUTTER := 0.004
const UV_ATLAS_COLUMNS := 6
const UV_ATLAS_ROWS := 6
const UV_ATLAS_COLUMN_WEIGHTS := [0.06, 0.06, 0.38, 0.38, 0.06, 0.06]
const ATLAS_SAMPLING_ROLES := ["lower_side_planes", "upper_side_planes"]
const ATLAS_SAMPLING_SEMANTICS := [
	"PortLowerSidePlane", "StarboardLowerSidePlane",
	"PortUpperSidePlane", "StarboardUpperSidePlane",
]
const UV_DOMINANT_AXIS_TIE_EPSILON := 0.0005
const UV_AUDIT_TOLERANCE := 0.00004
const RUNTIME_TEXTURES := {
	"albedo": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png",
	"normal": "res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png",
	"roughness": "res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png",
	"orm": "res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png",
	"emissive": "res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png",
}
const RUNTIME_TEXTURE_SHA256 := {
	"albedo": "17ccc04b8e641b4890cbacb7842b2fb24e2bbbbd00a7628fc5d9fa86c1b74b12",
	"normal": "c86817d88739b85835efd8626a2ce2c540620fa8a0af985e4bc5384d1599e357",
	"roughness": "57255d680fc060dd74a040f3bea27d55e9e93dba35f42985ada956f92bacfa42",
	"orm": "8f754d93a36b12eb6a031c8c9675da6e54591844c5582fee1063d6d3b523b2cd",
	"emissive": "398be72d094af6a429d9f06ec7eeeb855850b9873648d2d2f70e6b85e47cbd69",
}


## Returns a detached audit snapshot. Callers may mutate it without changing the
## asset's evidence boundary or future reports.
func get_torrent_authored_asset_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var manifest := _load_manifest(errors)
	_audit_exact_hierarchy(errors)
	_audit_identity_metadata(errors)
	_audit_no_forbidden_authority(errors)
	var materials := _expected_materials()
	_audit_materials(materials, errors)
	var lod_reports: Array[Dictionary] = []
	for lod in 2:
		lod_reports.append(_audit_lod(lod, manifest, materials, errors))
	if lod_reports.size() == 2:
		var lod0_triangles := int(lod_reports[0].get("triangle_count", 0))
		var lod1_triangles := int(lod_reports[1].get("triangle_count", 0))
		if lod0_triangles < 3000 or lod0_triangles > 6000:
			errors.append("LOD0 authored refinement is outside the 3000-6000 triangle target")
		if lod1_triangles <= 0 or lod1_triangles > floori(float(lod0_triangles) * 0.25):
			errors.append("LOD1 is not materially lower than the authored LOD0")
	var manifest_sha256 := _sha256(MANIFEST_PATH)
	var fingerprint := _fingerprint(manifest_sha256, lod_reports, materials)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"asset_id": ASSET_ID,
		"asset_revision": ASSET_REVISION,
		"component_id": COMPONENT_ID,
		"scene_path": scene_file_path,
		"manifest_path": MANIFEST_PATH,
		"manifest_sha256": manifest_sha256,
		"determinism_fingerprint": fingerprint,
		"node_contract": _node_contract(),
		"resource_contract": {
			"visual_instance_count": 26,
			"mesh_instance_count": 26,
			"collision_node_count": 0,
			"runtime_mesh_construction": false,
			"shared_material": false,
			"material_role_count": MATERIAL_ROLE_ORDER.size(),
			"material_role_order": MATERIAL_ROLE_ORDER.duplicate(),
			"material_role_members": MATERIAL_ROLE_MEMBERS.duplicate(true),
		},
		"lod_strategy": {
			"count": 2,
			"manual_switch_distance_m": LOD_SWITCH_DISTANCE_M,
			"switch_margin_m": LOD_SWITCH_MARGIN_M,
			"automatic_import_lods": false,
			"lod1_method": "analytic_rebuild",
		},
		"geometry_refinement": (manifest.get("geometry_refinement", {}) as Dictionary).duplicate(true),
		"lods": lod_reports,
		"provenance": (manifest.get("provenance", {}) as Dictionary).duplicate(true),
		"material_contract": {
			"material_class": "StandardMaterial3D",
			"inspection_node": NodePath("Dated2011Form/MacroformLOD0/PortLowerSidePlane"),
			"inspection_nodes": {
				"stepped_side_trim_atlas": NodePath("Dated2011Form/MacroformLOD0/PortLowerSidePlane"),
				"warm_ivory": NodePath("Dated2011Form/MacroformLOD0/PointedNose"),
				"restrained_graphite": NodePath("Dated2011Form/MacroformLOD0/PortAftCircularHousing"),
			},
			"material_role_order": MATERIAL_ROLE_ORDER.duplicate(),
			"material_role_members": MATERIAL_ROLE_MEMBERS.duplicate(true),
			"material_paths": EXPECTED_MATERIAL_PATHS.duplicate(),
			"roles": _material_roles_contract(),
			"textures": RUNTIME_TEXTURES.duplicate(true),
			"texture_sha256": RUNTIME_TEXTURE_SHA256.duplicate(true),
			"albedo": RUNTIME_TEXTURES.albedo,
			"normal": RUNTIME_TEXTURES.normal,
			"roughness": RUNTIME_TEXTURES.roughness,
			"orm": RUNTIME_TEXTURES.orm,
			"emissive": RUNTIME_TEXTURES.emissive,
			"origin": "modern_project_original",
			"mapping": "intentional_non_seamless_weighted_role_signed_axis_trim_v2",
			"uv_set": 0,
			"uv1_triplanar": false,
			"texture_repeat": false,
			"non_triplanar": true,
			"non_seamless": true,
			"source_kind": "image_derived_proxy_trim_atlas",
			"final_hand_authored_pbr": false,
			"production_usage": "selected_stepped_side_planes_only",
			"atlas_sampling_roles": ATLAS_SAMPLING_ROLES.duplicate(),
			"atlas_sampling_semantics": ATLAS_SAMPLING_SEMANTICS.duplicate(),
			"flat_study_bound": false,
			"uv_layout": _uv_layout_contract(),
			"packed_orm_channels": {"ao": "red", "roughness": "green", "metallic": "blue"},
			"separate_roughness_map_used": true,
		},
		"authored_bounds_m": {
			"position": EXPECTED_BOUNDS.position,
			"size": EXPECTED_BOUNDS.size,
		},
		"content_note": (
			"B5 bounds only the broad observed macroform. The recording/build dates are unknown. The v2 chamfers and shallow "
			+ "structural relief are modern authored refinement; exact topology, dimensions, "
			+ "UVs, normals, finish, symmetry, and 2009 continuity are not authenticated."
		),
	}.duplicate(true)


func _node_contract() -> Dictionary:
	var contract := {
		"root": NodePath("."),
		"dated_form": NodePath("Dated2011Form"),
		"lod_0": NodePath("Dated2011Form/MacroformLOD0"),
		"lod_1": NodePath("Dated2011Form/MacroformLOD1"),
	}
	for component: String in EXPECTED_COMPONENTS:
		contract[component.to_snake_case()] = NodePath("Dated2011Form/MacroformLOD0/%s" % component)
	return contract


func _load_manifest(errors: PackedStringArray) -> Dictionary:
	var manifest_sha256 := _sha256(MANIFEST_PATH)
	if manifest_sha256 != EXPECTED_MANIFEST_SHA256:
		errors.append("authored asset manifest bytes drifted from the pinned UV-layout trust root")
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		errors.append("authored asset manifest is unavailable")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("authored asset manifest is not valid JSON")
		return {}
	var manifest := parsed as Dictionary
	if int(manifest.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("authored asset manifest schema drifted")
	if str(manifest.get("asset_id", "")) != ASSET_ID:
		errors.append("authored asset manifest identity drifted")
	if str(manifest.get("asset_revision", "")) != ASSET_REVISION:
		errors.append("authored asset manifest revision drifted")
	if manifest.get("required_objects", []) != EXPECTED_COMPONENTS:
		errors.append("authored asset manifest semantic roster drifted")
	var lods := manifest.get("lods", []) as Array
	if lods.size() != 2:
		errors.append("authored asset manifest must contain exactly two LOD records")
	var strategy := manifest.get("lod_strategy", {}) as Dictionary
	if (
		int(strategy.get("count", 0)) != 2
		or not is_equal_approx(float(strategy.get("manual_switch_distance_m", -1.0)), LOD_SWITCH_DISTANCE_M)
		or bool(strategy.get("automatic_import_lods", true))
		or str(strategy.get("lod1_method", "")) != "analytic_rebuild"
	):
		errors.append("authored asset manifest LOD strategy drifted")
	var refinement := manifest.get("geometry_refinement", {}) as Dictionary
	if (
		str(refinement.get("revision", "")) != "bounded_authored_relief_v2"
		or not bool(refinement.get("exact_aabb_locked", false))
		or bool(refinement.get("new_historical_claims", true))
	):
		errors.append("authored v2 refinement boundary drifted")
	_audit_manifest_provenance(manifest.get("provenance", {}) as Dictionary, errors)
	_audit_manifest_texture_contract(manifest.get("texture_contract", {}) as Dictionary, errors)
	return manifest


func _audit_exact_hierarchy(errors: PackedStringArray) -> void:
	if name != &"TorrentAuthoredMacroform" or scene_file_path != PRESENTATION_PATH:
		errors.append("presentation root identity or PackedScene path drifted")
	if transform != Transform3D.IDENTITY or not visible:
		errors.append("presentation root transform or visibility drifted")
	var dated_form := get_node_or_null("Dated2011Form") as Node3D
	if get_child_count() != 1 or dated_form == null or get_child(0) != dated_form:
		errors.append("presentation root must own only the exact Dated2011Form hierarchy")
	if dated_form == null:
		return
	if dated_form.transform != Transform3D.IDENTITY or not dated_form.visible:
		errors.append("Dated2011Form transform or visibility drifted")
	if dated_form.get_child_count() != 2:
		errors.append("Dated2011Form must own exactly two authored LOD roots")
	var expected_visual_ids: Dictionary = {}
	for lod in 2:
		var lod_root := dated_form.get_node_or_null("MacroformLOD%d" % lod) as Node3D
		if lod_root == null:
			errors.append("MacroformLOD%d is missing" % lod)
			continue
		if lod_root.get_parent() != dated_form or lod_root.transform != Transform3D.IDENTITY or not lod_root.visible:
			errors.append("MacroformLOD%d hierarchy, transform or visibility drifted" % lod)
		if dated_form.get_child_count() > lod and dated_form.get_child(lod) != lod_root:
			errors.append("MacroformLOD%d sibling order drifted" % lod)
		if lod_root.get_child_count() != EXPECTED_COMPONENTS.size():
			errors.append("MacroformLOD%d does not own exactly 13 semantic meshes" % lod)
		for component_index in EXPECTED_COMPONENTS.size():
			var component := EXPECTED_COMPONENTS[component_index] as String
			var instance := lod_root.get_node_or_null(component) as MeshInstance3D
			if instance == null or instance.get_parent() != lod_root:
				errors.append("LOD%d semantic component %s is missing or detached" % [lod, component])
				continue
			if lod_root.get_child_count() > component_index and lod_root.get_child(component_index) != instance:
				errors.append("LOD%d semantic component order drifted at %s" % [lod, component])
			expected_visual_ids[instance.get_instance_id()] = true
	var visual_instances := find_children("*", "VisualInstance3D", true, false)
	if visual_instances.size() != 26:
		errors.append("presentation must contain exactly 26 authored VisualInstance3D nodes")
	for candidate: Node in visual_instances:
		if not candidate is MeshInstance3D or not expected_visual_ids.has(candidate.get_instance_id()):
			errors.append("presentation contains a rogue visual instance: %s" % candidate.name)


func _audit_lod(
	lod: int,
	manifest: Dictionary,
	materials: Array[StandardMaterial3D],
	errors: PackedStringArray
) -> Dictionary:
	var lod_root := get_node_or_null("Dated2011Form/MacroformLOD%d" % lod) as Node3D
	var components: Array[Dictionary] = []
	var vertex_count := 0
	var triangle_count := 0
	var surface_count := 0
	var combined_bounds := AABB()
	var has_bounds := false
	var manifest_record := _manifest_lod_record(manifest, lod)
	if manifest_record.is_empty():
		errors.append("manifest LOD%d record is missing" % lod)
	else:
		var manifest_objects := manifest_record.get("objects", []) as Array
		var manifest_object_names: Array[String] = []
		for object_value: Variant in manifest_objects:
			manifest_object_names.append(str((object_value as Dictionary).get("name", "")))
		if manifest_objects.size() != EXPECTED_COMPONENTS.size() or manifest_object_names != EXPECTED_COMPONENTS:
			errors.append("manifest LOD%d must publish exactly one ordered record per semantic object" % lod)
	if lod_root == null:
		return {"lod": lod, "components": components}
	var aggregate_path := str(manifest_record.get("path", ""))
	if aggregate_path != _aggregate_mesh_path(lod):
		errors.append("LOD%d aggregate source path drifted" % lod)
	if _sha256(aggregate_path) != str(manifest_record.get("sha256", "")):
		errors.append("LOD%d aggregate source hash drifted" % lod)
	if str(manifest_record.get("geometry_only_sha256", "")) != EXPECTED_GEOMETRY_ONLY_SHA256[lod]:
		errors.append("LOD%d geometry-only trust root drifted during the UV mapping revision" % lod)
	for component: String in EXPECTED_COMPONENTS:
		var instance := lod_root.get_node_or_null(component) as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var expected_path := _component_mesh_path(lod, component)
		var expected_resource := ResourceLoader.load(expected_path) as Mesh
		if (
			instance.mesh is PrimitiveMesh
			or instance.mesh.resource_path != expected_path
			or instance.mesh != expected_resource
		):
			errors.append("LOD%d component %s is not the exact cached imported mesh" % [lod, component])
		if instance.transform != Transform3D.IDENTITY or not instance.visible:
			errors.append("LOD%d component %s transform or visibility drifted" % [lod, component])
		if instance.custom_aabb != EXPECTED_BOUNDS:
			errors.append("LOD%d component %s synchronized custom AABB drifted" % [lod, component])
		if instance.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED:
			errors.append("LOD%d component %s unexpectedly enables range fading" % [lod, component])
		if lod == 0:
			if (
				not is_zero_approx(instance.visibility_range_begin)
				or not is_equal_approx(instance.visibility_range_end, LOD_SWITCH_DISTANCE_M)
				or not is_zero_approx(instance.visibility_range_begin_margin)
				or not is_equal_approx(instance.visibility_range_end_margin, LOD_SWITCH_MARGIN_M)
			):
				errors.append("LOD0 component %s near visibility range drifted" % component)
		else:
			if (
				not is_equal_approx(instance.visibility_range_begin, LOD_SWITCH_DISTANCE_M)
				or not is_zero_approx(instance.visibility_range_end)
				or not is_equal_approx(instance.visibility_range_begin_margin, LOD_SWITCH_MARGIN_M)
				or not is_zero_approx(instance.visibility_range_end_margin)
			):
				errors.append("LOD1 component %s far visibility range drifted" % component)
		var material_role_index := _material_role_index(component)
		var expected_material: StandardMaterial3D = (
			materials[material_role_index]
			if material_role_index >= 0 and material_role_index < materials.size()
			else null
		)
		if expected_material == null or instance.material_override != expected_material:
			errors.append("LOD%d component %s material-role identity drifted" % [lod, component])
		var artifact := _manifest_component_record(manifest_record, "component_artifacts", component)
		var object_record := _manifest_component_record(manifest_record, "objects", component)
		var expected_uv_role_index := _uv_role_index(component)
		if expected_uv_role_index < 0 or str(object_record.get("uv_role", "")) != UV_ROLE_ORDER[expected_uv_role_index]:
			errors.append("LOD%d component %s declared UV role drifted" % [lod, component])
		if str(artifact.get("path", "")) != expected_path:
			errors.append("LOD%d component %s manifest resource path drifted" % [lod, component])
		var component_sha256 := _sha256(expected_path)
		if component_sha256 != str(artifact.get("sha256", "")):
			errors.append("LOD%d component %s content hash drifted" % [lod, component])
		var metrics := _mesh_metrics(instance.mesh, "LOD%d %s" % [lod, component], component, object_record, errors)
		var bounds := instance.get_aabb()
		if (
			int(metrics.triangle_count) != int(object_record.get("triangle_count", -1))
			or not _aabb_matches_record(bounds, object_record.get("aabb", {}) as Dictionary)
		):
			errors.append("LOD%d component %s live topology diverges from manifest" % [lod, component])
		vertex_count += int(metrics.vertex_count)
		triangle_count += int(metrics.triangle_count)
		surface_count += int(metrics.surface_count)
		combined_bounds = bounds if not has_bounds else combined_bounds.merge(bounds)
		has_bounds = true
		components.append({
			"name": component,
			"path": expected_path,
			"sha256": component_sha256,
			"vertex_count": int(metrics.vertex_count),
			"source_obj_vertex_count": int(object_record.get("vertex_count", -1)),
			"triangle_count": int(metrics.triangle_count),
			"surface_count": int(metrics.surface_count),
			"uv_islands": (metrics.get("uv_islands", []) as Array).duplicate(),
			"uv_projection_bounds": (object_record.get("uv_projection_bounds", []) as Array).duplicate(true),
			"uv_role": str(object_record.get("uv_role", "")),
			"material_role": MATERIAL_ROLE_ORDER[material_role_index] if material_role_index >= 0 else "",
			"aabb": bounds,
		})
	if components.size() != EXPECTED_COMPONENTS.size():
		errors.append("LOD%d audit did not resolve all 13 semantic components" % lod)
	if (
		vertex_count != EXPECTED_LOD_VERTICES[lod]
		or triangle_count != EXPECTED_LOD_TRIANGLES[lod]
		or triangle_count != int(manifest_record.get("triangle_count", -1))
	):
		errors.append("LOD%d aggregate topology drifted (live vertices=%d triangles=%d, expected vertices=%d triangles=%d)" % [lod, vertex_count, triangle_count, EXPECTED_LOD_VERTICES[lod], EXPECTED_LOD_TRIANGLES[lod]])
	if not combined_bounds.is_equal_approx(EXPECTED_BOUNDS):
		errors.append("LOD%d aggregate authored bounds drifted" % lod)
	return {
		"lod": lod,
		"components": components,
		"component_count": components.size(),
		"vertex_count": vertex_count,
		"source_obj_vertex_count": int(manifest_record.get("vertex_count", -1)),
		"triangle_count": triangle_count,
		"surface_count": surface_count,
		"aabb": combined_bounds,
	}


func _mesh_metrics(
	mesh: Mesh,
	label: String,
	component: String,
	object_record: Dictionary,
	errors: PackedStringArray
) -> Dictionary:
	var vertex_count := 0
	var triangle_count := 0
	var surface_count := mesh.get_surface_count() if mesh != null else 0
	var seen_signed_axes := PackedByteArray()
	seen_signed_axes.resize(SIGNED_AXIS_ORDER.size())
	var projection_bounds := _projection_bounds_from_record(
		object_record.get("uv_projection_bounds", []),
		label,
		errors
	)
	if not mesh is ArrayMesh:
		errors.append("%s must use the exact imported ArrayMesh resource" % label)
		return {
			"vertex_count": vertex_count,
			"triangle_count": triangle_count,
			"surface_count": surface_count,
		}
	if surface_count != 1:
		errors.append("%s must retain one imported semantic surface" % label)
	for surface_index in surface_count:
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			errors.append("%s surface is not authored triangle topology" % label)
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if (
			vertices.is_empty()
			or normals.size() != vertices.size()
			or tangents.size() != vertices.size() * 4
			or uvs.size() != vertices.size()
			or indices.is_empty()
			or indices.size() % 3 != 0
		):
			errors.append("%s imported vertex, normal, tangent, UV or index arrays drifted" % label)
		var uv_finite_and_bounded := true
		var uv_exact := true
		var first_uv_drift := ""
		if (
			uvs.size() == vertices.size()
			and normals.size() == vertices.size()
			and projection_bounds.size() == SIGNED_AXIS_ORDER.size()
		):
			var live_projection_bounds := _projection_bounds(vertices, normals)
			if not _projection_bounds_match(live_projection_bounds, projection_bounds):
				errors.append("%s live projection bounds diverged from the authored mapping record" % label)
			for vertex_index in vertices.size():
				var uv := uvs[vertex_index]
				var axis_index := _signed_dominant_axis_index(normals[vertex_index])
				seen_signed_axes[axis_index] = 1
				var island := _atlas_island_rect(_uv_role_index(component), axis_index)
				var inside_island := (
					uv_finite_and_bounded
					and is_finite(uv.x)
					and is_finite(uv.y)
					and uv.x >= island.position.x - UV_AUDIT_TOLERANCE
					and uv.y >= island.position.y - UV_AUDIT_TOLERANCE
					and uv.x <= island.end.x + UV_AUDIT_TOLERANCE
					and uv.y <= island.end.y + UV_AUDIT_TOLERANCE
				)
				uv_finite_and_bounded = uv_finite_and_bounded and inside_island
				var expected_uv := _expected_atlas_uv(component, vertices[vertex_index], normals[vertex_index], projection_bounds)
				var matches_projection := uv.distance_to(expected_uv) <= UV_AUDIT_TOLERANCE
				uv_exact = uv_exact and matches_projection
				if first_uv_drift.is_empty() and (not inside_island or not matches_projection):
					first_uv_drift = " vertex=%s normal=%s uv=%s expected=%s axis=%s" % [vertices[vertex_index], normals[vertex_index], uv, expected_uv, SIGNED_AXIS_ORDER[axis_index]]
		else:
			uv_finite_and_bounded = false
			uv_exact = false
		if not uv_finite_and_bounded:
			errors.append("%s UV escaped its semantic signed-axis island%s" % [label, first_uv_drift])
		if not uv_exact:
			errors.append("%s live UV mapping diverged from the deterministic atlas projection%s" % [label, first_uv_drift])
		vertex_count += vertices.size()
		triangle_count += indices.size() / 3
	var used_axes: Array[String] = []
	for axis_index in SIGNED_AXIS_ORDER.size():
		if seen_signed_axes[axis_index] != 0:
			used_axes.append(SIGNED_AXIS_ORDER[axis_index])
	if used_axes.size() != SIGNED_AXIS_ORDER.size():
		errors.append("%s does not exercise all six reserved signed-axis islands" % label)
	return {
		"vertex_count": vertex_count,
		"triangle_count": triangle_count,
		"surface_count": surface_count,
		"uv_islands": used_axes,
	}


func _audit_materials(materials: Array[StandardMaterial3D], errors: PackedStringArray) -> void:
	if materials.size() != MATERIAL_ROLE_ORDER.size():
		errors.append("canonical three-role authored material roster is incomplete")
		return
	for role_index in MATERIAL_ROLE_ORDER.size():
		var material := materials[role_index]
		if material == null:
			errors.append("canonical %s material is missing" % MATERIAL_ROLE_ORDER[role_index])
			continue
		if material.resource_path != EXPECTED_MATERIAL_PATHS[role_index]:
			errors.append("canonical %s material resource identity drifted" % MATERIAL_ROLE_ORDER[role_index])
		if material.uv1_triplanar or material.texture_repeat:
			errors.append("canonical %s material UV policy drifted" % MATERIAL_ROLE_ORDER[role_index])

	var atlas := materials[0]
	if atlas != null:
		if (
			atlas.albedo_color != Color.WHITE
			or not is_equal_approx(atlas.metallic, 1.0)
			or atlas.metallic_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			or not is_equal_approx(atlas.roughness, 1.0)
			or atlas.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_RED
			or not atlas.normal_enabled
			or not is_equal_approx(atlas.normal_scale, 0.2)
			or not atlas.ao_enabled
			or atlas.ao_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_RED
			or not is_equal_approx(atlas.ao_light_affect, 0.2)
			or not atlas.emission_enabled
			or atlas.emission != Color(0.35, 0.85, 0.9, 1.0)
			or not is_equal_approx(atlas.emission_energy_multiplier, 0.18)
		):
			errors.append("canonical stepped-side trim material physical response drifted")
		var live_textures := {
			"albedo": atlas.albedo_texture,
			"normal": atlas.normal_texture,
			"roughness": atlas.roughness_texture,
			"orm": atlas.ao_texture,
			"emissive": atlas.emission_texture,
		}
		if atlas.metallic_texture != atlas.ao_texture:
			errors.append("canonical atlas material no longer shares its packed ORM resource")
		for key: String in RUNTIME_TEXTURES:
			var texture := live_textures.get(key) as Texture2D
			var expected_path := str(RUNTIME_TEXTURES[key])
			if texture == null or texture.resource_path != expected_path or texture != ResourceLoader.load(expected_path):
				errors.append("canonical atlas material %s texture resource drifted" % key)
			if texture != null and texture.resource_path == FORBIDDEN_FLAT_STUDY_TEXTURE:
				errors.append("canonical atlas material illegally binds the flat-albedo study")
			if _sha256(expected_path) != str(RUNTIME_TEXTURE_SHA256[key]):
				errors.append("canonical atlas material %s texture content drifted" % key)

	_audit_untextured_material(
		materials[1], Color(0.9, 0.88, 0.78, 1.0), 0.08, 0.58,
		"warm ivory", errors
	)
	_audit_untextured_material(
		materials[2], Color(0.035, 0.055, 0.06, 1.0), 0.28, 0.42,
		"restrained graphite", errors
	)

	for lod in 2:
		for component: String in EXPECTED_COMPONENTS:
			var instance := get_node_or_null("Dated2011Form/MacroformLOD%d/%s" % [lod, component]) as MeshInstance3D
			var role_index := _material_role_index(component)
			if instance == null or role_index < 0 or instance.material_override != materials[role_index]:
				errors.append("LOD%d component %s violates exact material-role membership" % [lod, component])


func _audit_untextured_material(
	material: StandardMaterial3D,
	expected_albedo: Color,
	expected_metallic: float,
	expected_roughness: float,
	label: String,
	errors: PackedStringArray
) -> void:
	if material == null:
		return
	if (
		material.albedo_color != expected_albedo
		or not is_equal_approx(material.metallic, expected_metallic)
		or not is_equal_approx(material.roughness, expected_roughness)
		or material.albedo_texture != null
		or material.metallic_texture != null
		or material.roughness_texture != null
		or material.normal_enabled
		or material.normal_texture != null
		or material.ao_enabled
		or material.ao_texture != null
		or material.emission_enabled
		or material.emission_texture != null
	):
		errors.append("canonical %s material properties or no-texture contract drifted" % label)


func _audit_identity_metadata(errors: PackedStringArray) -> void:
	var expected_root_metadata := {
		"identity_lock": "b5_observed_name_to_model",
		"historical_revision": "unverified",
		"source_upload_date": "2011-06-29",
		"recording_date_status": "unknown",
		"game_build_revision_status": "unknown",
		"reconstruction_status": "partial",
		"geometry_status": "source_aligned_partial",
		"continuity_2009": "unproved",
		"source_reference": "B5",
		"absolute_scale_status": "modern_ergonomic_normalization",
	}
	for key: String in expected_root_metadata:
		if str(get_meta(key, "")) != str(expected_root_metadata[key]):
			errors.append("presentation evidence metadata drifted: %s" % key)
	for false_claim: String in [
		"authenticated_geometry", "exact_geometry", "authenticated_exact_geometry",
		"authenticated_historical_silhouette", "collision_authority",
	]:
		if bool(get_meta(false_claim, true)):
			errors.append("presentation evidence boundary drifted: %s" % false_claim)
	var dated_form := get_node_or_null("Dated2011Form") as Node3D
	if dated_form != null and (
		str(dated_form.get_meta("evidence_status", "")) != "source_aligned_partial"
		or str(dated_form.get_meta("source_reference", "")) != "B5"
		or not bool(dated_form.get_meta("historically_supported", false))
		or bool(dated_form.get_meta("exact_topology_authenticated", true))
	):
		errors.append("Dated2011Form evidence metadata drifted")
	_audit_semantic_metadata(errors)


func _audit_semantic_metadata(errors: PackedStringArray) -> void:
	var lod0 := get_node_or_null("Dated2011Form/MacroformLOD0") as Node3D
	if lod0 == null:
		return
	var roles := {
		"PointedNose": "pointed_nose",
		"RaisedSpine": "raised_spine",
		"BlockyAftBody": "blocky_aft",
		"PortAftRail": "upright_aft_rail",
		"StarboardAftRail": "upright_aft_rail",
	}
	for component: String in roles:
		var node := lod0.get_node_or_null(component)
		if (
			node == null
			or str(node.get_meta("silhouette_role", "")) != str(roles[component])
			or str(node.get_meta("source_reference", "")) != "B5"
		):
			errors.append("semantic source role drifted: %s" % component)
	for side_name: String in ["Port", "Starboard"]:
		for tier_name: String in ["Lower", "Upper"]:
			var component := "%s%sSidePlane" % [side_name, tier_name]
			var node := lod0.get_node_or_null(component)
			if (
				node == null
				or str(node.get_meta("silhouette_role", "")) != "stepped_side_plane"
				or str(node.get_meta("side", "")) != side_name.to_lower()
				or str(node.get_meta("tier", "")) != tier_name.to_lower()
				or not bool(node.get_meta("stepped_edge", false))
				or str(node.get_meta("source_reference", "")) != "B5"
			):
				errors.append("stepped side-plane metadata drifted: %s" % component)
	for component: String in ["PortAftCircularHousing", "StarboardAftCircularHousing"]:
		var node := lod0.get_node_or_null(component)
		if (
			node == null
			or not bool(node.get_meta("circular_form", false))
			or str(node.get_meta("historical_function", "")) != "unknown"
			or not bool(node.get_meta("historical_function_unresolved", false))
			or str(node.get_meta("modern_interpretation", "")) != "engine"
			or str(node.get_meta("interpretation_status", "")) != "modern"
			or str(node.get_meta("source_reference", "")) != "B5"
		):
			errors.append("aft housing evidence metadata drifted: %s" % component)
	var crossbar := lod0.get_node_or_null("AftCrossbar")
	if (
		crossbar == null
		or str(crossbar.get_meta("silhouette_role", "")) != "aft_crossbar"
		or str(crossbar.get_meta("evidence_status", "")) != "inferred_reconstruction"
		or bool(crossbar.get_meta("historically_supported", true))
		or str(crossbar.get_meta("source_basis", "")) != "B5_u_like_rear_read"
	):
		errors.append("inferred aft-crossbar evidence metadata drifted")


func _audit_manifest_provenance(provenance: Dictionary, errors: PackedStringArray) -> void:
	if (
		str(provenance.get("identity_lock", "")) != "b5_observed_name_to_model"
		or str(provenance.get("historical_revision", "")) != "unverified"
		or str(provenance.get("source_upload_date", "")) != "2011-06-29"
		or str(provenance.get("recording_date_status", "")) != "unknown"
		or str(provenance.get("game_build_revision_status", "")) != "unknown"
		or provenance.get("source_references", []) != ["B5"]
		or str(provenance.get("geometry_status", "")) != "source_aligned_partial"
		or str(provenance.get("reconstruction_status", "")) != "partial"
		or str(provenance.get("2009_continuity", "")) != "unproved"
		or str(provenance.get("absolute_scale_status", "")) != "modern_ergonomic_normalization"
		or str(provenance.get("aft_housing_historical_function", "")) != "unknown"
		or str(provenance.get("aft_crossbar_evidence_status", "")) != "inferred_reconstruction"
		or bool(provenance.get("aft_crossbar_historically_supported", true))
	):
		errors.append("authored asset provenance boundary drifted")
	for false_claim: String in [
		"authenticated_geometry", "exact_geometry", "authenticated_exact_geometry",
		"authenticated_historical_silhouette", "copied_source_geometry",
	]:
		if bool(provenance.get(false_claim, true)):
			errors.append("authored asset manifest makes unsupported claim: %s" % false_claim)


func _audit_manifest_texture_contract(contract: Dictionary, errors: PackedStringArray) -> void:
	if (
		str(contract.get("origin", "")) != "modern_project_original"
		or str(contract.get("mapping", "")) != "intentional_non_seamless_weighted_role_signed_axis_trim_v2"
		or int(contract.get("uv_set", -1)) != 0
		or bool(contract.get("triplanar", true))
		or bool(contract.get("repeat", true))
		or str(contract.get("source_kind", "")) != "image_derived_proxy_trim_atlas"
		or bool(contract.get("final_hand_authored_pbr", true))
		or str(contract.get("production_usage", "")) != "selected_stepped_side_planes_only"
		or contract.get("atlas_sampling_roles", []) != ATLAS_SAMPLING_ROLES
		or contract.get("atlas_sampling_semantics", []) != ATLAS_SAMPLING_SEMANTICS
	):
		errors.append("authored texture evidence or UV contract drifted")
	_audit_manifest_uv_layout(contract.get("uv_layout", {}) as Dictionary, errors)
	for key: String in RUNTIME_TEXTURES:
		if str(contract.get("runtime_%s" % key, "")) != str(RUNTIME_TEXTURES[key]):
			errors.append("manifest runtime %s texture path drifted" % key)


func _audit_manifest_uv_layout(layout: Dictionary, errors: PackedStringArray) -> void:
	var islands := layout.get("islands", []) as Array
	if (
		str(layout.get("layout_id", "")) != UV_LAYOUT_ID
		or layout.get("semantic_order", []) != EXPECTED_COMPONENTS
		or layout.get("role_order", []) != UV_ROLE_ORDER
		or layout.get("role_members", []) != UV_ROLE_MEMBERS
		or layout.get("signed_axis_order", []) != SIGNED_AXIS_ORDER
		or int(layout.get("columns", 0)) != UV_ATLAS_COLUMNS
		or int(layout.get("rows", 0)) != UV_ATLAS_ROWS
		or layout.get("column_weights", []) != UV_ATLAS_COLUMN_WEIGHTS
		or not is_equal_approx(float(layout.get("outer_guard", -1.0)), UV_ATLAS_OUTER_GUARD)
		or not is_equal_approx(float(layout.get("cell_gutter", -1.0)), UV_ATLAS_CELL_GUTTER)
		or int(layout.get("island_count", 0)) != UV_ROLE_ORDER.size() * SIGNED_AXIS_ORDER.size()
		or bool(layout.get("cross_role_overlap", true))
		or not bool(layout.get("intentional_within_role_reuse", false))
		or str(layout.get("cross_semantic_overlap", "")) != "within_declared_role_only"
		or bool(layout.get("cross_signed_axis_overlap", true))
		or not bool(layout.get("lods_share_layout", false))
		or str(layout.get("dominant_axis_tie_break", "")) != "X_then_Y_then_Z"
		or not is_equal_approx(float(layout.get("dominant_axis_tie_epsilon", -1.0)), UV_DOMINANT_AXIS_TIE_EPSILON)
		or str(layout.get("obj_v_encoding", "")) != "one_minus_internal_v"
		or str(layout.get("projection_normalization", "")) != "per_lod_semantic_signed_axis_local_bounds"
		or islands.size() != UV_ROLE_ORDER.size() * SIGNED_AXIS_ORDER.size()
	):
		errors.append("declared-role signed-axis atlas layout header drifted")
		return
	var rectangles: Array[Rect2] = []
	for role_index in UV_ROLE_ORDER.size():
		for axis_index in SIGNED_AXIS_ORDER.size():
			var record_index := role_index * SIGNED_AXIS_ORDER.size() + axis_index
			var record := islands[record_index] as Dictionary
			var expected := _atlas_island_rect(role_index, axis_index)
			var actual := Rect2(
				_vector2_record(record.get("uv_min", [])),
				_vector2_record(record.get("uv_max", [])) - _vector2_record(record.get("uv_min", []))
			)
			if (
				str(record.get("role", "")) != UV_ROLE_ORDER[role_index]
				or record.get("members", []) != UV_ROLE_MEMBERS[role_index]
				or str(record.get("signed_axis", "")) != SIGNED_AXIS_ORDER[axis_index]
				or int(record.get("column", -1)) != role_index
				or int(record.get("row", -1)) != axis_index
				or not actual.is_equal_approx(expected)
			):
				errors.append("atlas island record drifted for %s %s" % [UV_ROLE_ORDER[role_index], SIGNED_AXIS_ORDER[axis_index]])
			rectangles.append(actual)
	for first_index in rectangles.size():
		for second_index in range(first_index + 1, rectangles.size()):
			if rectangles[first_index].intersects(rectangles[second_index]):
				errors.append("declared-role signed-axis atlas islands overlap")
				return


func _uv_layout_contract() -> Dictionary:
	var islands: Array[Dictionary] = []
	for role_index in UV_ROLE_ORDER.size():
		for axis_index in SIGNED_AXIS_ORDER.size():
			var island := _atlas_island_rect(role_index, axis_index)
			islands.append({
				"role": UV_ROLE_ORDER[role_index],
				"members": (UV_ROLE_MEMBERS[role_index] as Array).duplicate(),
				"signed_axis": SIGNED_AXIS_ORDER[axis_index],
				"column": role_index,
				"row": axis_index,
				"uv_min": [_rounded_uv(island.position.x), _rounded_uv(island.position.y)],
				"uv_max": [_rounded_uv(island.end.x), _rounded_uv(island.end.y)],
			})
	return {
		"layout_id": UV_LAYOUT_ID,
		"semantic_order": EXPECTED_COMPONENTS.duplicate(),
		"role_order": UV_ROLE_ORDER.duplicate(),
		"role_members": UV_ROLE_MEMBERS.duplicate(true),
		"signed_axis_order": SIGNED_AXIS_ORDER.duplicate(),
		"columns": UV_ATLAS_COLUMNS,
		"rows": UV_ATLAS_ROWS,
		"column_weights": UV_ATLAS_COLUMN_WEIGHTS.duplicate(),
		"outer_guard": UV_ATLAS_OUTER_GUARD,
		"cell_gutter": UV_ATLAS_CELL_GUTTER,
		"island_count": islands.size(),
		"cross_role_overlap": false,
		"intentional_within_role_reuse": true,
		"cross_semantic_overlap": "within_declared_role_only",
		"cross_signed_axis_overlap": false,
		"lods_share_layout": true,
		"dominant_axis_tie_break": "X_then_Y_then_Z",
		"dominant_axis_tie_epsilon": UV_DOMINANT_AXIS_TIE_EPSILON,
		"obj_v_encoding": "one_minus_internal_v",
		"projection_normalization": "per_lod_semantic_signed_axis_local_bounds",
		"islands": islands,
	}


func _expected_atlas_uv(
	component: String,
	point: Vector3,
	normal: Vector3,
	projection_bounds: Array[Rect2]
) -> Vector2:
	var role_index := _uv_role_index(component)
	var axis_index := _signed_dominant_axis_index(normal)
	var projection := _dominant_axis_projection(point, axis_index)
	var bounds := projection_bounds[axis_index]
	var local := Vector2(
		(projection.x - bounds.position.x) / bounds.size.x,
		(projection.y - bounds.position.y) / bounds.size.y
	).clamp(Vector2.ZERO, Vector2.ONE)
	var island := _atlas_island_rect(role_index, axis_index)
	return island.position + local * island.size


func _uv_role_index(component: String) -> int:
	for role_index in UV_ROLE_MEMBERS.size():
		if component in UV_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _projection_bounds(positions: PackedVector3Array, normals: PackedVector3Array) -> Array[Rect2]:
	var minimums: Array[Vector2] = []
	var maximums: Array[Vector2] = []
	for axis_index in SIGNED_AXIS_ORDER.size():
		minimums.append(Vector2(INF, INF))
		maximums.append(Vector2(-INF, -INF))
	for vertex_index in mini(positions.size(), normals.size()):
		var axis_index := _signed_dominant_axis_index(normals[vertex_index])
		var projected := _dominant_axis_projection(positions[vertex_index], axis_index)
		minimums[axis_index] = minimums[axis_index].min(projected)
		maximums[axis_index] = maximums[axis_index].max(projected)
	var bounds: Array[Rect2] = []
	for axis_index in SIGNED_AXIS_ORDER.size():
		bounds.append(Rect2(minimums[axis_index], maximums[axis_index] - minimums[axis_index]))
	return bounds


func _projection_bounds_from_record(
	value: Variant,
	label: String,
	errors: PackedStringArray
) -> Array[Rect2]:
	var records := value as Array
	var bounds: Array[Rect2] = []
	if records.size() != SIGNED_AXIS_ORDER.size():
		errors.append("%s manifest must publish six local UV projection bounds" % label)
		return bounds
	for axis_index in SIGNED_AXIS_ORDER.size():
		var record := records[axis_index] as Dictionary
		var minimum := _vector2_record(record.get("projected_min", []))
		var maximum := _vector2_record(record.get("projected_max", []))
		var size := maximum - minimum
		if str(record.get("signed_axis", "")) != SIGNED_AXIS_ORDER[axis_index] or size.x <= 0.000001 or size.y <= 0.000001:
			errors.append("%s manifest local UV projection bound drifted for %s" % [label, SIGNED_AXIS_ORDER[axis_index]])
		bounds.append(Rect2(minimum, size))
	return bounds


func _projection_bounds_match(actual: Array[Rect2], expected: Array[Rect2]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if (
			actual[index].position.distance_to(expected[index].position) > UV_AUDIT_TOLERANCE
			or actual[index].end.distance_to(expected[index].end) > UV_AUDIT_TOLERANCE
		):
			return false
	return true


func _signed_dominant_axis_index(normal: Vector3) -> int:
	var absolute := normal.abs()
	var maximum := maxf(absolute.x, maxf(absolute.y, absolute.z))
	if absolute.x >= maximum - UV_DOMINANT_AXIS_TIE_EPSILON:
		return 0 if normal.x >= 0.0 else 1
	if absolute.y >= maximum - UV_DOMINANT_AXIS_TIE_EPSILON:
		return 2 if normal.y >= 0.0 else 3
	return 4 if normal.z >= 0.0 else 5


func _dominant_axis_projection(point: Vector3, axis_index: int) -> Vector2:
	var x := (point.x + 3.60) / 7.20
	var y := (point.y + 0.39) / 4.54
	var z := (point.z + 4.80) / 8.40
	match axis_index:
		0: return Vector2(z, y)
		1: return Vector2(1.0 - z, y)
		2: return Vector2(x, z)
		3: return Vector2(x, 1.0 - z)
		4: return Vector2(1.0 - x, y)
		_: return Vector2(x, y)


func _atlas_island_rect(role_index: int, axis_index: int) -> Rect2:
	var guarded_size := 1.0 - UV_ATLAS_OUTER_GUARD * 2.0
	var normalized_column_start := 0.0
	for previous_role_index in role_index:
		normalized_column_start += float(UV_ATLAS_COLUMN_WEIGHTS[previous_role_index])
	var cell_size := Vector2(
		guarded_size * float(UV_ATLAS_COLUMN_WEIGHTS[role_index]),
		guarded_size / float(UV_ATLAS_ROWS)
	)
	var cell_origin := Vector2(
		UV_ATLAS_OUTER_GUARD + guarded_size * normalized_column_start,
		UV_ATLAS_OUTER_GUARD + float(axis_index) * cell_size.y
	)
	return Rect2(cell_origin + Vector2.ONE * UV_ATLAS_CELL_GUTTER, cell_size - Vector2.ONE * UV_ATLAS_CELL_GUTTER * 2.0)


func _vector2_record(value: Variant) -> Vector2:
	var values := value as Array
	return Vector2(float(values[0]), float(values[1])) if values.size() == 2 else Vector2(-10.0, -10.0)


func _rounded_uv(value: float) -> float:
	return snappedf(value, 0.00001)


func _audit_no_forbidden_authority(errors: PackedStringArray) -> void:
	for type_name: String in [
		"CollisionObject3D", "CollisionShape3D", "CollisionPolygon3D", "Area3D",
		"Light3D", "GPUParticles3D", "CPUParticles3D", "Decal",
	]:
		if not find_children("*", type_name, true, false).is_empty():
			errors.append("presentation owns forbidden gameplay or rogue visual type %s" % type_name)


func _expected_materials() -> Array[StandardMaterial3D]:
	var materials: Array[StandardMaterial3D] = []
	for component: String in ["PortLowerSidePlane", "PointedNose", "PortAftCircularHousing"]:
		var inspection := get_node_or_null("Dated2011Form/MacroformLOD0/%s" % component) as MeshInstance3D
		materials.append(inspection.material_override as StandardMaterial3D if inspection != null else null)
	return materials


func _material_role_index(component: String) -> int:
	for role_index in MATERIAL_ROLE_MEMBERS.size():
		if component in MATERIAL_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _material_roles_contract() -> Array[Dictionary]:
	return [
		{
			"role": MATERIAL_ROLE_ORDER[0],
			"members": (MATERIAL_ROLE_MEMBERS[0] as Array).duplicate(),
			"resource_path": EXPECTED_MATERIAL_PATHS[0],
			"texture_usage": "image_derived_proxy_trim_atlas",
			"albedo_color": Color.WHITE,
			"metallic": 1.0,
			"roughness": 1.0,
			"normal_scale": 0.2,
		},
		{
			"role": MATERIAL_ROLE_ORDER[1],
			"members": (MATERIAL_ROLE_MEMBERS[1] as Array).duplicate(),
			"resource_path": EXPECTED_MATERIAL_PATHS[1],
			"texture_usage": "none",
			"albedo_color": Color(0.9, 0.88, 0.78, 1.0),
			"metallic": 0.08,
			"roughness": 0.58,
		},
		{
			"role": MATERIAL_ROLE_ORDER[2],
			"members": (MATERIAL_ROLE_MEMBERS[2] as Array).duplicate(),
			"resource_path": EXPECTED_MATERIAL_PATHS[2],
			"texture_usage": "none",
			"albedo_color": Color(0.035, 0.055, 0.06, 1.0),
			"metallic": 0.28,
			"roughness": 0.42,
		},
	]


func _manifest_lod_record(manifest: Dictionary, lod: int) -> Dictionary:
	for value: Variant in manifest.get("lods", []):
		var record := value as Dictionary
		if int(record.get("lod", -1)) == lod:
			return record
	return {}


func _manifest_component_record(record: Dictionary, field: String, component: String) -> Dictionary:
	for value: Variant in record.get(field, []):
		var candidate := value as Dictionary
		if str(candidate.get("name", "")) == component:
			return candidate
	return {}


func _aabb_matches_record(bounds: AABB, record: Dictionary) -> bool:
	var position_values := record.get("position", []) as Array
	var size_values := record.get("size", []) as Array
	if position_values.size() != 3 or size_values.size() != 3:
		return false
	var expected := AABB(
		Vector3(float(position_values[0]), float(position_values[1]), float(position_values[2])),
		Vector3(float(size_values[0]), float(size_values[1]), float(size_values[2]))
	)
	return bounds.is_equal_approx(expected)


func _aggregate_mesh_path(lod: int) -> String:
	return "res://assets/models/torrent/torrent_macroform_lod%d.obj" % lod


func _component_mesh_path(lod: int, component: String) -> String:
	return (
		"res://assets/models/torrent/torrent_macroform_lod%d_%s.obj"
		% [lod, component.to_snake_case()]
	)


func _sha256(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path))


func _fingerprint(
	manifest_sha256: String,
	lod_reports: Array[Dictionary],
	materials: Array[StandardMaterial3D]
) -> String:
	var payload := "%s|%s|%s|%s" % [ASSET_ID, ASSET_REVISION, COMPONENT_ID, manifest_sha256]
	for lod_report: Dictionary in lod_reports:
		payload += "|lod=%d|v=%d|t=%d" % [
			int(lod_report.get("lod", -1)),
			int(lod_report.get("vertex_count", 0)),
			int(lod_report.get("triangle_count", 0)),
		]
		for component: Dictionary in lod_report.get("components", []):
			payload += "|%s=%s@%s" % [
				str(component.get("name", "")),
				str(component.get("sha256", "")),
				str(component.get("material_role", "")),
			]
	for role_index in materials.size():
		var material := materials[role_index]
		if material == null:
			payload += "|material_%d=null" % role_index
			continue
		payload += "|material_%d=%s|rgba=%.6f,%.6f,%.6f,%.6f|m=%.6f|r=%.6f|n=%s:%.6f|ao=%s:%.6f|e=%s:%.6f" % [
			role_index,
			material.resource_path,
			material.albedo_color.r, material.albedo_color.g,
			material.albedo_color.b, material.albedo_color.a,
			material.metallic, material.roughness,
			material.normal_enabled, material.normal_scale,
			material.ao_enabled, material.ao_light_affect,
			material.emission_enabled, material.emission_energy_multiplier,
		]
		for texture: Texture2D in [
			material.albedo_texture, material.metallic_texture,
			material.roughness_texture, material.normal_texture,
			material.ao_texture, material.emission_texture,
		]:
			payload += ":%s" % (texture.resource_path if texture != null else "null")
	for key: String in ["albedo", "normal", "roughness", "orm", "emissive"]:
		payload += "|%s=%s" % [key, _sha256(str(RUNTIME_TEXTURES[key]))]
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(payload.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()
