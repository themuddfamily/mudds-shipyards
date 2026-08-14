extends SceneTree

const PRESENTATION_SCENE := preload("res://scenes/ships/presentation/torrent_authored_macroform.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const PRESENTATION_PATH := "res://scenes/ships/presentation/torrent_authored_macroform.tscn"
const MANIFEST_PATH := "res://assets/models/torrent/torrent_authored_asset_manifest.json"
const LOD_PATHS := [
	"res://assets/models/torrent/torrent_macroform_lod0.obj",
	"res://assets/models/torrent/torrent_macroform_lod1.obj",
]
const SOURCE_TEXTURES := {
	"res://assets/models/torrent/textures/torrent-hero-trim-albedo-v1.png": "21536687fe1b5b7ddba305f696d1e7a53f29bd14774db3ec1411af12b6622b76",
	"res://assets/models/torrent/textures/torrent-hero-flat-albedo-study-v1.png": "c480681c5c94ca7baa01668127f0084e61adbf86e8c3826dbe208b7f8c81f063",
}
const RUNTIME_TEXTURES := {
	"albedo": ["res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png", "17ccc04b8e641b4890cbacb7842b2fb24e2bbbbd00a7628fc5d9fa86c1b74b12"],
	"normal": ["res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png", "c86817d88739b85835efd8626a2ce2c540620fa8a0af985e4bc5384d1599e357"],
	"roughness": ["res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png", "57255d680fc060dd74a040f3bea27d55e9e93dba35f42985ada956f92bacfa42"],
	"orm": ["res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png", "8f754d93a36b12eb6a031c8c9675da6e54591844c5582fee1063d6d3b523b2cd"],
	"emissive": ["res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png", "398be72d094af6a429d9f06ec7eeeb855850b9873648d2d2f70e6b85e47cbd69"],
}
const GOLDEN_MANIFEST_SHA256 := "a44136e7d9374206269391a64536a890576ddac29ca1949ef3e57db6c9a8c459"
const GOLDEN_LOD_SHA256 := [
	"6d6e15fbc906d9a9e4636e0595597a05bae4d345dadf945aab2a88434518abc9",
	"2755293411bbf2f5a38b59ff1390c1198b7d6013b693d1a742698ebfccf00110",
]
const GOLDEN_GEOMETRY_ONLY_SHA256 := [
	"91a24751b27f9e30949241db18914f3ca9820324d0ecf29f5507fc89c9820050",
	"c1da2f93e70fb30d30e2db5da2c1ad75e00988d9339944af49672026548cb856",
]
const EXPECTED_LOD_TRIANGLES := [4636, 632]
const EXPECTED_COMPONENTS := [
	"PointedNose", "CentralPressureKeel", "RaisedSpine", "BlockyAftBody",
	"PortLowerSidePlane", "PortUpperSidePlane", "StarboardLowerSidePlane",
	"StarboardUpperSidePlane", "PortAftCircularHousing",
	"StarboardAftCircularHousing", "PortAftRail", "StarboardAftRail", "AftCrossbar",
]
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
const EXPECTED_BOUNDS := AABB(Vector3(-3.60, -0.39, -4.80), Vector3(7.20, 4.54, 8.40))
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

var _assertions := 0
var _failures: Array[String] = []
var _manifest: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_checked_in_integrity()
	_test_deterministic_regeneration()
	var presentation := PRESENTATION_SCENE.instantiate() as TorrentAuthoredMacroform
	_check(presentation != null, "authored presentation instantiates as TorrentAuthoredMacroform")
	if presentation == null:
		_finish()
		return
	root.add_child(presentation)
	await process_frame
	_test_exact_runtime_roster(presentation)
	_test_evidence_boundary(presentation)
	var initial_snapshot := _mesh_snapshot(presentation)
	var lod_metrics := _test_lods_and_topology(presentation)
	_test_semantic_uv_atlas(presentation)
	_test_material_contract(presentation)
	_test_collision_separation(presentation)
	_test_audit_contract(presentation, lod_metrics)
	_test_adversarial_runtime_audit(presentation)
	await process_frame
	await physics_frame
	_check(_mesh_snapshot(presentation) == initial_snapshot, "runtime frames and audits do not rebuild or replace imported meshes")
	_check(not presentation.is_processing() and not presentation.is_physics_processing(), "authored presentation has no per-frame runtime generator")
	presentation.queue_free()
	await process_frame
	await _test_production_delegation()
	_finish()


func _test_checked_in_integrity() -> void:
	_check(FileAccess.file_exists(MANIFEST_PATH), "immutable authored asset manifest is checked in")
	_check(_hash(MANIFEST_PATH) == GOLDEN_MANIFEST_SHA256, "manifest bytes match the pinned audit hash")
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	_check(parsed is Dictionary, "authored asset manifest parses as a Dictionary")
	if not parsed is Dictionary:
		return
	_manifest = parsed as Dictionary
	_check(int(_manifest.get("schema_version", 0)) == 2, "manifest schema publishes the semantic signed-axis UV contract")
	_check(str(_manifest.get("asset_id", "")) == "torrent_b5_observed_authored_macroform", "manifest has the dedicated B5-observed Torrent asset identity")
	_check(str(_manifest.get("asset_revision", "")) == "v2", "manifest pins the bounded authored-relief v2 revision")
	var refinement := _manifest.get("geometry_refinement", {}) as Dictionary
	var triangle_target := refinement.get("lod0_triangle_target", []) as Array
	_check(
		str(refinement.get("revision", "")) == "bounded_authored_relief_v2"
		and triangle_target.size() == 2
		and int(triangle_target[0]) == 3000
		and int(triangle_target[1]) == 6000
		and is_equal_approx(float(refinement.get("lod1_maximum_fraction_of_lod0", -1.0)), 0.25)
		and bool(refinement.get("exact_aabb_locked", false))
		and not bool(refinement.get("new_historical_claims", true)),
		"manifest bounds the v2 relief pass without adding an evidence claim"
	)
	var lods := _manifest.get("lods", []) as Array
	_check(lods.size() == 2, "manifest declares exactly authored LOD0 and LOD1")
	for lod in mini(2, lods.size()):
		var record := lods[lod] as Dictionary
		_check(_hash(LOD_PATHS[lod]) == GOLDEN_LOD_SHA256[lod], "LOD%d aggregate OBJ matches its pinned hash" % lod)
		_check(str(record.get("sha256", "")) == GOLDEN_LOD_SHA256[lod], "LOD%d manifest hash matches the trust root" % lod)
		_check(str(record.get("geometry_only_sha256", "")) == GOLDEN_GEOMETRY_ONLY_SHA256[lod], "LOD%d retains its exact pre-UV geometry-only trust root" % lod)
		var objects := record.get("objects", []) as Array
		var object_names: Array[String] = []
		for object_value: Variant in objects:
			object_names.append(str((object_value as Dictionary).get("name", "")))
		_check(
			objects.size() == EXPECTED_COMPONENTS.size()
			and object_names == EXPECTED_COMPONENTS
			and _unique_strings(object_names).size() == EXPECTED_COMPONENTS.size(),
			"LOD%d manifest publishes exactly one ordered record per semantic object" % lod
		)
		var components := record.get("component_artifacts", []) as Array
		_check(components.size() == EXPECTED_COMPONENTS.size(), "LOD%d publishes all semantic component artifacts" % lod)
		for component_value: Variant in components:
			var component := component_value as Dictionary
			var path := str(component.get("path", ""))
			_check(FileAccess.file_exists(path), "component OBJ exists: %s" % path.get_file())
			_check(_hash(path) == str(component.get("sha256", "")), "component OBJ matches manifest hash: %s" % path.get_file())
			var import_text := _read_text(path + ".import")
			_check("generate_lods=false" in import_text, "component import disables automatic LOD generation")
			_check("force_disable_mesh_compression=true" in import_text, "component import preserves authored topology without compression")
	for path: String in SOURCE_TEXTURES:
		_check(_hash(path) == str(SOURCE_TEXTURES[path]), "source texture remains byte-identical: %s" % path.get_file())
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and image.get_size() == Vector2i(1254, 1254), "source texture preserves its 1254-square provenance master")
	for key: String in RUNTIME_TEXTURES:
		var spec := RUNTIME_TEXTURES[key] as Array
		_check(_hash(str(spec[0])) == str(spec[1]), "%s runtime map matches its deterministic hash" % key)
		var image := Image.load_from_file(ProjectSettings.globalize_path(str(spec[0])))
		_check(image != null and image.get_size() == Vector2i(1024, 1024), "%s runtime map is exactly 1024 square" % key)


func _test_deterministic_regeneration() -> void:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/generate_torrent_authored_assets.gd",
			"--", "--verify-checked-in",
		],
		output,
		true
	)
	var joined := "\n".join(PackedStringArray(output))
	_check(
		exit_code == 0
		and "TORRENT_AUTHORED_ASSET_DETERMINISM_OK" in joined,
		"offline authoring regenerates every checked-in OBJ and manifest byte-for-byte without writes"
	)


func _test_exact_runtime_roster(presentation: TorrentAuthoredMacroform) -> void:
	_check(
		presentation.name == &"TorrentAuthoredMacroform"
		and presentation.scene_file_path == PRESENTATION_PATH
		and presentation.transform == Transform3D.IDENTITY
		and presentation.visible,
		"presentation root keeps its exact identity, PackedScene, transform, and visibility"
	)
	var dated_form := presentation.get_node_or_null("Dated2011Form") as Node3D
	_check(
		presentation.get_child_count() == 1
		and dated_form != null
		and presentation.get_child(0) == dated_form
		and dated_form.transform == Transform3D.IDENTITY
		and dated_form.visible,
		"presentation owns one visible identity-transform Dated2011Form root"
	)
	_check(dated_form != null and dated_form.get_child_count() == 2, "Dated2011Form owns exactly LOD0 and LOD1")
	for lod in 2:
		var lod_root := dated_form.get_node_or_null("MacroformLOD%d" % lod) as Node3D if dated_form != null else null
		_check(
			lod_root != null
			and lod_root.get_parent() == dated_form
			and dated_form.get_child(lod) == lod_root
			and lod_root.transform == Transform3D.IDENTITY
			and lod_root.visible
			and lod_root.get_child_count() == EXPECTED_COMPONENTS.size(),
			"LOD%d has the exact visible identity-transform 13-component hierarchy" % lod
		)
		if lod_root == null:
			continue
		for component_index in EXPECTED_COMPONENTS.size():
			var component := EXPECTED_COMPONENTS[component_index] as String
			var instance := lod_root.get_node_or_null(component) as MeshInstance3D
			_check(instance != null and lod_root.get_child(component_index) == instance, "LOD%d exact semantic child order includes %s" % [lod, component])
	var visuals := presentation.find_children("*", "VisualInstance3D", true, false)
	var meshes := presentation.find_children("*", "MeshInstance3D", true, false)
	_check(visuals.size() == 26 and meshes.size() == 26, "runtime presentation contains exactly 26 mesh visuals and no rogue visual type")


func _test_evidence_boundary(presentation: TorrentAuthoredMacroform) -> void:
	var audit := presentation.get_torrent_authored_asset_audit_report()
	var provenance := audit.get("provenance", {}) as Dictionary
	_check(str(provenance.get("identity_lock", "")) == "b5_observed_name_to_model", "authored mesh is locked only to the B5-observed identity")
	_check(
		str(provenance.get("historical_revision", "")) == "unverified"
		and str(provenance.get("source_upload_date", "")) == "2011-06-29"
		and str(provenance.get("recording_date_status", "")) == "unknown"
		and str(provenance.get("game_build_revision_status", "")) == "unknown",
		"asset provenance separates the documented upload date from unknown recording/build dates"
	)
	_check(provenance.get("source_references", []) == ["B5"], "authored geometry uses source B5 only")
	_check(str(provenance.get("geometry_status", "")) == "source_aligned_partial", "macroform is explicitly source-aligned and partial")
	_check(str(provenance.get("reconstruction_status", "")) == "partial", "reconstruction detail remains partial")
	for false_claim: String in ["authenticated_geometry", "exact_geometry", "authenticated_exact_geometry", "authenticated_historical_silhouette"]:
		_check(not bool(provenance.get(false_claim, true)), "%s remains false" % false_claim)
	_check(str(provenance.get("2009_continuity", "")) == "unproved", "continuity with the 2009 craft remains unproved")
	_check(str(provenance.get("absolute_scale_status", "")) == "modern_ergonomic_normalization", "metric scale is labelled as modern normalization")
	_check(str(provenance.get("aft_housing_historical_function", "")) == "unknown", "source-observed circular housings keep unknown function")
	_check(str(provenance.get("aft_crossbar_evidence_status", "")) == "inferred_reconstruction" and not bool(provenance.get("aft_crossbar_historically_supported", true)), "aft crossbar stays inferred rather than promoted to B5 evidence")


func _test_lods_and_topology(presentation: TorrentAuthoredMacroform) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for lod in 2:
		var lod_root := presentation.get_node_or_null("Dated2011Form/MacroformLOD%d" % lod) as Node3D
		_check(lod_root != null, "authored MacroformLOD%d root resolves" % lod)
		var combined := AABB()
		var has_bounds := false
		var vertex_count := 0
		var triangle_count := 0
		var surface_count := 0
		for component: String in EXPECTED_COMPONENTS:
			var instance := lod_root.get_node_or_null(component) as MeshInstance3D if lod_root != null else null
			_check(instance != null, "LOD%d semantic MeshInstance exists: %s" % [lod, component])
			if instance == null or instance.mesh == null:
				continue
			var expected_path := "res://assets/models/torrent/torrent_macroform_lod%d_%s.obj" % [lod, component.to_snake_case()]
			_check(instance.transform == Transform3D.IDENTITY, "LOD%d %s keeps identity transform" % [lod, component])
			_check(instance.mesh is ArrayMesh and not instance.mesh is PrimitiveMesh, "LOD%d %s uses an imported ArrayMesh" % [lod, component])
			_check(instance.mesh.resource_path == expected_path and FileAccess.file_exists(expected_path), "LOD%d %s references its checked-in component OBJ" % [lod, component])
			_check(instance.custom_aabb.is_equal_approx(EXPECTED_BOUNDS), "LOD%d %s shares the synchronized whole-craft cull bounds" % [lod, component])
			_check(instance.visible and instance.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "LOD%d %s stays visible within its hard manual range without fade" % [lod, component])
			if lod == 0:
				_check(
					is_equal_approx(instance.visibility_range_end, 60.0)
					and is_equal_approx(instance.visibility_range_end_margin, 5.0)
					and is_zero_approx(instance.visibility_range_begin)
					and is_zero_approx(instance.visibility_range_begin_margin),
					"LOD0 %s owns the exact near range and handoff margin" % component
				)
			else:
				_check(
					is_equal_approx(instance.visibility_range_begin, 60.0)
					and is_equal_approx(instance.visibility_range_begin_margin, 5.0)
					and is_zero_approx(instance.visibility_range_end)
					and is_zero_approx(instance.visibility_range_end_margin),
					"LOD1 %s owns the exact far range and handoff margin" % component
				)
			var mesh_metrics := _validate_mesh(instance.mesh, "LOD%d %s" % [lod, component])
			vertex_count += int(mesh_metrics.vertex_count)
			triangle_count += int(mesh_metrics.triangle_count)
			surface_count += int(mesh_metrics.surface_count)
			var bounds := instance.get_aabb()
			combined = bounds if not has_bounds else combined.merge(bounds)
			has_bounds = true
		_check(combined.is_equal_approx(EXPECTED_BOUNDS), "LOD%d geometry preserves the exact normalized authored AABB" % lod)
		_check(combined.size.x / combined.size.z >= 0.85 and combined.size.x / combined.size.z <= 0.94, "LOD%d span-to-length ratio stays in the evidence-directed band" % lod)
		_check(combined.size.y / combined.size.z >= 0.53 and combined.size.y / combined.size.z <= 0.59, "LOD%d height-to-length ratio stays in the evidence-directed band" % lod)
		reports.append({"lod": lod, "vertices": vertex_count, "triangles": triangle_count, "surfaces": surface_count, "aabb": combined})
		var manifest_record := (_manifest.get("lods", []) as Array)[lod] as Dictionary
		_check(
			triangle_count == EXPECTED_LOD_TRIANGLES[lod]
			and triangle_count == int(manifest_record.get("triangle_count", -1)),
			"LOD%d live triangles exactly match its pinned authored manifest" % lod
		)
	_check(int(reports[0].triangles) >= 3000 and int(reports[0].triangles) <= 6000, "LOD0 meets the bounded 3000-6000 authored-detail target")
	_check(int(reports[1].triangles) <= floori(float(reports[0].triangles) * 0.25), "LOD1 is at most one quarter of LOD0 topology")
	_check(int(reports[1].triangles) < int(reports[0].triangles), "LOD1 has strictly fewer authored triangles than LOD0")
	_check(int(reports[1].vertices) < int(reports[0].vertices), "LOD1 has strictly fewer authored vertices than LOD0")
	return reports


func _validate_mesh(mesh: Mesh, label: String) -> Dictionary:
	var total_vertices := 0
	var total_triangles := 0
	_check(mesh.get_surface_count() > 0, "%s has at least one imported surface" % label)
	for surface_index in mesh.get_surface_count():
		_check(mesh.surface_get_primitive_type(surface_index) == Mesh.PRIMITIVE_TRIANGLES, "%s surface is triangulated" % label)
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		_check(not vertices.is_empty(), "%s surface contains vertices" % label)
		_check(normals.size() == vertices.size(), "%s has one authored/imported normal per vertex" % label)
		_check(tangents.size() == vertices.size() * 4, "%s importer supplies one tangent frame per UV-mapped vertex" % label)
		_check(uvs.size() == vertices.size(), "%s has one intentional UV per vertex" % label)
		_check(not indices.is_empty() and indices.size() % 3 == 0, "%s has indexed triangle topology" % label)
		var referenced := PackedByteArray()
		referenced.resize(vertices.size())
		var attributes_finite := true
		var normals_unit := true
		var uvs_in_domain := true
		for vertex_index in vertices.size():
			var vertex := vertices[vertex_index]
			var normal := normals[vertex_index]
			var uv := uvs[vertex_index]
			attributes_finite = attributes_finite and _finite_vector3(vertex) and _finite_vector3(normal) and _finite_vector2(uv)
			normals_unit = normals_unit and absf(normal.length() - 1.0) <= 0.02
			uvs_in_domain = uvs_in_domain and uv.x >= -0.00001 and uv.x <= 1.00001 and uv.y >= -0.00001 and uv.y <= 1.00001
		_check(attributes_finite, "%s vertex attributes are finite" % label)
		_check(normals_unit, "%s normals are unit length" % label)
		_check(uvs_in_domain, "%s UVs stay inside the non-tiled atlas domain" % label)
		var indices_in_range := true
		var distinct_indices := true
		var non_degenerate := true
		for triangle_start in range(0, indices.size(), 3):
			var a := indices[triangle_start]
			var b := indices[triangle_start + 1]
			var c := indices[triangle_start + 2]
			var in_range := a >= 0 and b >= 0 and c >= 0 and a < vertices.size() and b < vertices.size() and c < vertices.size()
			indices_in_range = indices_in_range and in_range
			if not in_range:
				continue
			referenced[a] = 1
			referenced[b] = 1
			referenced[c] = 1
			distinct_indices = distinct_indices and a != b and b != c and a != c
			non_degenerate = non_degenerate and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length_squared() > 0.000000000001
		_check(indices_in_range, "%s triangle indices stay in range" % label)
		_check(distinct_indices, "%s triangles have three distinct indices" % label)
		_check(non_degenerate, "%s triangles have non-zero area" % label)
		_check(not referenced.has(0), "%s has no unreferenced imported vertex" % label)
		total_vertices += vertices.size()
		total_triangles += indices.size() / 3
	return {"vertex_count": total_vertices, "triangle_count": total_triangles, "surface_count": mesh.get_surface_count()}


func _test_semantic_uv_atlas(presentation: TorrentAuthoredMacroform) -> void:
	var texture_contract := _manifest.get("texture_contract", {}) as Dictionary
	var layout := texture_contract.get("uv_layout", {}) as Dictionary
	var islands := layout.get("islands", []) as Array
	_check(
		str(texture_contract.get("mapping", "")) == "intentional_non_seamless_weighted_role_signed_axis_trim_v2"
		and str(texture_contract.get("source_kind", "")) == "image_derived_proxy_trim_atlas"
		and not bool(texture_contract.get("final_hand_authored_pbr", true))
		and str(texture_contract.get("production_usage", "")) == "selected_stepped_side_planes_only"
		and texture_contract.get("atlas_sampling_roles", []) == ATLAS_SAMPLING_ROLES
		and texture_contract.get("atlas_sampling_semantics", []) == ATLAS_SAMPLING_SEMANTICS,
		"material evidence labels the trim maps as an image-derived proxy rather than final hand-authored PBR"
	)
	_check(
		str(layout.get("layout_id", "")) == UV_LAYOUT_ID
		and layout.get("semantic_order", []) == EXPECTED_COMPONENTS
		and layout.get("role_order", []) == UV_ROLE_ORDER
		and layout.get("role_members", []) == UV_ROLE_MEMBERS
		and layout.get("signed_axis_order", []) == SIGNED_AXIS_ORDER
		and int(layout.get("columns", 0)) == UV_ATLAS_COLUMNS
		and int(layout.get("rows", 0)) == UV_ATLAS_ROWS
		and layout.get("column_weights", []) == UV_ATLAS_COLUMN_WEIGHTS
		and is_equal_approx(float(layout.get("outer_guard", -1.0)), UV_ATLAS_OUTER_GUARD)
		and is_equal_approx(float(layout.get("cell_gutter", -1.0)), UV_ATLAS_CELL_GUTTER)
		and is_equal_approx(float(layout.get("dominant_axis_tie_epsilon", -1.0)), UV_DOMINANT_AXIS_TIE_EPSILON)
		and str(layout.get("projection_normalization", "")) == "per_lod_semantic_signed_axis_local_bounds"
		and int(layout.get("island_count", 0)) == 36
		and islands.size() == 36
		and not bool(layout.get("cross_role_overlap", true))
		and bool(layout.get("intentional_within_role_reuse", false))
		and str(layout.get("cross_semantic_overlap", "")) == "within_declared_role_only"
		and not bool(layout.get("cross_signed_axis_overlap", true))
		and bool(layout.get("lods_share_layout", false)),
		"manifest exposes the exact guarded weighted-role/signed-axis trim layout"
	)

	var contract_rectangles: Array[Rect2] = []
	var island_records_exact := islands.size() == 36
	if island_records_exact:
		for role_index in UV_ROLE_ORDER.size():
			for axis_index in SIGNED_AXIS_ORDER.size():
				var record_index := role_index * SIGNED_AXIS_ORDER.size() + axis_index
				var record := islands[record_index] as Dictionary
				var minimum := _record_vector2(record.get("uv_min", []))
				var maximum := _record_vector2(record.get("uv_max", []))
				var actual := Rect2(minimum, maximum - minimum)
				var expected := _atlas_island_rect(role_index, axis_index)
				island_records_exact = (
					island_records_exact
					and str(record.get("role", "")) == UV_ROLE_ORDER[role_index]
					and record.get("members", []) == UV_ROLE_MEMBERS[role_index]
					and str(record.get("signed_axis", "")) == SIGNED_AXIS_ORDER[axis_index]
					and int(record.get("column", -1)) == role_index
					and int(record.get("row", -1)) == axis_index
					and actual.position.distance_to(expected.position) <= 0.00001
					and actual.end.distance_to(expected.end) <= 0.00001
				)
				contract_rectangles.append(actual)
	_check(island_records_exact, "all 36 manifest islands have their exact role membership, signed-axis, row, column, and guarded bounds")
	var islands_disjoint := contract_rectangles.size() == 36
	for first_index in contract_rectangles.size():
		for second_index in range(first_index + 1, contract_rectangles.size()):
			islands_disjoint = islands_disjoint and not contract_rectangles[first_index].intersects(contract_rectangles[second_index])
	_check(islands_disjoint, "all declared visual-role and signed-axis atlas islands are pairwise disjoint")

	for lod in 2:
		var lod_root := presentation.get_node("Dated2011Form/MacroformLOD%d" % lod) as Node3D
		for semantic_index in EXPECTED_COMPONENTS.size():
			var component := EXPECTED_COMPONENTS[semantic_index] as String
			var role_index := _uv_role_index(component)
			var instance := lod_root.get_node(component) as MeshInstance3D
			var object_record := _manifest_object_record(lod, component)
			var projection_bounds := _projection_bounds_from_record(object_record.get("uv_projection_bounds", []))
			var all_uvs_finite_and_in_domain := true
			var all_uvs_exact := true
			var live_bounds_exact := true
			var used_axes := PackedByteArray()
			used_axes.resize(SIGNED_AXIS_ORDER.size())
			var uv_count := 0
			for surface_index in instance.mesh.get_surface_count():
				var arrays := instance.mesh.surface_get_arrays(surface_index)
				var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
				var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
				live_bounds_exact = live_bounds_exact and _projection_bounds_match(_projection_bounds(vertices, normals), projection_bounds)
				for vertex_index in mini(vertices.size(), mini(normals.size(), uvs.size())):
					var uv := uvs[vertex_index]
					var axis_index := _signed_dominant_axis_index(normals[vertex_index])
					var island := _atlas_island_rect(role_index, axis_index)
					var expected_uv := _expected_atlas_uv(role_index, vertices[vertex_index], normals[vertex_index], projection_bounds)
					used_axes[axis_index] = 1
					uv_count += 1
					all_uvs_finite_and_in_domain = (
						all_uvs_finite_and_in_domain
						and _finite_vector2(uv)
						and uv.x >= 0.0 and uv.x <= 1.0
						and uv.y >= 0.0 and uv.y <= 1.0
						and uv.x >= island.position.x - UV_AUDIT_TOLERANCE
						and uv.y >= island.position.y - UV_AUDIT_TOLERANCE
						and uv.x <= island.end.x + UV_AUDIT_TOLERANCE
						and uv.y <= island.end.y + UV_AUDIT_TOLERANCE
					)
					all_uvs_exact = all_uvs_exact and uv.distance_to(expected_uv) <= UV_AUDIT_TOLERANCE
			_check(str(object_record.get("uv_role", "")) == UV_ROLE_ORDER[role_index], "LOD%d %s declares its exact visual UV role" % [lod, component])
			_check(uv_count > 0 and all_uvs_finite_and_in_domain, "LOD%d %s UVs are finite, in 0..1, and confined to their declared-role islands" % [lod, component])
			_check(projection_bounds.size() == 6 and live_bounds_exact, "LOD%d %s local projection bounds are complete and match the live imported geometry" % [lod, component])
			_check(all_uvs_exact, "LOD%d %s UVs exactly reproduce the semantic signed-axis projection" % [lod, component])
			_check(not used_axes.has(0), "LOD%d %s exercises all six signed-axis islands" % [lod, component])

	var audit := presentation.get_torrent_authored_asset_audit_report()
	var material_contract := audit.get("material_contract", {}) as Dictionary
	var audited_layout := material_contract.get("uv_layout", {}) as Dictionary
	_check(
		str(material_contract.get("mapping", "")) == "intentional_non_seamless_weighted_role_signed_axis_trim_v2"
		and str(material_contract.get("source_kind", "")) == "image_derived_proxy_trim_atlas"
		and not bool(material_contract.get("final_hand_authored_pbr", true))
		and str(material_contract.get("production_usage", "")) == "selected_stepped_side_planes_only"
		and material_contract.get("atlas_sampling_roles", []) == ATLAS_SAMPLING_ROLES
		and material_contract.get("atlas_sampling_semantics", []) == ATLAS_SAMPLING_SEMANTICS
		and int(audited_layout.get("island_count", 0)) == 36,
		"runtime audit publishes the exact selected-use proxy atlas and 36 role/orientation island boundary"
	)


func _expected_atlas_uv(
	role_index: int,
	point: Vector3,
	normal: Vector3,
	projection_bounds: Array[Rect2]
) -> Vector2:
	var axis_index := _signed_dominant_axis_index(normal)
	var projection := _dominant_axis_projection(point, axis_index)
	var bounds := projection_bounds[axis_index]
	var local := Vector2(
		(projection.x - bounds.position.x) / bounds.size.x,
		(projection.y - bounds.position.y) / bounds.size.y
	).clamp(Vector2.ZERO, Vector2.ONE)
	var island := _atlas_island_rect(role_index, axis_index)
	return island.position + local * island.size


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


func _projection_bounds_from_record(value: Variant) -> Array[Rect2]:
	var records := value as Array
	var bounds: Array[Rect2] = []
	if records.size() != SIGNED_AXIS_ORDER.size():
		return bounds
	for axis_index in SIGNED_AXIS_ORDER.size():
		var record := records[axis_index] as Dictionary
		var minimum := _record_vector2(record.get("projected_min", []))
		var maximum := _record_vector2(record.get("projected_max", []))
		if str(record.get("signed_axis", "")) != SIGNED_AXIS_ORDER[axis_index]:
			return []
		bounds.append(Rect2(minimum, maximum - minimum))
	return bounds


func _projection_bounds_match(actual: Array[Rect2], expected: Array[Rect2]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if actual[index].position.distance_to(expected[index].position) > UV_AUDIT_TOLERANCE or actual[index].end.distance_to(expected[index].end) > UV_AUDIT_TOLERANCE:
			return false
	return true


func _manifest_object_record(lod: int, component: String) -> Dictionary:
	var lods := _manifest.get("lods", []) as Array
	if lod < 0 or lod >= lods.size():
		return {}
	for value: Variant in (lods[lod] as Dictionary).get("objects", []):
		var record := value as Dictionary
		if str(record.get("name", "")) == component:
			return record
	return {}


func _uv_role_index(component: String) -> int:
	for role_index in UV_ROLE_MEMBERS.size():
		if component in UV_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _material_role_index(component: String) -> int:
	for role_index in MATERIAL_ROLE_MEMBERS.size():
		if component in MATERIAL_ROLE_MEMBERS[role_index]:
			return role_index
	return -1


func _material_textures(material: StandardMaterial3D) -> Array[Texture2D]:
	return [
		material.albedo_texture,
		material.metallic_texture,
		material.roughness_texture,
		material.normal_texture,
		material.ao_texture,
		material.emission_texture,
	]


func _material_has_no_textures(material: StandardMaterial3D) -> bool:
	return (
		not material.normal_enabled
		and not material.ao_enabled
		and not material.emission_enabled
		and not _material_textures(material).any(func(texture: Texture2D) -> bool: return texture != null)
	)


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


func _record_vector2(value: Variant) -> Vector2:
	var values := value as Array
	return Vector2(float(values[0]), float(values[1])) if values.size() == 2 else Vector2(-10.0, -10.0)


func _test_material_contract(presentation: TorrentAuthoredMacroform) -> void:
	var materials: Array[StandardMaterial3D] = [
		(presentation.get_node("Dated2011Form/MacroformLOD0/PortLowerSidePlane") as MeshInstance3D).material_override as StandardMaterial3D,
		(presentation.get_node("Dated2011Form/MacroformLOD0/PointedNose") as MeshInstance3D).material_override as StandardMaterial3D,
		(presentation.get_node("Dated2011Form/MacroformLOD0/PortAftCircularHousing") as MeshInstance3D).material_override as StandardMaterial3D,
	]
	_check(not materials.has(null), "all three production material roles resolve to StandardMaterial3D resources")
	if materials.has(null):
		return
	for role_index in MATERIAL_ROLE_ORDER.size():
		_check(materials[role_index].resource_path == EXPECTED_MATERIAL_PATHS[role_index], "%s retains its exact embedded resource identity" % MATERIAL_ROLE_ORDER[role_index])
	_check(materials[0] != materials[1] and materials[0] != materials[2] and materials[1] != materials[2], "three material roles use three distinct embedded resource identities")

	var atlas := materials[0]
	_check(atlas.albedo_texture != null and atlas.albedo_texture.resource_path == str(RUNTIME_TEXTURES.albedo[0]), "side-plane atlas role uses the 1024 runtime trim atlas")
	_check(atlas.normal_enabled and atlas.normal_texture != null and atlas.normal_texture.resource_path == str(RUNTIME_TEXTURES.normal[0]), "side-plane atlas role uses the registered tangent normal map")
	_check(atlas.roughness_texture != null and atlas.roughness_texture.resource_path == str(RUNTIME_TEXTURES.roughness[0]), "side-plane atlas role uses the registered separate roughness map")
	_check(atlas.ao_enabled and atlas.ao_texture != null and atlas.ao_texture.resource_path == str(RUNTIME_TEXTURES.orm[0]), "side-plane atlas role consumes the packed ORM red AO channel")
	_check(atlas.metallic_texture != null and atlas.metallic_texture.resource_path == str(RUNTIME_TEXTURES.orm[0]), "side-plane atlas role consumes the packed ORM blue metallic channel")
	_check(atlas.emission_enabled and atlas.emission_texture != null and atlas.emission_texture.resource_path == str(RUNTIME_TEXTURES.emissive[0]), "side-plane atlas role uses the bounded cyan emissive accent mask")
	_check(
		atlas.albedo_color == Color.WHITE
		and is_equal_approx(atlas.metallic, 1.0)
		and atlas.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		and is_equal_approx(atlas.roughness, 1.0)
		and atlas.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and is_equal_approx(atlas.normal_scale, 0.2)
		and is_equal_approx(atlas.ao_light_affect, 0.2)
		and atlas.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and atlas.emission == Color(0.35, 0.85, 0.9, 1.0)
		and is_equal_approx(atlas.emission_energy_multiplier, 0.18),
		"side-plane atlas role retains restrained normal response and packed-channel semantics"
	)
	_check(atlas.ao_texture == atlas.metallic_texture, "atlas AO and metallic consume one shared packed ORM resource")

	var ivory := materials[1]
	_check(
		ivory.albedo_color == Color(0.9, 0.88, 0.78, 1.0)
		and is_equal_approx(ivory.metallic, 0.08)
		and is_equal_approx(ivory.roughness, 0.58)
		and _material_has_no_textures(ivory),
		"warm-ivory role has the exact clean untextured response"
	)
	var graphite := materials[2]
	_check(
		graphite.albedo_color == Color(0.035, 0.055, 0.06, 1.0)
		and is_equal_approx(graphite.metallic, 0.28)
		and is_equal_approx(graphite.roughness, 0.42)
		and _material_has_no_textures(graphite),
		"restrained-graphite role has the exact clean untextured response"
	)
	for material: StandardMaterial3D in materials:
		_check(not material.uv1_triplanar and not material.texture_repeat, "each material role uses a non-repeating explicit UV policy")
		for texture: Texture2D in _material_textures(material):
			_check(texture == null or texture.resource_path != FORBIDDEN_FLAT_STUDY_TEXTURE, "no production material binds the flat-albedo study")

	var material_ids: Dictionary = {}
	for lod in 2:
		for component: String in EXPECTED_COMPONENTS:
			var instance := presentation.get_node("Dated2011Form/MacroformLOD%d/%s" % [lod, component]) as MeshInstance3D
			var role_index := _material_role_index(component)
			_check(role_index >= 0 and instance.material_override == materials[role_index], "LOD%d %s uses exact %s membership" % [lod, component, MATERIAL_ROLE_ORDER[role_index]])
			material_ids[instance.material_override.get_instance_id()] = true
	_check(material_ids.size() == 3, "the 26 semantic meshes resolve to exactly three canonical material identities")


func _test_collision_separation(presentation: TorrentAuthoredMacroform) -> void:
	for forbidden_type: String in ["CollisionObject3D", "CollisionShape3D", "CollisionPolygon3D", "Area3D"]:
		_check(presentation.find_children("*", forbidden_type, true, false).is_empty(), "presentation contains no %s gameplay authority" % forbidden_type)


func _test_audit_contract(presentation: TorrentAuthoredMacroform, live_metrics: Array[Dictionary]) -> void:
	var first := presentation.get_torrent_authored_asset_audit_report()
	var second := presentation.get_torrent_authored_asset_audit_report()
	if not bool(first.get("valid", false)):
		print("TORRENT_AUTHORED_AUDIT_DIAGNOSTIC: ", first.get("errors", PackedStringArray()))
	_check(bool(first.get("valid", false)) and (first.get("errors", PackedStringArray()) as PackedStringArray).is_empty(), "authored asset audit validates live imported resources")
	_check(int(first.get("schema_version", 0)) == 2, "runtime audit publishes schema v2 with exact UV-layout evidence")
	_check(str(first.get("asset_revision", "")) == "v2" and str(first.get("component_id", "")) == "torrent_authored_macroform_presentation_v2", "runtime audit identifies the bounded authored-relief revision")
	_check(str(first.get("scene_path", "")) == PRESENTATION_PATH, "runtime audit identifies the exact presentation PackedScene")
	_check(str(first.get("manifest_sha256", "")) == GOLDEN_MANIFEST_SHA256, "runtime audit echoes the pinned manifest hash")
	var resources := first.get("resource_contract", {}) as Dictionary
	_check(
		int(resources.get("visual_instance_count", 0)) == 26
		and int(resources.get("mesh_instance_count", 0)) == 26
		and int(resources.get("collision_node_count", -1)) == 0
		and not bool(resources.get("runtime_mesh_construction", true))
		and not bool(resources.get("shared_material", true))
		and int(resources.get("material_role_count", 0)) == 3
		and resources.get("material_role_order", []) == MATERIAL_ROLE_ORDER
		and resources.get("material_role_members", []) == MATERIAL_ROLE_MEMBERS,
		"runtime audit publishes the exact immutable 26-mesh, three-material, collision-free resource contract"
	)
	var material_contract := first.get("material_contract", {}) as Dictionary
	var roles := material_contract.get("roles", []) as Array
	_check(
		material_contract.get("material_role_order", []) == MATERIAL_ROLE_ORDER
		and material_contract.get("material_role_members", []) == MATERIAL_ROLE_MEMBERS
		and material_contract.get("material_paths", []) == EXPECTED_MATERIAL_PATHS
		and roles.size() == 3
		and not bool(material_contract.get("flat_study_bound", true)),
		"runtime audit exposes exact material-role membership, embedded identities, and no flat-study binding"
	)
	if roles.size() == 3:
		for role_index in MATERIAL_ROLE_ORDER.size():
			var role := roles[role_index] as Dictionary
			_check(
				str(role.get("role", "")) == MATERIAL_ROLE_ORDER[role_index]
				and role.get("members", []) == MATERIAL_ROLE_MEMBERS[role_index]
				and str(role.get("resource_path", "")) == EXPECTED_MATERIAL_PATHS[role_index],
				"runtime audit material role %s is exact" % MATERIAL_ROLE_ORDER[role_index]
			)
	_check(str(first.get("determinism_fingerprint", "")).length() == 64, "runtime audit publishes a SHA-256 determinism fingerprint")
	_check(first.get("determinism_fingerprint") == second.get("determinism_fingerprint"), "repeated audit calls have an identical fingerprint")
	var node_contract := first.get("node_contract", {}) as Dictionary
	_check(node_contract.get("lod_0") == NodePath("Dated2011Form/MacroformLOD0") and node_contract.get("lod_1") == NodePath("Dated2011Form/MacroformLOD1"), "audit publishes exact LOD handoff paths")
	for component: String in EXPECTED_COMPONENTS:
		_check(presentation.get_node_or_null(node_contract.get(component.to_snake_case(), NodePath())) is MeshInstance3D, "audit semantic path resolves: %s" % component)
	var peer := PRESENTATION_SCENE.instantiate() as TorrentAuthoredMacroform
	root.add_child(peer)
	var peer_audit := peer.get_torrent_authored_asset_audit_report()
	_check(peer_audit.get("determinism_fingerprint") == first.get("determinism_fingerprint"), "a peer scene instance has the same immutable fingerprint")
	peer.queue_free()
	var mutable_provenance := first.get("provenance", {}) as Dictionary
	mutable_provenance["identity_lock"] = "corrupted_by_caller"
	var fresh := presentation.get_torrent_authored_asset_audit_report()
	_check(str((fresh.get("provenance", {}) as Dictionary).get("identity_lock", "")) == "b5_observed_name_to_model", "caller mutation cannot alter a fresh nested audit report")
	presentation.set_meta("authenticated_exact_geometry", true)
	var fail_red := presentation.get_torrent_authored_asset_audit_report()
	_check(not bool(fail_red.get("valid", true)) and not (fail_red.get("errors", PackedStringArray()) as PackedStringArray).is_empty(), "live evidence-metadata drift makes the audit fail red")
	presentation.set_meta("authenticated_exact_geometry", false)
	_check(bool(presentation.get_torrent_authored_asset_audit_report().get("valid", false)), "restoring immutable evidence metadata returns the audit green")
	_check(live_metrics.size() == 2, "focused topology audit measured both LODs")


func _test_adversarial_runtime_audit(presentation: TorrentAuthoredMacroform) -> void:
	_check(_audit_is_green(presentation), "adversarial authored-asset fixture begins green")

	var original_transform := presentation.transform
	presentation.position += Vector3(0.1, 0.0, 0.0)
	_expect_fail_red(presentation, "root transform drift fails the authored asset audit red")
	presentation.transform = original_transform
	_expect_green(presentation, "restoring the root transform returns the audit green")
	presentation.visible = false
	_expect_fail_red(presentation, "hidden presentation root fails the authored asset audit red")
	presentation.visible = true
	_expect_green(presentation, "restoring root visibility returns the audit green")

	var target := presentation.get_node("Dated2011Form/MacroformLOD0/PointedNose") as MeshInstance3D
	target.visible = false
	_expect_fail_red(presentation, "hidden authored mesh fails the audit red")
	target.visible = true
	_expect_green(presentation, "restoring authored mesh visibility returns the audit green")
	var target_transform := target.transform
	target.position += Vector3(0.02, 0.0, 0.0)
	_expect_fail_red(presentation, "moved authored mesh fails the audit red")
	target.transform = target_transform
	_expect_green(presentation, "restoring authored mesh transform returns the audit green")
	var original_mesh := target.mesh
	target.mesh = BoxMesh.new()
	_expect_fail_red(presentation, "runtime primitive replacement fails the audit red")
	target.mesh = original_mesh
	_expect_green(presentation, "restoring the exact imported mesh resource returns the audit green")
	var imported_mesh := target.mesh as ArrayMesh
	var original_surface_arrays := imported_mesh.surface_get_arrays(0)
	var original_surface_material := imported_mesh.surface_get_material(0)
	var mutated_surface_arrays := original_surface_arrays.duplicate(true)
	var mutated_uvs := (mutated_surface_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
	mutated_uvs[0] = Vector2(0.999, 0.999)
	mutated_surface_arrays[Mesh.ARRAY_TEX_UV] = mutated_uvs
	imported_mesh.clear_surfaces()
	imported_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mutated_surface_arrays)
	imported_mesh.surface_set_material(0, original_surface_material)
	_expect_fail_red(presentation, "same-resource live UV mapping drift fails the exact atlas audit red")
	imported_mesh.clear_surfaces()
	imported_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original_surface_arrays)
	imported_mesh.surface_set_material(0, original_surface_material)
	_expect_green(presentation, "restoring the exact imported UV arrays returns the audit green")
	var original_custom_aabb := target.custom_aabb
	target.custom_aabb = target.custom_aabb.grow(0.2)
	_expect_fail_red(presentation, "custom cull-AABB drift fails the audit red")
	target.custom_aabb = original_custom_aabb
	_expect_green(presentation, "restoring the synchronized custom AABB returns the audit green")
	var original_range_end := target.visibility_range_end
	target.visibility_range_end = 58.0
	_expect_fail_red(presentation, "manual LOD handoff drift fails the audit red")
	target.visibility_range_end = original_range_end
	_expect_green(presentation, "restoring the exact LOD handoff returns the audit green")

	var original_role: Variant = target.get_meta("silhouette_role")
	target.set_meta("silhouette_role", &"generic_wedge")
	_expect_fail_red(presentation, "semantic source-role drift fails the audit red")
	target.set_meta("silhouette_role", original_role)
	_expect_green(presentation, "restoring semantic source metadata returns the audit green")

	var lod0 := target.get_parent()
	var original_index := target.get_index()
	lod0.remove_child(target)
	_expect_fail_red(presentation, "detached semantic mesh fails the exact hierarchy audit red")
	lod0.add_child(target)
	lod0.move_child(target, original_index)
	_expect_green(presentation, "reattaching the exact semantic mesh restores the audit green")

	var rogue := MeshInstance3D.new()
	rogue.name = "RogueAuthoredVisual"
	rogue.mesh = BoxMesh.new()
	presentation.add_child(rogue)
	_expect_fail_red(presentation, "rogue visual fails the exact 26-mesh audit red")
	presentation.remove_child(rogue)
	rogue.queue_free()
	_expect_green(presentation, "removing the rogue visual restores the exact roster")

	var material_target := presentation.get_node("Dated2011Form/MacroformLOD1/RaisedSpine") as MeshInstance3D
	var ivory_material := material_target.material_override as StandardMaterial3D
	material_target.material_override = ivory_material.duplicate(true)
	_expect_fail_red(presentation, "divergent per-mesh material identity fails the audit red")
	material_target.material_override = ivory_material
	_expect_green(presentation, "restoring canonical warm-ivory identity returns the audit green")
	var atlas_target := presentation.get_node("Dated2011Form/MacroformLOD0/PortLowerSidePlane") as MeshInstance3D
	var atlas_material := atlas_target.material_override as StandardMaterial3D
	var graphite_material := (presentation.get_node("Dated2011Form/MacroformLOD0/PortAftCircularHousing") as MeshInstance3D).material_override as StandardMaterial3D
	atlas_target.material_override = graphite_material
	_expect_fail_red(presentation, "cross-role material substitution fails exact semantic membership red")
	atlas_target.material_override = atlas_material
	_expect_green(presentation, "restoring side-plane atlas membership returns the audit green")
	var all_meshes := presentation.find_children("*", "MeshInstance3D", true, false)
	var original_materials: Array[Material] = []
	var cloned_ivory_material := ivory_material.duplicate(true) as StandardMaterial3D
	for candidate: Node in all_meshes:
		original_materials.append((candidate as MeshInstance3D).material_override)
		(candidate as MeshInstance3D).material_override = cloned_ivory_material
	_expect_fail_red(presentation, "whole-roster material replacement fails the exact resource audit red")
	for candidate_index in all_meshes.size():
		(all_meshes[candidate_index] as MeshInstance3D).material_override = original_materials[candidate_index]
	_expect_green(presentation, "restoring all three canonical embedded material identities returns the audit green")
	var original_roughness := ivory_material.roughness
	var pristine_material_fingerprint := str(presentation.get_torrent_authored_asset_audit_report().get("determinism_fingerprint", ""))
	ivory_material.roughness = 0.17
	_expect_fail_red(presentation, "live warm-ivory property drift fails the audit red")
	_check(
		str(presentation.get_torrent_authored_asset_audit_report().get("determinism_fingerprint", "")) != pristine_material_fingerprint,
		"determinism fingerprint incorporates live material-role properties"
	)
	ivory_material.roughness = original_roughness
	_expect_green(presentation, "restoring warm-ivory physical properties returns the audit green")
	var original_graphite_albedo := graphite_material.albedo_color
	graphite_material.albedo_color = Color.WHITE
	_expect_fail_red(presentation, "live graphite property drift fails the audit red")
	graphite_material.albedo_color = original_graphite_albedo
	_expect_green(presentation, "restoring graphite physical properties returns the audit green")
	var original_albedo := atlas_material.albedo_texture
	atlas_material.albedo_texture = atlas_material.normal_texture
	_expect_fail_red(presentation, "live atlas texture-resource drift fails the audit red")
	atlas_material.albedo_texture = original_albedo
	_expect_green(presentation, "restoring the exact atlas albedo resource returns the audit green")
	var flat_study := ResourceLoader.load(FORBIDDEN_FLAT_STUDY_TEXTURE) as Texture2D
	atlas_material.albedo_texture = flat_study
	_expect_fail_red(presentation, "binding the flat-albedo study fails the production material audit red")
	atlas_material.albedo_texture = original_albedo
	_expect_green(presentation, "removing the flat-albedo study binding returns the audit green")


func _test_production_delegation() -> void:
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_check(torrent != null, "production Torrent instantiates for authored-audit delegation")
	if torrent == null:
		return
	root.add_child(torrent)
	await process_frame
	var authored := torrent.find_child("TorrentAuthoredMacroform", true, false) as TorrentAuthoredMacroform
	var pristine := torrent.get_torrent_reconstruction_audit_report()
	_check(
		authored != null
		and _audit_is_green(authored)
		and bool(pristine.get("valid", false))
		and pristine.get("authored_mesh", {}) is Dictionary,
		"production HeroShip delegates to one green authored-mesh audit"
	)
	if authored != null:
		var target := authored.get_node("Dated2011Form/MacroformLOD0/RaisedSpine") as MeshInstance3D
		target.visible = false
		var authored_fail := authored.get_torrent_authored_asset_audit_report()
		var hero_fail := torrent.get_torrent_reconstruction_audit_report()
		_check(
			not bool(authored_fail.get("valid", true))
			and not bool(hero_fail.get("valid", true)),
			"HeroShip cannot fail open when its delegated authored presentation is corrupted"
		)
		target.visible = true
		_check(
			_audit_is_green(authored)
			and bool(torrent.get_torrent_reconstruction_audit_report().get("valid", false)),
			"restoring the production authored mesh returns both delegated audits green"
		)
	torrent.queue_free()
	await process_frame


func _audit_is_green(presentation: TorrentAuthoredMacroform) -> bool:
	var report := presentation.get_torrent_authored_asset_audit_report()
	return bool(report.get("valid", false)) and (report.get("errors", PackedStringArray()) as PackedStringArray).is_empty()


func _expect_fail_red(presentation: TorrentAuthoredMacroform, description: String) -> void:
	var report := presentation.get_torrent_authored_asset_audit_report()
	_check(
		not bool(report.get("valid", true))
		and not (report.get("errors", PackedStringArray()) as PackedStringArray).is_empty(),
		description
	)


func _expect_green(presentation: TorrentAuthoredMacroform, description: String) -> void:
	_check(_audit_is_green(presentation), description)


func _mesh_snapshot(presentation: Node) -> Dictionary:
	var snapshot := {}
	for candidate: Node in presentation.find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		snapshot[str(presentation.get_path_to(instance))] = instance.mesh.get_instance_id() if instance.mesh != null else 0
	return snapshot


func _hash(path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path))


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _unique_strings(values: Array[String]) -> Dictionary:
	var unique := {}
	for value: String in values:
		unique[value] = true
	return unique


func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_AUTHORED_ASSET_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("TORRENT_AUTHORED_ASSET_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
