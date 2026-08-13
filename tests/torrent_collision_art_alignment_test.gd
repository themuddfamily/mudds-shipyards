extends SceneTree

const HERO_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const MANIFEST_PATH := "res://assets/models/torrent/hero/torrent_hero_asset_manifest.json"
const GENERATOR_PATH := "res://tools/blender/generate_torrent_hero_v1.py"
const BLEND_PATH := "res://art_source/torrent/torrent_hero_v1.blend"
const GLB_PATH := "res://assets/models/torrent/hero/torrent_hero_art.glb"
const COVERAGE_EPSILON_M := 0.000001

const EXPECTED_BOX_ORDER := [
	"HullCollision",
	"WingCollision",
	"UpperSilhouetteCollision",
	"PortAftPropulsionCollision",
	"StarboardAftPropulsionCollision",
	"LowerGearCollision",
	"NoseGearCollision",
]
const EXPECTED_BOXES := {
	"HullCollision": [Vector3(0.0, 1.05, -0.3), Vector3(4.6, 2.35, 9.0)],
	"WingCollision": [Vector3(0.0, 0.62, 0.05), Vector3(7.2, 1.5, 6.3)],
	"UpperSilhouetteCollision": [Vector3(0.0, 2.85, 0.85), Vector3(4.75, 1.75, 6.0)],
	"PortAftPropulsionCollision": [Vector3(-2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7)],
	"StarboardAftPropulsionCollision": [Vector3(2.5, 1.1, 3.25), Vector3(1.35, 1.35, 1.7)],
	"LowerGearCollision": [Vector3(0.0, -0.4, -0.15), Vector3(5.0, 0.75, 4.95)],
	"NoseGearCollision": [Vector3(0.0, -0.4, -3.05), Vector3(0.85, 0.55, 1.35)],
}
const EXPECTED_AGGREGATE_BOUNDS := AABB(
	Vector3(-3.6, -0.775, -4.8),
	Vector3(7.2, 4.5, 9.0)
)
const EXPECTED_EXCLUSIONS := [
	"PortEnginePlume",
	"PortPlaneTipLight1",
	"PortPlaneTipLight2",
	"PortPlaneTipLight3",
	"PortPlaneTipLight4",
	"StarboardEnginePlume",
	"StarboardPlaneTipLight1",
	"StarboardPlaneTipLight2",
	"StarboardPlaneTipLight3",
	"StarboardPlaneTipLight4",
]
var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _read_json(MANIFEST_PATH)
	_check(not manifest.is_empty(), "Torrent hero manifest parses for collision/art verification")
	if manifest.is_empty():
		_finish()
		return
	var alignment := manifest.get("collision_art_alignment", {}) as Dictionary
	_test_provenance(manifest, alignment)
	_test_manifest_box_contract(alignment)
	_test_evaluated_coverage(manifest, alignment)

	var test_root := Node3D.new()
	test_root.name = "TorrentCollisionArtAlignmentTestRoot"
	root.add_child(test_root)
	var hero := HERO_SCENE.instantiate() as HeroShip
	_check(hero != null, "production Torrent instantiates as HeroShip")
	if hero == null:
		test_root.queue_free()
		_finish()
		return
	test_root.add_child(hero)
	await process_frame
	await physics_frame
	_test_live_collision_contract(hero, alignment)
	hero.queue_free()
	await process_frame
	test_root.queue_free()
	await process_frame
	_finish()


func _test_provenance(manifest: Dictionary, alignment: Dictionary) -> void:
	_check(int(manifest.get("schema_version", 0)) == 1, "asset manifest retains its stable top-level schema")
	_check(str(manifest.get("asset_id", "")) == "torrent_hero_art_v1", "collision evidence belongs to the exact Torrent hero asset")
	_check(str(manifest.get("authorship", "")) == "original_script_assisted_blender", "manifest retains honest Blender authorship")
	_check(not bool(manifest.get("authenticated_historical_geometry", true)), "manifest makes no authenticated historical-geometry claim")
	_check(int(alignment.get("schema_version", 0)) == 1, "collision/art alignment publishes its versioned schema")
	_check(str(alignment.get("authority", "")) == "external_godot_gameplay_approximation", "manifest keeps collision authority external to presentation art")
	_check(not bool(alignment.get("historical_geometry_claim", true)), "collision approximation cannot masquerade as historical geometry")
	_check(str(alignment.get("evaluation_stage", "")) == "editable_source_before_export_only_static_batching", "coverage is evaluated from semantic Blender source before batching")
	_check(str(alignment.get("evaluation_method", "")) == "evaluated_mesh_vertices_to_nearest_axis_aligned_box_euclidean_distance_v1", "manifest identifies the exact evaluated-vertex distance algorithm")
	_check(str(alignment.get("source_root", "")) == "TorrentHeroArt", "coverage is measured in the stable imported art-root space")
	_check(alignment.get("source_collections", []) == ["LOD0", "CockpitArt", "CanopyPivot"], "coverage includes close hull, cockpit, and closed canopy source collections")
	_check(alignment.get("roots_explicitly_out_of_scope", []) == ["LOD1"], "only the duplicate far silhouette is outside the evaluated scope")
	_check(str(alignment.get("scope", "")) == "visible_close_solid_geometry_with_closed_canopy", "coverage scope explicitly names the complete visible close craft")

	var coordinate := alignment.get("coordinate_contract", {}) as Dictionary
	_check(str(coordinate.get("units", "")) == "metres" and str(coordinate.get("up", "")) == "+Y in Godot" and str(coordinate.get("forward", "")) == "-Z in Godot", "coverage coordinates match Godot ship-local metres")
	_check(str(coordinate.get("root", "")) == "identity" and str(coordinate.get("space", "")) == "TorrentHeroArt root-local equals HeroShip local", "identity import makes Blender audit points directly comparable to live collision")

	var provenance := alignment.get("provenance", {}) as Dictionary
	_check(str(provenance.get("generator", "")) == GENERATOR_PATH.trim_prefix("res://"), "coverage provenance names the checked-in generator")
	_check(str(provenance.get("evaluated_source_blend", "")) == BLEND_PATH.trim_prefix("res://"), "coverage provenance names the editable Blender source")
	_check(str(provenance.get("runtime_glb", "")) == GLB_PATH.trim_prefix("res://"), "coverage provenance names the runtime GLB")
	_check(str(provenance.get("blender_version", "")).begins_with("4.0.2"), "coverage provenance pins Blender 4.0.2")
	var generator_hash := FileAccess.get_sha256(GENERATOR_PATH)
	var blend_hash := FileAccess.get_sha256(BLEND_PATH)
	var glb_hash := FileAccess.get_sha256(GLB_PATH)
	_check(not generator_hash.is_empty() and str(provenance.get("generator_sha256", "")) == generator_hash, "coverage provenance hashes the exact generator bytes")
	_check(not blend_hash.is_empty() and str(provenance.get("evaluated_source_blend_sha256", "")) == blend_hash, "coverage provenance hashes the exact evaluated .blend bytes")
	_check(not glb_hash.is_empty() and str(provenance.get("runtime_glb_sha256", "")) == glb_hash, "coverage provenance hashes the exact runtime GLB bytes")
	_check(str(manifest.get("generator_sha256", "")) == generator_hash, "top-level manifest independently pins the generator hash")
	_check(str(manifest.get("blend_sha256", "")) == blend_hash, "top-level manifest independently pins the Blender-source hash")
	_check(str(manifest.get("glb_sha256", "")) == glb_hash, "top-level manifest independently pins the runtime-GLB hash")
	var semantic_hash := str(manifest.get("source_semantic_sha256", ""))
	_check(semantic_hash.length() == 64 and semantic_hash.is_valid_hex_number(false), "manifest publishes a canonical 256-bit editable-source semantic digest")
	_check(str(provenance.get("evaluated_source_semantic_sha256", "")) == semantic_hash, "coverage provenance and source-preservation contract share the exact semantic digest")
	_check(int(manifest.get("mesh_triangles_evaluated_in_blender", 0)) == 87392 and int(manifest.get("mesh_triangles_exported_runtime", -1)) == 87392, "collision proof preserves the exact 87,392-triangle v5 source/runtime contract")
	var batching := manifest.get("runtime_static_batching", {}) as Dictionary
	_check(int(batching.get("source_mesh_count_total", 0)) == 317 and int(batching.get("runtime_mesh_count_total", 0)) == 32, "collision proof preserves 317 editable semantic meshes and the 32-node runtime budget")
	var protected := batching.get("protected_meshes_by_root", {}) as Dictionary
	var protected_lod0 := _sorted_strings(protected.get("LOD0", []))
	_check(protected_lod0.has("AmberUnknownFunctionPanel") and int((batching.get("runtime_mesh_counts_by_root", {}) as Dictionary).get("LOD0", 0)) == 17, "standalone Amber panel and exact LOD0 batching survive regeneration")


func _test_manifest_box_contract(alignment: Dictionary) -> void:
	var box_order: Array = alignment.get("box_order", []) as Array
	_check(box_order == EXPECTED_BOX_ORDER, "manifest box order exactly matches the seven canonical gameplay boxes")
	var boxes := alignment.get("boxes", {}) as Dictionary
	_check(_sorted_strings(boxes) == _sorted_strings(EXPECTED_BOXES), "manifest has exactly the canonical seven-box roster")
	for box_name: String in EXPECTED_BOXES:
		var published := boxes.get(box_name, {}) as Dictionary
		var oracle: Array = EXPECTED_BOXES[box_name]
		_check(_json_vector3(published.get("position", [] as Array)).is_equal_approx(oracle[0] as Vector3), "%s manifest position matches the independent oracle" % box_name)
		_check(_json_vector3(published.get("size", [] as Array)).is_equal_approx(oracle[1] as Vector3), "%s manifest size matches the independent oracle" % box_name)
		_check(_json_vector3(published.get("rotation_degrees", [] as Array)).is_zero_approx() and _json_vector3(published.get("scale", [] as Array)).is_equal_approx(Vector3.ONE), "%s manifest transform is unrotated unit scale" % box_name)
		_check(str(published.get("shape_type", "")) == "BoxShape3D" and bool(published.get("enabled", false)) and not bool(published.get("top_level", true)), "%s manifest publishes an enabled direct box authority" % box_name)
	var body := alignment.get("body_contract", {}) as Dictionary
	_check(int(body.get("collision_layer", -1)) == PhysicsLayers.SHIP_BODY_LAYER and int(body.get("collision_mask", -1)) == PhysicsLayers.SHIP_BODY_MASK, "manifest body layer and mask match canonical ship physics")
	_check(bool(body.get("direct_children", false)) and bool(body.get("enabled", false)) and not bool(body.get("top_level", true)) and str(body.get("shape_type", "")) == "BoxShape3D", "manifest body contract requires enabled direct non-top-level boxes")
	var aggregate := alignment.get("aggregate_local_aabb", {}) as Dictionary
	_check(_json_vector3(aggregate.get("position", [] as Array)).is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.position) and _json_vector3(aggregate.get("size", [] as Array)).is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.size), "manifest publishes the independently derived aggregate collision bounds")


func _test_evaluated_coverage(manifest: Dictionary, alignment: Dictionary) -> void:
	var manifest_collections := manifest.get("collections", {}) as Dictionary
	var source_names := PackedStringArray()
	for collection_name in ["LOD0", "CockpitArt", "CanopyPivot"]:
		for object_name: Variant in manifest_collections.get(collection_name, [] as Array):
			source_names.append(str(object_name))
	var unique_source_names := _unique_strings(source_names)
	_check(source_names.size() == 299 and unique_source_names.size() == 299, "three evaluated source collections publish 299 unique semantic meshes")
	_check(int(alignment.get("source_object_count", -1)) == source_names.size(), "coverage source count agrees with the semantic manifest roster")

	var exclusions := alignment.get("excluded_objects", {}) as Dictionary
	var exclusion_names := _sorted_strings(exclusions)
	_check(exclusion_names == _sorted_strings(EXPECTED_EXCLUSIONS), "coverage excludes exactly two plumes and eight tiny navigation lights")
	_check(int(alignment.get("excluded_object_count", -1)) == exclusion_names.size(), "published exclusion count matches the exact exclusion roster")
	var reasons_are_explicit := true
	for exclusion_name: String in exclusion_names:
		var reason := str(exclusions.get(exclusion_name, ""))
		if reason.is_empty() or (not reason.contains("non-contact")):
			reasons_are_explicit = false
	_check(reasons_are_explicit, "every excluded effect carries an explicit non-contact justification")

	var expected_included := PackedStringArray()
	for source_name: String in source_names:
		if not exclusion_names.has(source_name):
			expected_included.append(source_name)
	expected_included.sort()
	_check(expected_included.size() == 289 and int(alignment.get("included_object_count", -1)) == expected_included.size(), "coverage includes all 289 non-effect close meshes")

	var categories := alignment.get("categories", {}) as Dictionary
	_check(_sorted_strings(categories) == PackedStringArray(["parked_gear", "primary_hull", "propulsion"]), "coverage partitions geometry into the exact three required categories")
	var propulsion := categories.get("propulsion", {}) as Dictionary
	var parked_gear := categories.get("parked_gear", {}) as Dictionary
	var primary_hull := categories.get("primary_hull", {}) as Dictionary
	var category_partition := PackedStringArray()
	for category in [primary_hull, propulsion, parked_gear]:
		category_partition.append_array(_sorted_strings(category.get("objects", [])))
	_check(
		_unique_strings(category_partition) == expected_included
		and category_partition.size() == expected_included.size(),
		"primary, propulsion, and parked-gear categories form an exact one-to-one source partition"
	)

	_check(int(primary_hull.get("object_count", -1)) == 219 and int(primary_hull.get("evaluated_vertex_count", -1)) == 22801, "primary hull audits 219 objects and 22,801 evaluated vertices")
	_check(int(propulsion.get("object_count", -1)) == 36 and int(propulsion.get("evaluated_vertex_count", -1)) == 11904, "propulsion audits 36 objects and 11,904 evaluated vertices")
	_check(int(parked_gear.get("object_count", -1)) == 34 and int(parked_gear.get("evaluated_vertex_count", -1)) == 4796, "parked gear audits 34 objects and 4,796 evaluated vertices")
	_check(int(primary_hull.get("uncovered_vertex_count", -1)) == 24 and is_equal_approx(float(primary_hull.get("maximum_uncovered_distance_m", -1.0)), 0.00999999), "primary-hull maximum uncovered distance is the measured 10 mm")
	_check(int(propulsion.get("uncovered_vertex_count", -1)) == 6 and is_equal_approx(float(propulsion.get("maximum_uncovered_distance_m", -1.0)), 0.015569925), "propulsion maximum uncovered distance is the measured 15.57 mm")
	_check(int(parked_gear.get("uncovered_vertex_count", -1)) == 0 and is_zero_approx(float(parked_gear.get("maximum_uncovered_distance_m", -1.0))), "all parked-gear evaluated vertices are inside the box union")
	_check(str(primary_hull.get("worst_object", "")) == "PortSteppedPlane4" and str(propulsion.get("worst_object", "")) == "PortDominantAftRail", "manifest retains deterministic worst-distance witnesses")

	var category_object_sum := 0
	var category_vertex_sum := 0
	var category_uncovered_sum := 0
	var category_over_sum := 0
	var category_maximum := 0.0
	for category_value: Variant in categories.values():
		var category := category_value as Dictionary
		category_object_sum += int(category.get("object_count", 0))
		category_vertex_sum += int(category.get("evaluated_vertex_count", 0))
		category_uncovered_sum += int(category.get("uncovered_vertex_count", 0))
		category_over_sum += int(category.get("vertices_over_tolerance", 0))
		category_maximum = maxf(category_maximum, float(category.get("maximum_uncovered_distance_m", 0.0)))
	_check(category_object_sum == int(alignment.get("included_object_count", -1)) and category_vertex_sum == int(alignment.get("evaluated_vertex_count", -1)), "independently summed category objects and vertices match overall coverage")
	_check(category_uncovered_sum == int(alignment.get("uncovered_vertex_count", -1)) and category_uncovered_sum == 30, "independently summed uncovered vertices match the exact 30 sub-tolerance witnesses")
	_check(category_over_sum == int(alignment.get("vertices_over_tolerance", -1)) and category_over_sum == 0, "no category has an evaluated vertex beyond tolerance")
	_check(is_equal_approx(category_maximum, float(alignment.get("maximum_uncovered_distance_m", -1.0))), "overall maximum equals the independently selected category maximum")
	var tolerance := float(alignment.get("tolerance_m", -1.0))
	var independently_valid := (
		is_equal_approx(tolerance, 0.02)
		and category_object_sum == 289
		and category_vertex_sum == 39501
		and category_over_sum == 0
		and (alignment.get("objects_over_tolerance", []) as Array).is_empty()
		and category_maximum <= tolerance + COVERAGE_EPSILON_M
	)
	_check(independently_valid, "independent arithmetic proves the evaluated visible craft is covered within two centimetres")
	_check(bool(alignment.get("valid", false)) == independently_valid, "published overall validity agrees with independent coverage arithmetic")

	var self_audit := alignment.get("self_audit", {}) as Dictionary
	var published_checks := self_audit.get("checks", {}) as Dictionary
	var independently_derived_checks := {
		"exact_source_roster_accounted_for": source_names.size() == 299 and expected_included.size() + exclusion_names.size() == source_names.size(),
		"category_partition_is_complete": category_object_sum == 289 and category_vertex_sum == 39501 and _unique_strings(category_partition) == expected_included,
		"category_totals_match_overall": category_object_sum == int(alignment.get("included_object_count", -1)) and category_vertex_sum == int(alignment.get("evaluated_vertex_count", -1)) and category_over_sum == int(alignment.get("vertices_over_tolerance", -1)),
		"maximum_matches_category_maximum": is_equal_approx(category_maximum, float(alignment.get("maximum_uncovered_distance_m", -1.0))),
		"no_evaluated_vertex_exceeds_tolerance": category_over_sum == 0 and (alignment.get("objects_over_tolerance", []) as Array).is_empty(),
		"maximum_within_two_centimetres": category_maximum <= 0.02 + COVERAGE_EPSILON_M,
		"seven_unique_axis_aligned_boxes": (alignment.get("boxes", {}) as Dictionary).size() == 7,
	}
	_check(_sorted_strings(published_checks) == _sorted_strings(independently_derived_checks), "self-audit exposes exactly the independently reproducible checks")
	var every_self_check_matches := true
	for check_name: String in independently_derived_checks:
		if bool(published_checks.get(check_name, false)) != bool(independently_derived_checks[check_name]):
			every_self_check_matches = false
	_check(every_self_check_matches and bool(self_audit.get("passed", false)) == independently_valid, "manifest self-audit agrees check-by-check rather than supplying an unexamined boolean")


func _test_live_collision_contract(hero: HeroShip, alignment: Dictionary) -> void:
	var boxes := alignment.get("boxes", {}) as Dictionary
	var live_names := PackedStringArray()
	var shape_resource_ids := {}
	var combined := AABB()
	var has_bounds := false
	for child in hero.get_children():
		if child is CollisionShape3D:
			live_names.append(str(child.name))
	live_names.sort()
	_check(live_names == _sorted_strings(EXPECTED_BOXES), "live HeroShip has exactly seven direct collision children")
	_check(hero.collision_layer == PhysicsLayers.SHIP_BODY_LAYER and hero.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "live Torrent uses canonical ship collision layer and mask")
	var body := alignment.get("body_contract", {}) as Dictionary
	_check(hero.collision_layer == int(body.get("collision_layer", -1)) and hero.collision_mask == int(body.get("collision_mask", -1)), "live body collision bits exactly match the manifest contract")
	for box_name: String in EXPECTED_BOXES:
		var collision := hero.get_node_or_null(NodePath(box_name)) as CollisionShape3D
		_check(collision != null and collision.get_parent() == hero, "%s is a direct live HeroShip child" % box_name)
		if collision == null:
			continue
		var oracle: Array = EXPECTED_BOXES[box_name]
		var published := boxes.get(box_name, {}) as Dictionary
		var box_shape := collision.shape as BoxShape3D
		_check(box_shape != null and box_shape.size.is_equal_approx(oracle[1] as Vector3), "%s live BoxShape3D size matches the independent oracle" % box_name)
		_check(collision.position.is_equal_approx(oracle[0] as Vector3), "%s live position matches the independent oracle" % box_name)
		_check(collision.position.is_equal_approx(_json_vector3(published.get("position", [] as Array))) and box_shape != null and box_shape.size.is_equal_approx(_json_vector3(published.get("size", [] as Array))), "%s live geometry exactly matches the Blender manifest box" % box_name)
		_check(collision.basis.is_equal_approx(Basis.IDENTITY) and collision.scale.is_equal_approx(Vector3.ONE), "%s live transform has identity basis and unit scale" % box_name)
		_check(not collision.top_level and not collision.disabled, "%s live authority is enabled and inherits the ship transform" % box_name)
		if box_shape != null:
			shape_resource_ids[box_shape.get_instance_id()] = true
			var shape_bounds := AABB(collision.position - box_shape.size * 0.5, box_shape.size)
			combined = shape_bounds if not has_bounds else combined.merge(shape_bounds)
			has_bounds = true
	_check(shape_resource_ids.size() == 7, "all seven live boxes own distinct shape resources")
	_check(has_bounds and combined.position.is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.position) and combined.size.is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.size), "independently merged live boxes retain the exact aggregate AABB")
	var landing := hero.get_landing_collision_report()
	_check(bool(landing.get("valid", false)) and int(landing.get("shape_count", 0)) == 7 and (landing.get("unsupported_shapes", PackedStringArray()) as PackedStringArray).is_empty(), "landing collision report sees all seven supported boxes")
	var landing_bounds := landing.get("local_bounds", AABB()) as AABB
	_check(landing_bounds.position.is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.position) and landing_bounds.size.is_equal_approx(EXPECTED_AGGREGATE_BOUNDS.size), "landing report agrees with independently merged live bounds")
	var presentation := hero.get_node_or_null("TorrentVisual/TorrentHeroPresentation")
	_check(presentation != null and presentation.find_children("*", "CollisionShape3D", true, false).is_empty(), "imported Blender presentation contains no duplicate collision authority")
	var reconstruction := hero.get_torrent_reconstruction_audit_report()
	_check(_sorted_strings(reconstruction.get("collision_shapes", PackedStringArray())) == _sorted_strings(EXPECTED_BOXES), "production reconstruction audit publishes the full seven-box roster")
	var art_audit := hero.get_torrent_art_audit_report()
	_check(bool(art_audit.get("valid", false)), "production art audit independently accepts the exact live collision authority")


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _json_vector3(value: Variant) -> Vector3:
	if not value is Array or (value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _sorted_strings(value: Variant) -> PackedStringArray:
	var strings := PackedStringArray()
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			strings.append(str(key))
	elif value is Array:
		for item: Variant in value:
			strings.append(str(item))
	elif value is PackedStringArray:
		strings = (value as PackedStringArray).duplicate()
	strings.sort()
	return strings


func _unique_strings(values: PackedStringArray) -> PackedStringArray:
	var seen := {}
	for value: String in values:
		seen[value] = true
	return _sorted_strings(seen)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_COLLISION_ART_ALIGNMENT_TEST_OK: %d assertions" % _assertions)
		quit()
	else:
		print("TORRENT_COLLISION_ART_ALIGNMENT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
