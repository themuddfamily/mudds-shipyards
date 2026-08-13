extends SceneTree

const HERO_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const PRESENTATION_SCENE := preload(
	"res://scenes/ships/presentation/torrent_hero_presentation.tscn"
)
const MANIFEST_PATH := "res://assets/models/torrent/hero/torrent_hero_asset_manifest.json"

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as TorrentHeroPresentation
	root.add_child(presentation)
	await process_frame
	var audit := presentation.get_asset_audit_report()
	_check(bool(audit.get("valid", false)), "standalone Blender presentation passes its exact runtime audit")
	_check(str(audit.get("authorship", "")) == "original_script_assisted_blender", "asset reports honest Blender authorship")
	_check(not bool(audit.get("historical_geometry_authenticated", true)), "modern hero asset makes no authenticated historical-geometry claim")
	_check(not bool(audit.get("gameplay_authority", true)), "imported art explicitly owns no gameplay authority")
	_check(int(audit.get("lod0_triangle_count", 0)) == 63716 and int(audit.get("lod0_mesh_count", 999)) == 17, "LOD0 preserves its measured close topology inside the 18-node draw budget")
	_check(int(audit.get("lod1_triangle_count", 0)) == 8036 and int(audit.get("lod1_mesh_count", 999)) == 5, "LOD1 preserves its complete silhouette at the exact five-node budget")
	_check(int(audit.get("total_mesh_count", 999)) == 32 and int(audit.get("near_surface_count", 999)) == 27 and int(audit.get("far_surface_count", 999)) == 5, "runtime presentation owns the measured 27-near/5-far surface contract")
	var root_art := presentation.get_asset_root()
	_check(root_art != null and root_art.name == &"TorrentHeroArt", "imported hierarchy publishes one stable hero root")
	for child_name in [&"LOD0", &"LOD1", &"CockpitArt", &"CanopyPivot", &"SemanticAnchors"]:
		_check(root_art != null and root_art.get_node_or_null(NodePath(String(child_name))) != null, "hero root exposes %s" % child_name)
	var forbidden := 0
	for type_name in ["CollisionObject3D", "CollisionShape3D", "Area3D", "Camera3D", "AudioStreamPlayer3D", "AnimationPlayer"]:
		forbidden += presentation.find_children("*", type_name, true, false).size()
	_check(forbidden == 0, "imported visual subtree contains no collision, camera, audio, or animation authority")
	_check(int(audit.get("forbidden_authority_node_count", -1)) == 0, "runtime audit independently rejects imported gameplay authority")
	_check(int(audit.get("runtime_material_role_count", 0)) == 10, "runtime presentation owns the exact ten-role PBR material bank")
	_check(str(audit.get("hull_texture_coordinate", "")) == "UV0/TEXCOORD_0" and not bool(audit.get("hull_triplanar", true)), "runtime hull material contract uses authored UV0 rather than triplanar projection")
	_check(bool(audit.get("far_lod_unbounded", false)), "atomic mid/far LOD remains unbounded without a disappearing-ship hole")
	_check(
		str(audit.get("glb_hash_verification_mode", "")) == "raw_source_file_sha256"
		and bool(audit.get("raw_source_glb_hash_checked", false))
		and bool(audit.get("raw_source_glb_hash_verified", false)),
		"source checkout audits the physical authored GLB hash rather than an imported-resource remap"
	)
	_check(_runtime_uses_only_authored_whole_ship_lods(root_art), "Godot importer keeps every per-surface auto-LOD table empty so switching remains whole-ship atomic")
	presentation.update_lod_for_distance(1000.0)
	_check(presentation.get_active_lod() == 1 and not presentation.get_lod0_root().visible and presentation.get_lod1_root().visible, "far distance atomically switches the complete craft to unbounded LOD1")
	presentation.update_lod_for_distance(0.0)
	_check(presentation.get_active_lod() == 0 and presentation.get_lod0_root().visible and not presentation.get_lod1_root().visible, "near distance atomically restores the complete close craft")
	var manifest := _read_json(MANIFEST_PATH)
	_check(not manifest.is_empty() and int(manifest.get("schema_version", 0)) == 1, "checked-in asset manifest parses with stable schema")
	_check(str(manifest.get("blender_version", "")).begins_with("4.0.2"), "manifest pins the actual Blender 4.0.2 tool")
	var runtime_triangles := int(manifest.get("mesh_triangles_exported_runtime", 0))
	var batching := manifest.get("runtime_static_batching", {}) as Dictionary
	var source_counts := batching.get("source_mesh_counts_by_root", {}) as Dictionary
	var runtime_counts := batching.get("runtime_mesh_counts_by_root", {}) as Dictionary
	_check(str(batching.get("strategy", "")) == "per_semantic_root_per_material_static_join" and bool(batching.get("source_preserved_in_blend", false)), "manifest records export-only per-semantic-root/material batching while preserving the editable source")
	_check(int(batching.get("source_mesh_count_total", 0)) == 317 and _mesh_counts_match(source_counts, {"CanopyPivot": 22, "CockpitArt": 39, "LOD0": 238, "LOD1": 18, "SemanticAnchors": 0}), "manifest pins the complete 317-mesh editable semantic roster")
	_check(int(batching.get("runtime_mesh_count_total", 999)) == 32 and _mesh_counts_match(runtime_counts, {"CanopyPivot": 3, "CockpitArt": 7, "LOD0": 17, "LOD1": 5, "SemanticAnchors": 0}), "export-only batching reduces art to the exact 32-node runtime roster")
	_check(runtime_triangles == 87392, "runtime GLB carries the measured 87,392-triangle production topology")
	_check(runtime_triangles == int(manifest.get("mesh_triangles_evaluated_in_blender", -1)), "runtime GLB geometry exactly matches Blender's evaluated triangle count")
	_check(_runtime_triangle_count(root_art) == runtime_triangles, "Godot's imported runtime meshes contain the exact manifest-pinned triangle count")
	_check(str(manifest.get("glb_sha256", "")) == FileAccess.get_sha256("res://assets/models/torrent/hero/torrent_hero_art.glb"), "manifest pins the exact runtime GLB hash")
	_check(str(manifest.get("blend_sha256", "")) == FileAccess.get_sha256("res://art_source/torrent/torrent_hero_v1.blend"), "manifest pins the exact editable Blender source")
	var art_quality := manifest.get("art_quality_contract", {}) as Dictionary
	_check(int(art_quality.get("close_triangle_count", 0)) == 79356 and int(art_quality.get("far_triangle_count", 0)) == 8036 and int(art_quality.get("total_triangle_count", 0)) == 87392, "manifest separates close cabin/canopy density from the complete far silhouette")
	_check(float(art_quality.get("pale_exterior_surface_ratio", 0.0)) >= 0.70 and float(art_quality.get("pale_exterior_surface_ratio", 1.0)) <= 0.80, "measured exterior surface area preserves the intended 70-80% warm pale palette")
	_check(int(art_quality.get("propulsion_depth_layers", 0)) == 4 and int(art_quality.get("engine_stator_vanes_per_nacelle", 0)) == 8, "art contract records four propulsion depth layers and eight stator vanes per nacelle")
	var uv_contract := manifest.get("uv0_contract", {}) as Dictionary
	_check(bool(uv_contract.get("all_source_meshes_mapped", false)) and int(uv_contract.get("mesh_count", 0)) == 317 and int(uv_contract.get("degenerate_polygon_count", -1)) == 0, "every editable mesh owns finite non-degenerate UV0 before batching")
	_check(
		str(uv_contract.get("method", "")) == "dominant_root_normal_axis_sign_corrected_projection_v3"
		and str(uv_contract.get("editable_source_handedness", "")) == "negative"
		and str(uv_contract.get("runtime_glTF_handedness", "")) == "positive_after_Blender_V_conversion"
		and str(uv_contract.get("projection_axis_tie_policy", "")) == "lowest_root_axis_index"
		and int(uv_contract.get("fallback_polygon_count", -1)) == 4
		and int(uv_contract.get("reflected_polygon_count", 0)) > 4000
		and (uv_contract.get("projection_axis_polygon_counts", {}) as Dictionary).size() == 3,
		"editable UV0 uses canonical root-normal box projection, corrects its sign, and accounts for Blender's glTF V conversion"
	)
	_check(_all_runtime_meshes_have_meaningful_uv0(root_art), "every imported runtime surface retains non-collapsed TEXCOORD_0 data")
	var uv_orientation := manifest.get("uv_orientation_contract", {}) as Dictionary
	var textured_orientation := uv_orientation.get("textured_materials", {}) as Dictionary
	_check(
		str(uv_orientation.get("method", "")) == "indexed_triangle_geometric_normal_uv_determinant_v1"
		and bool(uv_orientation.get("glTF_export_v_conversion_accounted_for", false))
		and int(textured_orientation.get("triangle_count", 0)) == 15120
		and int(textured_orientation.get("degenerate_triangle_count", -1)) == 0
		and float(textured_orientation.get("mirrored_surface_ratio", 1.0)) <= 0.00002,
		"actual GLB keeps all 15,120 textured hull triangles in one UV orientation apart from bounded float32 bevel slivers"
	)
	var live_uv_orientation := _runtime_textured_uv_orientation(root_art)
	_check(
		int(live_uv_orientation.get("triangle_count", 0)) == 15120
		and int(live_uv_orientation.get("degenerate_triangle_count", -1)) == 0
		and float(live_uv_orientation.get("mirrored_surface_ratio", 1.0)) <= 0.00002,
		"Godot's imported textured hull arrays preserve the measured non-mirrored GLB tangent-frame orientation"
	)
	var plate_winding := manifest.get("swept_plate_winding_contract", {}) as Dictionary
	_check(
		bool(plate_winding.get("all_positive_outward_winding", false))
		and int(plate_winding.get("expected_object_count", 0)) == 16
		and float(plate_winding.get("minimum_signed_volume_m3", 0.0)) > 0.585
		and (plate_winding.get("signed_volume_m3_by_object", {}) as Dictionary).size() == 16,
		"all sixteen close/far swept plates publish positive signed volume and outward winding on both sides"
	)
	_check(_hull_runtime_materials_use_registered_maps(root_art), "both pale runtime material families bind the registered albedo/normal/roughness maps through UV0")
	var texture_contract := manifest.get("material_texture_contract", {}) as Dictionary
	_check(str(texture_contract.get("texture_coordinate", "")) == "UV0/TEXCOORD_0" and not bool(texture_contract.get("triplanar", true)), "manifest and live material agree on the UV0 texture-coordinate authority")
	_check(_source_art_rosters_are_complete(manifest), "editable source publishes the shaped cockpit, canopy, propulsion, gear, panel, and livery feature rosters")
	var collision_art := manifest.get("collision_art_alignment", {}) as Dictionary
	_check(bool(collision_art.get("valid", false)) and int(collision_art.get("box_order", []).size()) == 7 and is_equal_approx(float(collision_art.get("tolerance_m", 0.0)), 0.02), "manifest retains the exact external seven-box/two-centimetre collision contract")
	_check(int(collision_art.get("excluded_object_count", 0)) == 10 and int(collision_art.get("vertices_over_tolerance", -1)) == 0 and float(collision_art.get("maximum_uncovered_distance_m", 1.0)) <= 0.02, "all close solid art is covered with only the frozen ten non-contact effects excluded")
	var expected_anchors := {
		"PilotSeatAnchor": Vector3(0.0, 1.56, -0.02),
		"BoardingEntry": Vector3(-1.42, 2.32, 0.18),
		"BoardingPoint": Vector3(-3.2, 0.05, 0.65),
		"LeftMuzzle": Vector3(-2.82, 0.42, -3.42),
		"RightMuzzle": Vector3(2.82, 0.42, -3.42),
	}
	for anchor_name: String in expected_anchors:
		var anchor := presentation.get_semantic_anchor(StringName(anchor_name))
		_check(anchor != null and anchor.position.distance_to(expected_anchors[anchor_name]) <= 0.002, "%s is a precise non-authoritative alignment witness" % anchor_name)
	for clamp_name in [
		"PortMainGearClampJawForward", "PortMainGearClampJawAft",
		"StarboardMainGearClampJawForward", "StarboardMainGearClampJawAft",
		"NoseGearCaptureClamp",
	]:
		_check(root_art != null and root_art.find_child(clamp_name, true, false) is MeshInstance3D, "%s is authored close-range capture hardware" % clamp_name)
	_check(root_art != null and root_art.find_child("AmberUnknownFunctionPanel", true, false) is MeshInstance3D, "the source-supported unknown-function panel retains its exact runtime identity")
	var plume_names := PackedStringArray()
	for plume in presentation.get_engine_plumes():
		plume_names.append(String(plume.name))
	plume_names.sort()
	_check(plume_names == PackedStringArray(["LOD1PortEnginePlume", "LOD1StarboardEnginePlume", "PortEnginePlume", "StarboardEnginePlume"]), "runtime publishes the exact two close and two far plume identities")
	var core_names := PackedStringArray()
	for core in presentation.get_engine_cores():
		core_names.append(String(core.name))
	core_names.sort()
	_check(core_names == PackedStringArray(["PortEngineCore", "StarboardEngineCore"]), "runtime publishes the exact paired close engine-core identities")
	var detached_plume := root_art.find_child("PortEnginePlume", true, false) as MeshInstance3D
	var detached_plume_parent := detached_plume.get_parent() if detached_plume != null else null
	if detached_plume_parent != null:
		detached_plume_parent.remove_child(detached_plume)
	var missing_plume_audit := presentation.get_asset_audit_report()
	_check(not bool(missing_plume_audit.get("valid", true)) and not (missing_plume_audit.get("errors", PackedStringArray()) as PackedStringArray).is_empty() and presentation.get_engine_plumes().size() == 3, "detaching one protected plume returns a structured-red audit without a fail-open roster")
	if detached_plume_parent != null and detached_plume != null:
		detached_plume_parent.add_child(detached_plume)
	_check(bool(presentation.get_asset_audit_report().get("valid", false)) and presentation.get_engine_plumes().size() == 4, "restoring the same protected plume identity returns the immutable presentation audit green")

	var hero := HERO_SCENE.instantiate() as HeroShip
	root.add_child(hero)
	await process_frame
	var hero_audit := hero.get_torrent_art_audit_report()
	_check(bool(hero_audit.get("valid", false)), "production Torrent delegates to close art and far-fallback audits")
	_check(
		bool(hero_audit.get("gameplay_authority_unchanged", false))
		and bool(hero_audit.get("collision_authority_unchanged", false))
		and bool(hero_audit.get("functional_authority_unchanged", false)),
		"production audit preserves collision, boarding, seat, camera, exit, and weapon authority outside imported art"
	)
	var collision_names := PackedStringArray([
		"HullCollision", "WingCollision", "UpperSilhouetteCollision",
		"PortAftPropulsionCollision", "StarboardAftPropulsionCollision",
		"LowerGearCollision", "NoseGearCollision",
	])
	var exact_collision_roster := true
	for collision_name in collision_names:
		exact_collision_roster = exact_collision_roster and hero.get_node_or_null(collision_name) is CollisionShape3D
	_check(exact_collision_roster, "canonical seven-shape gameplay collision remains external to imported art")
	_check(hero.get_node_or_null("TorrentVisual/TorrentHeroPresentation") is TorrentHeroPresentation, "production Torrent owns exactly one close presentation adapter")
	_check(hero.get_node_or_null("TorrentVisual/LegacyFarPresentation/TorrentAuthoredMacroform") != null, "trusted dated macroform remains available as far/fallback art")
	_check(hero.get_node_or_null("TorrentVisual/LegacyFarPresentation/ModernSystems") != null, "legacy systems remain isolated in the fallback gate")
	_check(hero.find_child("CockpitArt", true, false) != null and hero.get_node_or_null("TorrentVisual/CanopyHinge") != null, "audited Blender cockpit and functional canopy roots coexist without duplicate art")
	_check(not (hero.get_node("TorrentVisual/CockpitInterior/LegacyCockpitArt") as Node3D).visible and not (hero.get_node("TorrentVisual/CanopyHinge/LegacyCanopyArt") as Node3D).visible, "legacy close meshes are hidden instead of double-rendered")
	for functional_path in [
		^"LeftMuzzle", ^"RightMuzzle", ^"BoardingPoint", ^"ExitPoint",
		^"TorrentVisual/CockpitInterior/PilotSeatAnchor",
		^"TorrentVisual/CockpitInterior/BoardingEntry",
		^"TorrentVisual/CockpitInterior/CockpitCamera",
	]:
		var functional_node := hero.get_node(functional_path) as Node3D
		var original_transform := functional_node.transform
		functional_node.position += Vector3(100.0, 200.0, 300.0)
		var drift_report := hero.get_torrent_art_audit_report()
		_check(
			not bool(drift_report.get("valid", true))
			and not bool(drift_report.get("functional_authority_unchanged", true))
			and not bool(drift_report.get("gameplay_authority_unchanged", true)),
			"functional authority drift fails the combined audit red: %s" % functional_path
		)
		functional_node.transform = original_transform
		_check(bool(hero.get_torrent_art_audit_report().get("valid", false)), "restoring functional authority returns the combined audit green: %s" % functional_path)
	var before_ids := _presentation_ids(hero)
	hero.remove_child(hero.get_node("TorrentVisual"))
	# Restore immediately; the adapter must be persistent data, not runtime rebuilt.
	var detached_visual := before_ids.get("visual") as Node3D
	hero.add_child(detached_visual)
	await process_frame
	_check(_presentation_ids(hero).get("hero") == before_ids.get("hero"), "ordinary visual detach/re-add preserves the imported hero instance")

	hero.queue_free()
	presentation.queue_free()
	await process_frame
	_finish()


func _all_runtime_meshes_have_meaningful_uv0(asset_root: Node3D) -> bool:
	if asset_root == null:
		return false
	for candidate in asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh == null:
			return false
		for surface_index in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
				return false
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			if uvs.size() != vertices.size() or uvs.size() < 3:
				return false
			var unique_uvs := {}
			for uv in uvs:
				if not uv.is_finite():
					return false
				unique_uvs[Vector2(snappedf(uv.x, 0.000001), snappedf(uv.y, 0.000001))] = true
			if unique_uvs.size() < 3:
				return false
	return true


func _runtime_textured_uv_orientation(asset_root: Node3D) -> Dictionary:
	var triangle_count := 0
	var degenerate_triangle_count := 0
	var mirrored_surface_area := 0.0
	var surface_area := 0.0
	for candidate in asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var role := StringName(mesh_instance.get_meta("torrent_material_role", &""))
		if role not in [&"WarmIvoryHull", &"IvorySecondary"]:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if normals.size() != vertices.size() or uvs.size() != vertices.size():
				return {}
			var element_count := indices.size() if not indices.is_empty() else vertices.size()
			if element_count % 3 != 0:
				return {}
			for element in range(0, element_count, 3):
				var i0 := indices[element] if not indices.is_empty() else element
				var i1 := indices[element + 1] if not indices.is_empty() else element + 1
				var i2 := indices[element + 2] if not indices.is_empty() else element + 2
				var geometry_cross := (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
				var area := geometry_cross.length() * 0.5
				var uv_a := uvs[i1] - uvs[i0]
				var uv_b := uvs[i2] - uvs[i0]
				var uv_determinant := uv_a.x * uv_b.y - uv_a.y * uv_b.x
				var handedness := geometry_cross.dot(normals[i0] + normals[i1] + normals[i2]) * uv_determinant
				triangle_count += 1
				surface_area += area
				if area <= 0.000000000001 or absf(uv_determinant) <= 0.000000000001 or absf(handedness) <= 0.000000000000001:
					degenerate_triangle_count += 1
				elif handedness < 0.0:
					mirrored_surface_area += area
	return {
		"triangle_count": triangle_count,
		"degenerate_triangle_count": degenerate_triangle_count,
		"mirrored_surface_ratio": mirrored_surface_area / surface_area if surface_area > 0.0 else 1.0,
	}


func _mesh_counts_match(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key: String in expected:
		if int(actual.get(key, -1)) != int(expected[key]):
			return false
	return true


func _hull_runtime_materials_use_registered_maps(asset_root: Node3D) -> bool:
	if asset_root == null:
		return false
	var role_counts := {&"WarmIvoryHull": 0, &"IvorySecondary": 0}
	for candidate in asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var role := StringName(mesh_instance.get_meta("torrent_material_role", &""))
		if role not in role_counts:
			continue
		role_counts[role] += 1
		var material := mesh_instance.material_override as StandardMaterial3D
		if (
			material == null
			or material.albedo_texture == null
			or material.albedo_texture.resource_path != "res://assets/materials/torrent-hull-albedo-v1.png"
			or not material.normal_enabled
			or material.normal_texture == null
			or material.normal_texture.resource_path != "res://assets/materials/torrent-hull-normal-v1.png"
			or material.roughness_texture == null
			or material.roughness_texture.resource_path != "res://assets/materials/torrent-hull-roughness-v1.png"
			or material.uv1_triplanar
			or not material.uv1_scale.is_equal_approx(Vector3.ONE)
		):
			return false
	return int(role_counts[&"WarmIvoryHull"]) == 2 and int(role_counts[&"IvorySecondary"]) == 3


func _source_art_rosters_are_complete(manifest: Dictionary) -> bool:
	var collections := manifest.get("collections", {}) as Dictionary
	var lod0 := PackedStringArray(collections.get("LOD0", []))
	var cockpit := PackedStringArray(collections.get("CockpitArt", []))
	var canopy := PackedStringArray(collections.get("CanopyPivot", []))
	var required_lod0 := PackedStringArray([
		"DorsalCrimsonLivery", "PortPlaneRootShadows", "StarboardPlaneRootShadows",
		"PortPlaneLiveryStrip1", "StarboardPlaneLiveryStrip4",
		"PortAftCircularHousing", "PortEngineOuterCollar", "PortEngineNozzle",
		"PortEngineThermalLip", "PortEngineHub", "PortEngineStatorVane07",
		"StarboardAftCircularHousing", "StarboardEngineOuterCollar",
		"StarboardEngineNozzle", "StarboardEngineThermalLip",
		"StarboardEngineHub", "StarboardEngineStatorVane07",
		"AftMachineryRecess", "AftBayFrameTop", "AftBayConduit03",
		"PortMainGearUpperPivot", "PortMainGearOleoSleeve",
		"PortMainGearTrailingBrace", "PortMainGearForkForward",
		"PortMainGearAnkle", "PortMainGearHydraulicLine",
		"StarboardMainGearUpperPivot", "StarboardMainGearOleoSleeve",
		"StarboardMainGearTrailingBrace", "StarboardMainGearForkAft",
		"StarboardMainGearAnkle", "StarboardMainGearHydraulicLine",
		"NoseGearUpperPivot", "NoseGearOleoSleeve", "NoseGearTrailingBrace",
		"NoseGearForkPort", "NoseGearForkStarboard", "NoseGearAnkle",
		"NoseGearHydraulicLine", "PortHullFastener00", "StarboardHullFastener08",
	])
	var required_cockpit := PackedStringArray([
		"CrimsonSeatPan", "CrimsonSeatBack", "SeatHeadrest",
		"PortSeatBolster", "StarboardSeatBolster", "PortShoulderHarness",
		"StarboardShoulderHarness", "HarnessBuckle", "InstrumentBinnacle",
		"PrimaryDisplay", "PortStatusDisplay", "StarboardStatusDisplay",
		"PortConsoleKeyCluster", "StarboardConsoleKeyCluster",
		"PortConsoleRotary0", "StarboardConsoleRotary1", "ControlStick",
		"ControlStickGrip", "ThrottleLever", "ThrottleGrip",
		"PortRudderPedal", "StarboardRudderPedal",
	])
	var required_canopy := PackedStringArray([
		"CanopyGlass", "CanopyForwardFrame", "CanopyTopSpine", "CanopyRearFrame",
		"PortCanopySill", "StarboardCanopySill", "PortCanopySideRail",
		"StarboardCanopySideRail", "PortCanopySeal", "StarboardCanopySeal",
		"PortCanopyHinge", "StarboardCanopyHinge", "CanopyHingeBar",
		"PortCanopyLatch", "StarboardCanopyLatch", "PortCanopyStriker",
		"StarboardCanopyStriker",
	])
	for name in required_lod0:
		if name not in lod0:
			return false
	for name in required_cockpit:
		if name not in cockpit:
			return false
	for name in required_canopy:
		if name not in canopy:
			return false
	return true


func _presentation_ids(hero: HeroShip) -> Dictionary:
	var visual := hero.get_variant_visual_root()
	var adapter := visual.get_node_or_null("TorrentHeroPresentation") as TorrentHeroPresentation
	return {
		"visual": visual,
		"hero": adapter.get_asset_root().get_instance_id() if adapter != null and adapter.get_asset_root() != null else 0,
	}


func _runtime_triangle_count(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			var element_count: int = indices.size() if indices != null and indices.size() > 0 else vertices.size()
			total += element_count / 3
	return total


func _runtime_uses_only_authored_whole_ship_lods(node: Node) -> bool:
	if node == null:
		return false
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var array_mesh := mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
		if array_mesh == null:
			continue
		var serialized_surfaces: Array = array_mesh.get("_surfaces")
		for surface_value: Variant in serialized_surfaces:
			var surface: Dictionary = surface_value if surface_value is Dictionary else {}
			var internal_lods: Array = surface.get("lods", [])
			if not internal_lods.is_empty():
				return false
	return true


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value as Dictionary if value is Dictionary else {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_BLENDER_HERO_ASSET_TEST_OK: %d assertions" % _assertions)
		quit()
	else:
		print("TORRENT_BLENDER_HERO_ASSET_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
