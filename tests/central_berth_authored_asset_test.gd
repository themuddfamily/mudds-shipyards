extends SceneTree

## Focused source/import/runtime integrity audit for the Blender-authored
## central berth platform shell.  This scene is presentation-only and remains
## deliberately independent of the production world until integration.

const PRESENTATION_SCENE := preload("res://scenes/world/presentation/central_berth_hero_presentation.tscn")
const MANIFEST_PATH := "res://assets/models/station/central_berth_hero_v1_asset_manifest.json"
const GENERATOR_PATH := "res://tools/blender/generate_central_berth_hero_v1.py"
const BLEND_PATH := "res://art_source/station/central_berth_hero_v1.blend"
const GLB_PATH := "res://assets/models/station/central_berth_hero_v1.glb"
const REQUIRED_ROOTS := [
	"deck_panels", "edge_fascia", "primary_structure",
	"secondary_structure", "service_channels",
]
const MATERIAL_ROLES := [
	"DeckComposite", "EdgeIvory", "GuidanceCyan",
	"ServiceGraphite", "StructuralAlloy",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_source_and_manifest()
	var presentation := PRESENTATION_SCENE.instantiate() as CentralBerthHeroPresentation
	_check(presentation != null, "presentation wrapper instantiates")
	if presentation == null:
		_finish()
		return
	root.add_child(presentation)
	await process_frame
	_test_green_runtime_contract(presentation)
	await _test_structured_red_drift_cases(presentation)
	presentation.queue_free()
	await process_frame
	_finish()


func _test_source_and_manifest() -> void:
	_check(FileAccess.file_exists(GENERATOR_PATH), "deterministic Blender generator is checked in")
	_check(FileAccess.file_exists(BLEND_PATH), "editable central-berth Blend source is checked in")
	_check(FileAccess.file_exists(GLB_PATH), "runtime central-berth GLB is checked in")
	_check(FileAccess.file_exists(MANIFEST_PATH), "central-berth asset manifest is checked in")
	var manifest := _read_manifest()
	_check(int(manifest.get("schema_version", 0)) == 1, "manifest uses the frozen v1 schema")
	_check(str(manifest.get("asset_id", "")) == "mudds.station.central_berth_hero.v1", "manifest retains the central-berth asset ID")
	_check(
		str(manifest.get("authorship", "")) == "original_script_assisted_blender"
		and not bool(manifest.get("historical_geometry_authenticated", true)),
		"asset records original authorship without claiming recovered historical geometry"
	)
	_check(
		bool(manifest.get("presentation_only", false))
		and not bool(manifest.get("gameplay_authority", true))
		and not bool(manifest.get("collision_authority", true))
		and not bool(manifest.get("walking_surface_authority", true)),
		"manifest freezes the presentation-only authority boundary"
	)
	_check(PackedStringArray(manifest.get("semantic_roots", [])) == PackedStringArray(REQUIRED_ROOTS), "manifest publishes the five exact semantic roots")
	var manifest_roles := PackedStringArray((manifest.get("material_roles", {}) as Dictionary).keys())
	manifest_roles.sort()
	_check(manifest_roles == PackedStringArray(MATERIAL_ROLES), "manifest publishes the five exact material roles")
	_check(int(manifest.get("source_component_count", 0)) == 111, "editable Blend retains 111 authored components")
	var source_counts := manifest.get("source_component_counts_by_root", {}) as Dictionary
	_check(
		int(source_counts.get("deck_panels", 0)) == 19
		and int(source_counts.get("edge_fascia", 0)) == 24
		and int(source_counts.get("primary_structure", 0)) == 22
		and int(source_counts.get("secondary_structure", 0)) == 28
		and int(source_counts.get("service_channels", 0)) == 18,
		"editable component inventory remains deliberately layered and complete"
	)
	var batching := manifest.get("runtime_static_batching", {}) as Dictionary
	_check(
		str(batching.get("strategy", "")) == "per_semantic_root_per_material_static_join"
		and bool(batching.get("source_preserved_in_blend", false))
		and int(batching.get("runtime_mesh_instance_count", 0)) == 8
		and int(batching.get("runtime_mesh_instance_budget", 0)) == 12
		and int(batching.get("runtime_surface_budget", 0)) == 12,
		"runtime export collapses authored detail to eight bounded draw batches"
	)
	_check(
		int(manifest.get("mesh_vertices_exported_runtime", 0)) == 5976
		and int(manifest.get("mesh_triangles_exported_runtime", 0)) == 11508,
		"manifest freezes the first authored runtime topology"
	)
	var uv_contract := manifest.get("uv0_contract", {}) as Dictionary
	_check(
		str(uv_contract.get("method", "")) == "authored_component_uv0_preserved_through_static_join"
		and str(uv_contract.get("texture_coordinate", "")) == "UV0/TEXCOORD_0"
		and not bool(uv_contract.get("triplanar", true))
		and int(uv_contract.get("runtime_meshes_with_uv0", 0)) == 8
		and float(uv_contract.get("minimum_uv_axis_span", 0.0)) >= 0.75,
		"every runtime batch retains non-collapsed authored UV0"
	)
	var envelope := manifest.get("envelope_contract_godot_metres", {}) as Dictionary
	_check(
		_array_matches_vector3(envelope.get("minimum", []), Vector3(-12.75, -2.58, -27.75))
		and _array_matches_vector3(envelope.get("maximum", []), Vector3(12.75, 0.095, 7.75))
		and is_equal_approx(float(envelope.get("deck_top_y", -99.0)), 0.095)
		and bool(envelope.get("existing_pad_envelope_preserved", false))
		and bool(envelope.get("all_authored_form_at_or_below_deck_top", false)),
		"authored shell preserves the exact established pad envelope and top height"
	)
	_check(
		str(manifest.get("generator_sha256", "")) == FileAccess.get_sha256(GENERATOR_PATH)
		and str(manifest.get("blend_sha256", "")) == FileAccess.get_sha256(BLEND_PATH)
		and str(manifest.get("glb_sha256", "")) == FileAccess.get_sha256(GLB_PATH),
		"generator, editable Blend, and runtime GLB exactly match their checked-in hashes"
	)


func _test_green_runtime_contract(presentation: CentralBerthHeroPresentation) -> void:
	var audit := presentation.get_asset_audit_report()
	_check(bool(audit.get("valid", false)), "authored presentation audit is green: %s" % [audit.get("errors", [])])
	_check(
		bool(audit.get("presentation_only", false))
		and not bool(audit.get("gameplay_authority", true))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("walking_surface_authority", true))
		and int(audit.get("forbidden_authority_node_count", -1)) == 0,
		"live imported subtree contains no gameplay authority"
	)
	_check(
		PackedStringArray(audit.get("semantic_roots", [])) == PackedStringArray(REQUIRED_ROOTS)
		and int(audit.get("semantic_root_count", 0)) == 5
		and PackedStringArray(audit.get("material_roles", [])) == PackedStringArray(MATERIAL_ROLES)
		and int(audit.get("material_role_count", 0)) == 5,
		"live hierarchy retains all five roots and all five material roles"
	)
	_check(
		int(audit.get("runtime_mesh_count", 0)) == 8
		and int(audit.get("whole_wrapper_mesh_count", 0)) == 8
		and int(audit.get("runtime_surface_count", 0)) == 8
		and int(audit.get("runtime_triangle_count", 0)) == 11508
		and int(audit.get("runtime_mesh_budget", 0)) == 12
		and int(audit.get("runtime_surface_budget", 0)) == 12,
		"live runtime remains within its eight-draw 11,508-triangle budget"
	)
	_check(
		(audit.get("bounds_minimum", Vector3.INF) as Vector3).distance_to(Vector3(-12.75, -2.58, -27.75)) <= 0.002
		and (audit.get("bounds_maximum", Vector3.INF) as Vector3).distance_to(Vector3(12.75, 0.095, 7.75)) <= 0.002,
		"Godot import preserves the exact platform envelope and flush deck top"
	)
	var root_art := presentation.get_asset_root()
	_check(root_art != null and root_art.transform.is_equal_approx(Transform3D.IDENTITY), "imported art root mounts at identity")
	for root_name in REQUIRED_ROOTS:
		var semantic_root := presentation.get_semantic_root(StringName(root_name))
		_check(
			semantic_root != null
			and semantic_root.get_parent() == root_art
			and semantic_root.transform.is_equal_approx(Transform3D.IDENTITY),
			"semantic root is direct and identity-mounted: %s" % root_name
		)
	var deck_material := presentation.get_runtime_material(&"DeckComposite")
	_check(
		deck_material != null
		and deck_material.albedo_texture.resource_path == "res://assets/materials/shipyard-deck-albedo-v1.png"
		and deck_material.normal_enabled
		and deck_material.normal_texture.resource_path == "res://assets/materials/shipyard-deck-normal-v1.png"
		and is_equal_approx(deck_material.normal_scale, 0.42)
		and deck_material.roughness_texture.resource_path == "res://assets/materials/shipyard-deck-roughness-v1.png"
		and deck_material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED
		and not deck_material.uv1_triplanar,
		"DeckComposite binds the registered deck PBR maps through authored UV0"
	)
	var deck_meshes := presentation.get_semantic_root(&"deck_panels").find_children("*", "MeshInstance3D", true, false)
	_check(deck_meshes.size() == 1 and _mesh_has_uv0((deck_meshes[0] as MeshInstance3D).mesh), "batched deck skin retains non-collapsed runtime TEXCOORD_0")
	_check(
		is_equal_approx(presentation.get_runtime_material(&"EdgeIvory").metallic, 0.18)
		and is_equal_approx(presentation.get_runtime_material(&"StructuralAlloy").metallic, 0.72)
		and is_equal_approx(presentation.get_runtime_material(&"ServiceGraphite").roughness, 0.48)
		and presentation.get_runtime_material(&"GuidanceCyan").emission_enabled,
		"remaining material roles are physically distinct rather than one flat shader"
	)


func _test_structured_red_drift_cases(presentation: CentralBerthHeroPresentation) -> void:
	var deck_root := presentation.get_semantic_root(&"deck_panels")
	var root_art := presentation.get_asset_root()
	root_art.remove_child(deck_root)
	var missing_root := presentation.get_asset_audit_report()
	_check(
		not bool(missing_root.get("valid", true))
		and _errors_have(missing_root, "missing_semantic_root:deck_panels")
		and _errors_have(missing_root, "imported_node_roster_size_drift"),
		"detaching a protected semantic root returns structured red"
	)
	root_art.add_child(deck_root)
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring the protected root returns green")

	var original_root_transform := root_art.transform
	root_art.position.y += 0.25
	var transform_drift := presentation.get_asset_audit_report()
	_check(
		not bool(transform_drift.get("valid", true))
		and _errors_have(transform_drift, "asset_root_identity_or_transform_drift")
		and _errors_have(transform_drift, "imported_node_transform_authority_drift:."),
		"moving the imported shell returns structured transform-authority red"
	)
	root_art.transform = original_root_transform
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring the exact mount returns green")

	var deck_material := presentation.get_runtime_material(&"DeckComposite")
	var original_triplanar := deck_material.uv1_triplanar
	deck_material.uv1_triplanar = true
	var material_drift := presentation.get_asset_audit_report()
	_check(
		not bool(material_drift.get("valid", true))
		and _errors_have(material_drift, "deck_composite_uv0_pbr_map_binding_drift")
		and _errors_have(material_drift, "runtime_material_content_drift:DeckComposite"),
		"reintroducing triplanar mapping returns structured material red"
	)
	deck_material.uv1_triplanar = original_triplanar
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring authored UV0 material mapping returns green")

	var deck_mesh := deck_root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var original_mesh := deck_mesh.mesh
	deck_mesh.mesh = BoxMesh.new()
	var topology_drift := presentation.get_asset_audit_report()
	_check(
		not bool(topology_drift.get("valid", true))
		and _errors_have(topology_drift, "imported_mesh_topology_drift:"),
		"substituting one authored mesh returns structured topology red"
	)
	deck_mesh.mesh = original_mesh
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring the exact authored mesh returns green")

	var rogue_mesh := MeshInstance3D.new()
	rogue_mesh.name = "RogueVisualSibling"
	rogue_mesh.mesh = BoxMesh.new()
	presentation.add_child(rogue_mesh)
	var visual_roster_drift := presentation.get_asset_audit_report()
	_check(
		not bool(visual_roster_drift.get("valid", true))
		and _errors_have(visual_roster_drift, "presentation_adapter_child_roster_drift")
		and _errors_have(visual_roster_drift, "visual_mesh_exists_outside_authored_asset_root"),
		"adding a visual sibling outside the protected asset root returns structured red"
	)
	rogue_mesh.queue_free()
	await process_frame
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "removing rogue visual sibling restores green")

	var rogue_area := Area3D.new()
	rogue_area.name = "RogueGameplayAuthority"
	presentation.add_child(rogue_area)
	var authority_drift := presentation.get_asset_audit_report()
	_check(
		not bool(authority_drift.get("valid", true))
		and int(authority_drift.get("forbidden_authority_node_count", 0)) == 1
		and _errors_have(authority_drift, "visual_subtree_contains_gameplay_authority_nodes"),
		"adding gameplay authority beneath the wrapper returns structured red"
	)
	rogue_area.queue_free()
	await process_frame
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "removing rogue gameplay authority returns green")


func _read_manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _array_matches_vector3(value: Variant, expected: Vector3) -> bool:
	if not value is Array or (value as Array).size() != 3:
		return false
	var array := value as Array
	return Vector3(float(array[0]), float(array[1]), float(array[2])).distance_to(expected) <= 0.0001


func _mesh_has_uv0(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var uvs := mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	if uvs.is_empty():
		return false
	var minimum := Vector2.INF
	var maximum := -Vector2.INF
	for uv in uvs:
		minimum = minimum.min(uv)
		maximum = maximum.max(uv)
	return minimum.distance_to(maximum) > 0.1


func _errors_have(report: Dictionary, fragment: String) -> bool:
	for error in report.get("errors", PackedStringArray()) as PackedStringArray:
		if fragment in error:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if _failures.is_empty():
		print("CENTRAL_BERTH_AUTHORED_ASSET_TEST_PASS")
		quit(0)
	else:
		push_error("CENTRAL_BERTH_AUTHORED_ASSET_TEST_FAIL (%d): %s" % [_failures.size(), _failures])
		quit(1)
