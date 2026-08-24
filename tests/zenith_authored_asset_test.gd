extends SceneTree

const PRESENTATION_SCENE := preload(
	"res://scenes/ships/presentation/zenith_authored_presentation.tscn"
)
const MANIFEST_PATH := "res://assets/models/zenith/zenith_authored_asset_manifest.json"
const GLB_PATH := "res://assets/models/zenith/zenith_authored_art.glb"
const BLEND_PATH := "res://art_source/zenith/zenith_authored_v1.blend"
const EXPECTED_COLLISION_SHAPES := {
	"CenterWingRoot": "ConvexPolygonShape3D",
	"PortMainWing": "ConvexPolygonShape3D",
	"StarboardMainWing": "ConvexPolygonShape3D",
	"PortLongStrake": "ConvexPolygonShape3D",
	"PortSpineShoulder": "ConvexPolygonShape3D",
	"PortObservedPod": "ConvexPolygonShape3D",
	"PortIndexedFin": "ConvexPolygonShape3D",
	"StarboardLongStrake": "ConvexPolygonShape3D",
	"StarboardSpineShoulder": "ConvexPolygonShape3D",
	"StarboardObservedPod": "ConvexPolygonShape3D",
	"StarboardIndexedFin": "ConvexPolygonShape3D",
	"CentralWedgeRaised20mm": "ConvexPolygonShape3D",
	"PortEngineHull": "ConvexPolygonShape3D",
	"PortCannonHull": "ConvexPolygonShape3D",
	"PortMainGearStrut": "CylinderShape3D",
	"PortMainGearFoot": "BoxShape3D",
	"StarboardEngineHull": "ConvexPolygonShape3D",
	"StarboardCannonHull": "ConvexPolygonShape3D",
	"StarboardMainGearStrut": "CylinderShape3D",
	"StarboardMainGearFoot": "BoxShape3D",
	"PairedMainGearDoorRelief": "ConvexPolygonShape3D",
	"NoseGearStrut": "CylinderShape3D",
	"NoseGearFoot": "BoxShape3D",
	"DockingHull": "ConvexPolygonShape3D",
}
const EXPECTED_COLLISION_GEOMETRY_SHA256 := "7717ba624158dca52c71dc271e13663436b9b9bf52658972f92fbc9e4482c273"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as ZenithAuthoredPresentation
	root.add_child(presentation)
	await process_frame

	var audit := presentation.get_asset_audit_report()
	_check(bool(audit.get("valid", false)), "Zenith authored presentation passes its complete live audit")
	_check(
		str(audit.get("asset_id", "")) == "mudds.ship.zenith.b7_authored.v1"
		and str(audit.get("evidence_scope", "")) == "B7_frames_373_467_only"
		and str(audit.get("authorship", "")) == "original_script_assisted_blender"
		and not bool(audit.get("historical_geometry_authenticated", true)),
		"asset publishes the exact bounded authorship and B7 evidence contract"
	)
	_check(
		bool(audit.get("presentation_only", false))
		and not bool(audit.get("gameplay_authority", true))
		and not bool(audit.get("collision_authority", true))
		and int(audit.get("forbidden_authority_node_count", -1)) == 0,
		"imported art owns no gameplay, collision, camera, animation, or audio authority"
	)
	_check(
		bool(audit.get("collision_proposal_ready", false))
		and int(audit.get("collision_proposal_shape_count", 0)) == 24
		and float(audit.get("collision_proposal_maximum_miss_m", INF)) <= .020
		and float(audit.get("collision_proposal_reverse_bound_m", INF)) <= .150
		and float(audit.get("boarding_capsule_clearance_m", 0.0)) >= .05
		and float(audit.get("boarding_collision_clearance_m", 0.0)) >= .05
		and bool(audit.get("boarding_route_clear", false))
		and float(audit.get("boarding_route_clearance_m", 0.0)) >= .05
		and (audit.get("boarding_area_center", Vector3.INF) as Vector3).distance_to(
			Vector3(-7.65, -.05, .55)
		) <= .0001,
		"wrapper publishes the ready non-authoritative 24-shape two-way and production-route proposal"
	)
	_check(
		int(audit.get("close_triangle_count", 0)) == 47_274
		and int(audit.get("far_triangle_count", 0)) == 5_412,
		"whole-ship close/far art stays inside the exact measured 47,274/5,412 triangle contract"
	)
	_check(
		int(audit.get("runtime_mesh_count", 999)) == 22
		and int(audit.get("runtime_surface_count", 999)) == 22
		and int(audit.get("runtime_mesh_budget", 0)) == 30
		and int(audit.get("runtime_surface_budget", 0)) == 30,
		"runtime export holds twenty-two draw surfaces beneath the thirty-surface budget"
	)
	_check(
		(audit.get("bounds_minimum", Vector3.INF) as Vector3).distance_to(
			Vector3(-7.20, -1.05, -5.35)
		) <= 0.002
		and (audit.get("bounds_maximum", Vector3.INF) as Vector3).distance_to(
			Vector3(7.20, 3.20, 5.30)
		) <= 0.002,
		"visual envelope preserves the frozen 14.4m-wide single-seat normalization"
	)

	var asset_root := presentation.get_asset_root()
	var source_core := presentation.get_source_core_root()
	var modern_systems := presentation.get_modern_systems_root()
	_check(
		asset_root != null
		and asset_root.name == &"ZenithAuthoredArt"
		and _direct_child_names(asset_root) == PackedStringArray(["ModernSystems", "SourceCore"]),
		"imported art publishes only the exact SourceCore/ModernSystems root split"
	)
	_check(
		source_core != null
		and source_core.get_parent() == asset_root
		and _direct_child_names(source_core) == PackedStringArray(["LOD0", "LOD1"])
		and modern_systems != null
		and modern_systems.get_parent() == asset_root
		and _direct_child_names(modern_systems) == PackedStringArray([
			"CanopyPivot", "LOD0", "LOD1", "SemanticAnchors",
		]),
		"both removable siblings expose their exact direct-child hierarchy"
	)
	_check(
		bool(audit.get("source_core_removable", false))
		and bool(audit.get("modern_systems_removable", false)),
		"audit independently confirms the source/modern boundary is structurally removable"
	)
	_check(
		_source_core_uses_only_observed_material_roles(source_core)
		and _modern_systems_uses_only_modern_material_roles(modern_systems),
		"source-supported macroform cannot absorb a modern functional material role"
	)
	var engine_graphite := presentation.get_runtime_material(&"EngineGraphite")
	_check(
		engine_graphite != null
		and engine_graphite.albedo_color.v >= .15
		and is_equal_approx(engine_graphite.roughness, .52)
		and is_equal_approx(engine_graphite.metallic, .46),
		"engine graphite is materially lifted and roughened for readable modern engine separation"
	)

	# RE-FROZEN 2026-08-15 alongside tests/zenith_interceptor_test.gd: the seat
	# anchor moved 1.58 -> 1.11 (feet-frame marker, not cushion height) and the
	# cockpit camera 2.28/-1.24 -> 2.87/-0.80 (fleet seat + 1.76 m eye point,
	# held inside the modern canopy dome). Modern ergonomics only; the B7
	# source-core macroform and its evidence scope are unchanged.
	var expected_anchors := {
		&"PilotSeatAnchor": Vector3(0.0, 1.11, -0.55),
		&"BoardingEntry": Vector3(-1.18, 1.62, -0.32),
		&"BoardingPoint": Vector3(-7.65, -0.55, 0.55),
		&"ExitPoint": Vector3(-7.85, -0.55, 0.85),
		&"LeftMuzzle": Vector3(-1.25, 0.34, -4.25),
		&"RightMuzzle": Vector3(1.25, 0.34, -4.25),
		&"CockpitCamera": Vector3(0.0, 2.87, -0.80),
		&"DockingReceiver": Vector3(0.0, -0.82, 1.05),
		&"DamageCenter": Vector3(0.0, 0.48, 0.0),
		&"DamagePortWing": Vector3(-4.55, 0.18, 0.20),
		&"DamageStarboardWing": Vector3(4.55, 0.18, 0.20),
		&"PortEnginePlume": Vector3(-2.20, 0.38, 4.95),
		&"StarboardEnginePlume": Vector3(2.20, 0.38, 4.95),
	}
	for anchor_name: StringName in expected_anchors:
		var anchor := presentation.get_semantic_anchor(anchor_name)
		_check(
			anchor != null and anchor.position.distance_to(expected_anchors[anchor_name]) <= 0.002,
			"%s is an exact non-authoritative modern alignment witness" % anchor_name
		)

	_check(_runtime_meshes_have_uv0_and_unit_normals(asset_root), "every imported surface retains UV0 and unit normals")
	var far_port_nav := asset_root.get_node_or_null(
		^"ModernSystems/LOD1/ModernSystemsLOD1StaticBatch_PortNavRed"
	) as MeshInstance3D
	var far_starboard_nav := asset_root.get_node_or_null(
		^"ModernSystems/LOD1/ModernSystemsLOD1StaticBatch_StarboardNavGreen"
	) as MeshInstance3D
	_check(
		far_port_nav != null and far_starboard_nav != null
		and far_port_nav.mesh == far_starboard_nav.mesh
		and far_port_nav.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(-7.08, 0.28, 0.88))
		)
		and far_starboard_nav.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, Vector3(7.08, 0.28, 0.88))
		)
		and far_port_nav.material_override == presentation.get_runtime_material(&"PortNavRed")
		and far_starboard_nav.material_override == presentation.get_runtime_material(&"StarboardNavGreen")
		and far_port_nav.material_override != far_starboard_nav.material_override,
		"far navigation lights share one immutable mesh while retaining exact copies, transforms, and port/starboard materials"
	)
	_check(_runtime_has_no_per_surface_lods(asset_root), "import sidecar disables every per-surface auto-LOD table")
	_check(
		bool(audit.get("whole_ship_lod_atomic", false))
		and bool(audit.get("far_lod_unbounded", false)),
		"wrapper advertises one atomic whole-ship handoff and an unbounded far silhouette"
	)
	presentation.update_lod_for_distance(1000.0)
	_check(
		presentation.get_active_lod() == 1
		and _all_visible(presentation.get_lod1_roots())
		and _all_hidden(presentation.get_lod0_roots())
		and not presentation.get_canopy_pivot().visible,
		"far distance atomically switches both source and modern roots to LOD1"
	)
	presentation.update_lod_for_distance(0.0)
	_check(
		presentation.get_active_lod() == 0
		and _all_visible(presentation.get_lod0_roots())
		and _all_hidden(presentation.get_lod1_roots())
		and presentation.get_canopy_pivot().visible,
		"near distance atomically restores complete LOD0 plus articulated canopy"
	)

	var plume_names := PackedStringArray()
	for plume in presentation.get_engine_plumes():
		plume_names.append(String(plume.name))
	plume_names.sort()
	_check(
		plume_names == PackedStringArray([
			"LOD1PortEnginePlume", "LOD1StarboardEnginePlume",
			"PortEnginePlume", "StarboardEnginePlume",
		]),
		"runtime publishes the exact two close/two far protected plume identities"
	)
	var close_plume := asset_root.find_child("PortEnginePlume", true, false) as MeshInstance3D
	var plume_scale := close_plume.scale
	var plume_visible := close_plume.visible
	close_plume.scale = Vector3(1.18, 1.18, 1.42)
	close_plume.visible = false
	_check(
		bool(presentation.get_asset_audit_report().get("valid", false)),
		"protected plume visibility and finite nonnegative local scale remain runtime-mutable"
	)
	close_plume.scale = plume_scale
	close_plume.visible = plume_visible

	presentation.set_canopy_fraction(0.65)
	var supported_canopy_transform := presentation.get_canopy_pivot().transform
	_check(
		bool(presentation.get_asset_audit_report().get("valid", false))
		and is_equal_approx(presentation.get_canopy_pivot().rotation.x, deg_to_rad(63.0) * 0.65),
		"public canopy hook permits only the bounded modern hinge articulation"
	)
	presentation.get_canopy_pivot().rotation.y += 0.1
	_check(
		not bool(presentation.get_asset_audit_report().get("valid", true)),
		"unsupported canopy-axis mutation fails the live integrity audit red"
	)
	presentation.get_canopy_pivot().transform = supported_canopy_transform
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring supported canopy pose returns green")
	presentation.set_canopy_fraction(0.0)

	var detached_parent := modern_systems.get_parent()
	detached_parent.remove_child(modern_systems)
	_check(
		source_core.get_parent() == asset_root
		and source_core.find_children("*", "MeshInstance3D", true, false).size() == 4,
		"removing ModernSystems leaves the complete four-batch source-supported close/far macroform"
	)
	asset_root.add_child(modern_systems)
	_check(bool(presentation.get_asset_audit_report().get("valid", false)), "restoring exact ModernSystems sibling returns green")

	var manifest := _read_json(MANIFEST_PATH)
	var evidence := manifest.get("evidence_source", {}) as Dictionary
	var boundary := manifest.get("interpretation_boundary", {}) as Dictionary
	var collision := manifest.get("collision_proposal", {}) as Dictionary
	var pod_contract := manifest.get("pod_like_form_contract", {}) as Dictionary
	var canopy_contract := manifest.get("canopy_contract", {}) as Dictionary
	var pattern_contract := manifest.get("removed_surface_pattern_contract", {}) as Dictionary
	var included_frames := evidence.get("included_frames_zero_based", []) as Array
	_check(
		str(evidence.get("ledger_id", "")) == "B7"
		and included_frames.size() == 2
		and int(included_frames[0]) == 373
		and int(included_frames[1]) == 467
		and int(evidence.get("excluded_from_frame_zero_based", 0)) == 468
		and not bool(evidence.get("source_pixels_or_geometry_redistributed", true)),
		"manifest includes only B7 frames 373-467 and explicitly excludes frame 468 onward/source pixels"
	)
	_check(
		bool(boundary.get("modern_systems_removable", false))
		and bool(boundary.get("source_core_complete_without_modern_systems", false))
		and (boundary.get("SourceCore", []) as Array).size() == 6
		and (boundary.get("ModernSystems", []) as Array).size() == 7,
		"manifest records the exact six supported and seven modern-only feature families"
	)
	_check(
		_collision_contract_matches_oracle(collision),
		"manifest matches the independent hard-coded 24-shape type/geometry/purpose oracle"
	)
	var structural_collision := collision.get("structural_art_coverage", {}) as Dictionary
	var reverse_collision := collision.get("reverse_fit", {}) as Dictionary
	var exclusion_names := PackedStringArray()
	for exclusion_value: Variant in collision.get("non_solid_exclusions", []):
		var exclusion := exclusion_value as Dictionary
		exclusion_names.append(str(exclusion.get("name", "")))
	exclusion_names.sort()
	var trim_names := PackedStringArray()
	for trim_value: Variant in collision.get("non_contact_decorative_trim", []):
		var trim := trim_value as Dictionary
		trim_names.append(str(trim.get("name", "")))
	trim_names.sort()
	_check(
		int(structural_collision.get("included_object_count", -1)) == 65
		and int(structural_collision.get("audited_vertex_count", -1)) == 19_378
		and int(structural_collision.get("vertices_over_20mm", -1)) == 0
		and float(structural_collision.get("maximum_observed_miss_m", INF)) <= .020
		and float(reverse_collision.get("conservative_continuous_upper_bound_m", INF)) <= .150
		and int(reverse_collision.get("tested_cell_count", 0)) > 0
		and str(reverse_collision.get("exposure_method", "")) == "cell_hidden_only_when_all_three_original_and_1mm_outward_vertices_are_inside_one_same_convex_shape"
		and exclusion_names == PackedStringArray([
			"CanopyGlassShell", "PortEnginePlume", "PortNavigationLight",
			"StarboardEnginePlume", "StarboardNavigationLight",
		])
		and trim_names == _expected_non_contact_trim_names(),
		"two-way collision fit covers structural art, bounds exposed overreach, and separates five non-solids from nineteen named trim pieces"
	)
	var cannon_attachment := collision.get("cannon_attachment", {}) as Dictionary
	_check(
		cannon_attachment.size() == 4
		and _all_cannon_parts_attached(cannon_attachment),
		"both barrel/shroud pairs contact SourceCore within 20mm and muzzle anchors sit at their visible tips"
	)
	var capsule := collision.get("production_boarding_capsule", {}) as Dictionary
	var marker_collision := capsule.get("collision_marker_witness", {}) as Dictionary
	var boarding_route := collision.get("boarding_route", {}) as Dictionary
	var grounding_sweep := boarding_route.get("vertical_grounding_sweep", {}) as Dictionary
	var grounded_walk := boarding_route.get("grounded_walk_sweep", {}) as Dictionary
	var boarding_area := collision.get("boarding_area_witness", {}) as Dictionary
	_check(
		_array_to_vector3(capsule.get("root_position", [])) == Vector3(-7.65, -.55, .55)
		and _array_to_vector3(capsule.get("center_offset", [])) == Vector3(0.0, .97, 0.0)
		and _array_to_vector3(capsule.get("center_position", [])) == Vector3(-7.65, .42, .55)
		and is_equal_approx(float(capsule.get("radius", 0.0)), .38)
		and is_equal_approx(float(capsule.get("total_height", 0.0)), 1.94)
		and int(capsule.get("art_axis_sample_count", 0)) == 1001
		and float(capsule.get("conservative_art_clearance_m", 0.0)) >= .05
		and float(marker_collision.get("conservative_continuous_clearance_m", 0.0)) >= .05
		and bool(boarding_route.get("clear", false))
		and _array_to_vector3(boarding_route.get("initial_root_position", [])) == Vector3(-7.65, -.50, 4.75)
		and _array_to_vector3(boarding_route.get("grounded_root_position", [])) == Vector3(-7.65, -1.08, 4.75)
		and _array_to_vector3(boarding_route.get("grounded_end_root_position", [])) == Vector3(-7.65, -1.08, .55)
		and is_equal_approx(float(grounding_sweep.get("route_axis_absolute_dot", -1.0)), 1.0)
		and is_zero_approx(float(grounded_walk.get("route_axis_absolute_dot", -1.0)))
		and float(grounding_sweep.get("conservative_continuous_clearance_m", 0.0)) >= .05
		and float(grounded_walk.get("conservative_continuous_clearance_m", 0.0)) >= .05
		and _array_to_vector3(boarding_area.get("center", [])) == Vector3(-7.65, -.05, .55)
		and is_equal_approx(float(boarding_area.get("radius", 0.0)), 4.5)
		and float(boarding_area.get("collision_center_clearance_m", 0.0)) > 0.0,
		"port apron validates exact production capsule semantics, grounding/walk sweeps, marker, and 4.5m area witness"
	)
	var pod_records := pod_contract.get("source_object_records", []) as Array
	_check(
		bool(pod_contract.get("historical_function_unresolved", false))
		and bool(pod_contract.get("count_placement_function_unauthenticated", false))
		and bool(pod_contract.get("aggregate_evidence_survives_runtime_batching", false))
		and pod_records.size() == 4
		and _all_pod_records_publish_uncertainty(pod_records)
		and int(audit.get("pod_like_form_count", 0)) == 4
		and bool(audit.get("pod_historical_function_unresolved", false)),
		"all four editable pod records and their batched wrapper aggregate retain explicit historical uncertainty"
	)
	_check(
		int(pattern_contract.get("removed_lod0_source_surface_cell_count", -1)) == 28
		and int(pattern_contract.get("removed_lod1_silhouette_cell_count", -1)) == 24
		and asset_root.find_child("*SourceSurfaceCell*", true, false) == null
		and asset_root.find_child("*SilhouetteCell*", true, false) == null,
		"square surface-cell patterns are absent and stepped bands carry the authored rhythm"
	)
	_check(
		int(canopy_contract.get("glass_source_triangle_count", 99999)) == 1974
		and int(canopy_contract.get("superseded_glass_triangle_count", 0)) == 9310
		and (canopy_contract.get("frame_object_names", []) as Array).size() == 5
		and bool(canopy_contract.get("readable_coaming", false)),
		"canopy glass is reduced by over seventy-five percent and gains five readable frame/coaming elements"
	)
	_check(
		str(manifest.get("glb_sha256", "")) == FileAccess.get_sha256(GLB_PATH)
		and str(manifest.get("blend_sha256", "")) == FileAccess.get_sha256(BLEND_PATH)
		and bool(audit.get("raw_source_glb_hash_verified", false)),
		"manifest and live audit pin the physical checked-in GLB and editable Blender source"
	)
	var maps := audit.get("hull_maps", {}) as Dictionary
	_check(
		str(audit.get("hull_texture_coordinate", "")) == "UV0/TEXCOORD_0"
		and not bool(audit.get("hull_triplanar", true))
		and str(maps.get("albedo", "")) == "res://assets/materials/torrent-hull-albedo-v1.png"
		and str(maps.get("normal", "")) == "res://assets/materials/torrent-hull-normal-v1.png"
		and str(maps.get("roughness", "")) == "res://assets/materials/torrent-hull-roughness-v1.png",
		"pale source shell reuses registered fleet PBR maps through authored UV0"
	)

	presentation.queue_free()
	await process_frame
	_finish()


func _source_core_uses_only_observed_material_roles(source_core: Node3D) -> bool:
	if source_core == null:
		return false
	for candidate in source_core.find_children("*", "MeshInstance3D", true, false):
		if StringName((candidate as MeshInstance3D).get_meta("zenith_material_role", &"")) not in [
			&"PaleCeramicHull", &"PaleFacetSecondary",
		]:
			return false
	return true


func _modern_systems_uses_only_modern_material_roles(modern_systems: Node3D) -> bool:
	if modern_systems == null:
		return false
	var allowed := [
		&"GraphitePanel", &"EngineGraphite", &"ExposedAlloy", &"CanopyGlass", &"EngineEmission",
		&"PortNavRed", &"StarboardNavGreen", &"CockpitEmission",
	]
	for candidate in modern_systems.find_children("*", "MeshInstance3D", true, false):
		if StringName((candidate as MeshInstance3D).get_meta("zenith_material_role", &"")) not in allowed:
			return false
	return true


func _collision_contract_matches_oracle(collision: Dictionary) -> bool:
	if (
		bool(collision.get("authority", true))
		or bool(collision.get("collision_authority", true))
		or int(collision.get("shape_count", -1)) != EXPECTED_COLLISION_SHAPES.size()
		or int(collision.get("maximum_shape_count", -1)) != 24
		or str(collision.get("shape_geometry_sha256", "")) != EXPECTED_COLLISION_GEOMETRY_SHA256
		or (collision.get("shapes", []) as Array).size() != EXPECTED_COLLISION_SHAPES.size()
	):
		return false
	var observed := {}
	for shape_value: Variant in collision.get("shapes", []):
		var shape := shape_value as Dictionary
		observed[str(shape.get("name", ""))] = shape
	if observed.size() != EXPECTED_COLLISION_SHAPES.size():
		return false
	for shape_name: String in EXPECTED_COLLISION_SHAPES:
		if not observed.has(shape_name):
			return false
		var actual := observed[shape_name] as Dictionary
		if (
			str(actual.get("shape_type", "")) != str(EXPECTED_COLLISION_SHAPES[shape_name])
			or str(actual.get("purpose", "")).is_empty()
			or bool(actual.get("authority", true))
			or str(actual.get("provenance", "")).is_empty()
			or (actual.get("source_object_names", []) as Array).is_empty()
		):
			return false
		if str(actual.get("shape_type", "")) == "ConvexPolygonShape3D":
			if (
				int(actual.get("point_count", 0)) < 4
				or (actual.get("points", []) as Array).size() != int(actual.get("point_count", -1))
				or str(actual.get("points_sha256", "")).length() != 64
			):
				return false
	var type_counts := collision.get("shape_type_counts", {}) as Dictionary
	if (
		int(type_counts.get("ConvexPolygonShape3D", -1)) != 18
		or int(type_counts.get("CylinderShape3D", -1)) != 3
		or int(type_counts.get("BoxShape3D", -1)) != 3
	):
		return false
	for cylinder_name in ["PortMainGearStrut", "StarboardMainGearStrut", "NoseGearStrut"]:
		var cylinder := observed[cylinder_name] as Dictionary
		if _array_to_vector3(cylinder.get("rotation_degrees", [])).distance_to(Vector3.ZERO) > .00001:
			return false
	var port_strut := observed["PortMainGearStrut"] as Dictionary
	var starboard_strut := observed["StarboardMainGearStrut"] as Dictionary
	var nose_strut := observed["NoseGearStrut"] as Dictionary
	if (
		_array_to_vector3(port_strut.get("position", [])) != Vector3(-2.55, -.30, 1.25)
		or _array_to_vector3(starboard_strut.get("position", [])) != Vector3(2.55, -.30, 1.25)
		or not is_equal_approx(float(port_strut.get("radius", 0.0)), .10)
		or not is_equal_approx(float(starboard_strut.get("radius", 0.0)), .10)
		or not is_equal_approx(float(port_strut.get("height", 0.0)), 1.18)
		or not is_equal_approx(float(starboard_strut.get("height", 0.0)), 1.18)
		or _array_to_vector3(nose_strut.get("position", [])) != Vector3(0.0, -.34, -2.82)
		or not is_equal_approx(float(nose_strut.get("radius", 0.0)), .09)
		or not is_equal_approx(float(nose_strut.get("height", 0.0)), 1.08)
	):
		return false
	return true


func _expected_non_contact_trim_names() -> PackedStringArray:
	var names := PackedStringArray([
		"CanopyAftHoop", "CanopyCentreFrame", "CanopyForwardHoop",
		"CanopyPortSill", "CanopyStarboardSill",
	])
	for side in ["Port", "Starboard"]:
		for index in range(1, 8):
			names.append("%sSteppedSubdivision%02d" % [side, index])
	names.sort()
	return names


func _all_pod_records_publish_uncertainty(records: Array) -> bool:
	var names := PackedStringArray()
	for record_value: Variant in records:
		var record := record_value as Dictionary
		if (
			not bool(record.get("historical_function_unresolved", false))
			or not bool(record.get("count_placement_function_unauthenticated", false))
			or str(record.get("evidence_claim", "")) != "cautiously_indexed_pod_like_form_only"
		):
			return false
		names.append(str(record.get("name", "")))
	names.sort()
	return names == PackedStringArray([
		"LOD1PortPodForm", "LOD1StarboardPodForm",
		"PortObservedPodLikeForm", "StarboardObservedPodLikeForm",
	])


func _all_cannon_parts_attached(attachment: Dictionary) -> bool:
	for cannon_name in [
		"PortCannonBarrel", "PortCannonShroud",
		"StarboardCannonBarrel", "StarboardCannonShroud",
	]:
		var record := attachment.get(cannon_name, {}) as Dictionary
		if (
			not bool(record.get("attached", false))
			or float(record.get("minimum_distance_to_source_solid_m", INF)) > .020
		):
			return false
	return true


func _array_to_vector3(value: Variant) -> Vector3:
	if value is not Array or (value as Array).size() != 3:
		return Vector3.INF
	var array := value as Array
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


func _runtime_meshes_have_uv0_and_unit_normals(asset_root: Node3D) -> bool:
	if asset_root == null:
		return false
	for candidate in asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh == null:
			return false
		for surface_index in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			if vertices.is_empty() or normals.size() != vertices.size() or uvs.size() != vertices.size():
				return false
			var unique_uvs := {}
			for index in vertices.size():
				if not normals[index].is_finite() or absf(normals[index].length() - 1.0) > 0.001:
					return false
				if not uvs[index].is_finite():
					return false
				unique_uvs[Vector2(snappedf(uvs[index].x, .000001), snappedf(uvs[index].y, .000001))] = true
			if unique_uvs.size() < 3:
				return false
	return true


func _runtime_has_no_per_surface_lods(asset_root: Node3D) -> bool:
	if asset_root == null:
		return false
	for candidate in asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh as ArrayMesh
		if mesh == null:
			return false
		for surface_value: Variant in mesh.get("_surfaces"):
			if surface_value is Dictionary and not (surface_value as Dictionary).get("lods", {}).is_empty():
				return false
	return true


func _all_visible(nodes: Array[Node3D]) -> bool:
	return nodes.size() == 2 and nodes[0].visible and nodes[1].visible


func _all_hidden(nodes: Array[Node3D]) -> bool:
	return nodes.size() == 2 and not nodes[0].visible and not nodes[1].visible


func _direct_child_names(node: Node) -> PackedStringArray:
	var names := PackedStringArray()
	for child in node.get_children():
		names.append(String(child.name))
	names.sort()
	return names


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_AUTHORED_ASSET_TEST_OK assertions=", _assertions)
		quit(0)
		return
	push_error("ZENITH_AUTHORED_ASSET_TEST_FAILED assertions=%d failures=%d" % [
		_assertions, _failures.size(),
	])
	for failure in _failures:
		push_error(" - %s" % failure)
	quit(1)
