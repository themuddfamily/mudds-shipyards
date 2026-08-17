extends SceneTree

const ProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const COMMON_EVIDENCE_KEYS := [
	"content_class", "status", "scope", "references", "notes",
]
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_test_valid_contract_and_deterministic_units()
	_test_scale_elevation_and_finite_bounds()
	_test_lod_and_collision_contract()
	_test_tile_and_biome_ceilings()
	_test_landing_and_origin_limits()
	_test_detached_snapshot_audit_and_zero_authority()
	_test_resource_round_trip()
	_finish()


func _test_valid_contract_and_deterministic_units() -> void:
	var profile := ProfileScript.new()
	var snapshot := profile.get_snapshot()
	var audit := profile.audit()
	_check(
		profile is Resource and not (profile as Object).is_class("Node"),
		"the terrain profile is data, never a scene/process owner"
	)
	_check(profile.is_profile_valid(), "the authored default planetary terrain contract validates")
	_check(profile.get_planet_radius_meters() == 120000.0 and profile.get_maximum_elevation_meters() == 8500.0, "canonical metre accessors publish the shared sea-level datum and elevation envelope")
	_check(
		snapshot.get("planet_radius_reference") == &"sea_level"
			and snapshot.get("lod_strategy") == &"clipmap_rings"
			and snapshot.get("clipmap_ring_distances_meters")
				== PackedFloat64Array([256.0, 768.0, 2048.0, 6144.0, 18432.0]),
		"sea-level radius and near-to-far clipmap rings are explicit"
	)
	var units := audit.get("units", {}) as Dictionary
	_check(
		units == {
			"distance": &"meters",
			"angle": &"degrees",
			"tile_resolution": &"vertices_per_edge",
			"tile_count": &"tiles",
		},
		"the audit publishes one deterministic unit system"
	)
	_check(
		int(snapshot.get("collision_lod_ring_index", -1)) == 2
			and is_equal_approx(float(snapshot.get("collision_maximum_distance_meters", -1.0)), 1500.0),
		"collision names one exact LOD and finite distance envelope"
	)


func _test_scale_elevation_and_finite_bounds() -> void:
	var profile := ProfileScript.new()
	profile.profile_id = &"9terrain"
	_check(not profile.is_profile_valid(), "terrain profile identity starts with a lowercase letter like world references")
	profile = ProfileScript.new()
	profile.evidence_references = PackedStringArray(["source", "source"])
	_check(not profile.is_profile_valid(), "terrain evidence references reject duplicates")
	profile = ProfileScript.new()
	profile.evidence_references = PackedStringArray(["x".repeat(ProfileScript.MAX_EVIDENCE_REFERENCE_LENGTH + 1)])
	_check(not profile.is_profile_valid(), "terrain evidence references have the shared length ceiling")
	profile = ProfileScript.new()
	var mutations: Array[Dictionary] = [
		{"field": &"reference_planet_radius_meters", "value": NAN},
		{"field": &"reference_planet_radius_meters", "value": ProfileScript.MIN_PLANET_RADIUS_METERS - 0.01},
		{"field": &"reference_planet_radius_meters", "value": ProfileScript.MAX_PLANET_RADIUS_METERS + 1.0},
		{"field": &"minimum_elevation_meters", "value": -INF},
		{"field": &"maximum_elevation_meters", "value": INF},
		{"field": &"minimum_elevation_meters", "value": -ProfileScript.MAX_ABSOLUTE_ELEVATION_METERS - 1.0},
		{"field": &"maximum_elevation_meters", "value": ProfileScript.MAX_ABSOLUTE_ELEVATION_METERS + 1.0},
	]
	for mutation in mutations:
		var candidate := ProfileScript.new()
		candidate.set(StringName(mutation.field), mutation.value)
		_check(
			not candidate.is_profile_valid(),
			"non-finite/out-of-range scale mutation is rejected: %s" % mutation.field
		)
	profile.minimum_elevation_meters = profile.maximum_elevation_meters
	_check(not profile.is_profile_valid(), "equal or inverted elevation endpoints are rejected")
	profile = ProfileScript.new()
	profile.reference_planet_radius_meters = 1000.0
	profile.minimum_elevation_meters = -1000.0
	profile.maximum_elevation_meters = 10.0
	_check(not profile.is_profile_valid(), "an elevation envelope cannot cross the radial centre")


func _test_lod_and_collision_contract() -> void:
	var profile := ProfileScript.new()
	profile.clipmap_ring_distances_meters = PackedFloat64Array([256.0])
	_check(not profile.is_profile_valid(), "a clipmap roster below the ring-count floor is rejected")
	profile.clipmap_ring_distances_meters = PackedFloat64Array([
		1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0,
		10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0,
	])
	_check(not profile.is_profile_valid(), "a clipmap roster above the ring-count ceiling is rejected")
	for bad_rings in [
		PackedFloat64Array([256.0, 256.0]),
		PackedFloat64Array([512.0, 256.0]),
		PackedFloat64Array([NAN, 512.0]),
		PackedFloat64Array([0.0, 512.0]),
		PackedFloat64Array([256.0, ProfileScript.MAX_LOD_DISTANCE_METERS + 1.0]),
	]:
		profile = ProfileScript.new()
		profile.clipmap_ring_distances_meters = bad_rings
		_check(not profile.is_profile_valid(), "malformed clipmap ring distances fail closed: %s" % bad_rings)
	profile = ProfileScript.new()
	profile.collision_lod_ring_index = profile.clipmap_ring_distances_meters.size()
	_check(not profile.is_profile_valid(), "collision cannot name a missing clipmap ring")
	profile = ProfileScript.new()
	profile.collision_maximum_distance_meters = INF
	_check(not profile.is_profile_valid(), "collision distance must be finite")
	profile = ProfileScript.new()
	profile.collision_lod_ring_index = 1
	profile.collision_maximum_distance_meters = 768.01
	_check(not profile.is_profile_valid(), "collision cannot extend beyond its selected ring")


func _test_tile_and_biome_ceilings() -> void:
	for bad_resolution in [16, 18, 130, 1026]:
		var candidate := ProfileScript.new()
		candidate.tile_resolution_vertices_per_edge = bad_resolution
		_check(not candidate.is_profile_valid(), "non-2^n+1/bounded tile resolution is rejected: %d" % bad_resolution)
	var profile := ProfileScript.new()
	profile.maximum_visible_tile_count = ProfileScript.MAX_VISIBLE_TILE_COUNT + 1
	_check(not profile.is_profile_valid(), "visible tile count cannot exceed its hard ceiling")
	profile = ProfileScript.new()
	profile.maximum_resident_tile_count = profile.maximum_visible_tile_count - 1
	_check(not profile.is_profile_valid(), "resident tile capacity must cover every visible tile")
	profile = ProfileScript.new()
	profile.maximum_collision_tile_count = profile.maximum_visible_tile_count + 1
	_check(not profile.is_profile_valid(), "collision tiles cannot exceed the visible tile ceiling")
	profile = ProfileScript.new()
	profile.biome_layer_ids = PackedStringArray()
	_check(not profile.is_profile_valid(), "a terrain profile requires at least one biome layer")
	profile.biome_layer_ids = PackedStringArray(["bedrock", "bedrock"])
	_check(not profile.is_profile_valid(), "duplicate biome channel IDs are rejected")
	profile.biome_layer_ids = PackedStringArray(["Bed Rock"])
	_check(not profile.is_profile_valid(), "biome IDs use stable lowercase snake case")
	profile.biome_layer_ids = PackedStringArray(["9bedrock"])
	_check(not profile.is_profile_valid(), "biome IDs begin with a lowercase letter")
	var too_many_biomes := PackedStringArray()
	for index in ProfileScript.MAX_BIOME_LAYER_COUNT + 1:
		too_many_biomes.append("layer_%d" % index)
	profile.biome_layer_ids = too_many_biomes
	_check(not profile.is_profile_valid(), "biome layer count cannot exceed its exact ceiling")


func _test_landing_and_origin_limits() -> void:
	var mutations: Array[Dictionary] = [
		{"field": &"landing_site_maximum_slope_degrees", "value": NAN},
		{"field": &"landing_site_maximum_slope_degrees", "value": -0.01},
		{"field": &"landing_site_maximum_slope_degrees", "value": ProfileScript.MAX_LANDING_SLOPE_DEGREES + 0.01},
		{"field": &"landing_site_maximum_roughness_meters", "value": INF},
		{"field": &"landing_site_maximum_roughness_meters", "value": -0.01},
		{"field": &"landing_site_maximum_roughness_meters", "value": ProfileScript.MAX_LANDING_ROUGHNESS_METERS + 0.01},
		{"field": &"origin_shift_threshold_meters", "value": NAN},
		{"field": &"origin_shift_threshold_meters", "value": ProfileScript.MIN_ORIGIN_SHIFT_THRESHOLD_METERS - 0.01},
		{"field": &"origin_shift_threshold_meters", "value": ProfileScript.MAX_ORIGIN_SHIFT_THRESHOLD_METERS + 1.0},
	]
	for mutation in mutations:
		var candidate := ProfileScript.new()
		candidate.set(StringName(mutation.field), mutation.value)
		_check(not candidate.is_profile_valid(), "landing/origin bound rejects %s" % mutation.field)
	var profile := ProfileScript.new()
	profile.origin_shift_threshold_meters = profile.reference_planet_radius_meters
	_check(not profile.is_profile_valid(), "origin shift must occur before the sea-level radius reference")


func _test_detached_snapshot_audit_and_zero_authority() -> void:
	var profile := ProfileScript.new()
	var snapshot := profile.get_snapshot()
	var returned_rings := snapshot.get("clipmap_ring_distances_meters") as PackedFloat64Array
	var returned_biomes := snapshot.get("biome_layer_ids") as PackedStringArray
	returned_rings[0] = 999999.0
	returned_biomes[0] = "caller_mutated"
	snapshot["reference_planet_radius_meters"] = -1.0
	_check(
		profile.clipmap_ring_distances_meters[0] == 256.0
			and profile.biome_layer_ids[0] == "bedrock"
			and profile.reference_planet_radius_meters == 120000.0,
		"snapshot arrays and scalars are detached from the source profile"
	)
	var audit := profile.audit()
	var audit_snapshot := audit.get("snapshot", {}) as Dictionary
	(audit_snapshot.get("biome_layer_ids") as PackedStringArray)[0] = "audit_mutated"
	(audit.get("errors") as PackedStringArray).append("caller_mutated")
	((audit.get("evidence") as Dictionary))["status"] = &"caller_mutated"
	(audit.get("authority") as Dictionary)["terrain_generation"] = true
	var fresh_audit := profile.audit()
	var evidence := fresh_audit.get("evidence", {}) as Dictionary
	var authority := fresh_audit.get("authority", {}) as Dictionary
	_check(
		(fresh_audit.get("snapshot", {}) as Dictionary).get("biome_layer_ids")
			== PackedStringArray(["bedrock", "regolith", "ice"])
			and (fresh_audit.get("errors") as PackedStringArray).is_empty(),
		"audit trees are deeply detached across calls"
	)
	_check(
		_dictionary_has_exact_keys(evidence, COMMON_EVIDENCE_KEYS)
			and evidence.status == &"modern_interpretation",
		"common nested evidence publishes exactly the five-key core",
	)
	var all_zero := _dictionary_has_exact_keys(authority, COMMON_AUTHORITY_KEYS)
	for key in COMMON_AUTHORITY_KEYS:
		all_zero = all_zero and authority[key] is bool and not bool(authority[key])
	_check(all_zero, "common nested authority is detached and freezes the exact zero-authority roster")
	var authority_without_audio := authority.duplicate(true)
	authority_without_audio.erase("audio")
	_check(
		not _dictionary_has_exact_keys(authority_without_audio, COMMON_AUTHORITY_KEYS),
		"the exact authority roster rejects a missing audio key",
	)
	_check(
		bool(fresh_audit.get("valid", false))
			and not bool(fresh_audit.get("terrain_renderer_authority", true))
			and not bool(fresh_audit.get("terrain_generation_authority", true))
			and not bool(fresh_audit.get("collision_generation_authority", true))
			and not bool(fresh_audit.get("gameplay_authority", true))
			and not bool(fresh_audit.get("streaming_authority", true))
			and not bool(fresh_audit.get("save_authority", true))
			and not bool(fresh_audit.get("network_authority", true))
			and not bool(fresh_audit.get("origin_shift_authority", true)),
		"the profile freezes zero renderer/generator/gameplay/stream/save authority"
	)


func _test_resource_round_trip() -> void:
	var profile := ProfileScript.new() as PlanetaryTerrainProfile
	profile.profile_id = &"round_trip_terrain"
	profile.evidence_references = PackedStringArray(["phase_10_design_note"])
	var resource_path := "user://planetary_terrain_profile_test_%d.tres" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ResourceSaver.save(profile, resource_path)
	_check(save_error == OK, "terrain profile saves as a normal typed Godot Resource")
	var loaded := ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlanetaryTerrainProfile
	_check(loaded != null, "saved terrain profile reloads with its concrete type")
	if loaded != null:
		_check(
			loaded.is_profile_valid()
				and loaded.profile_id == &"round_trip_terrain"
				and loaded.get_snapshot() == profile.get_snapshot()
				and loaded.get_authority_report() == profile.get_authority_report(),
			"round trip preserves terrain units, evidence, budgets, and zero authority",
		)
	if FileAccess.file_exists(resource_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_check(remove_error == OK, "temporary terrain profile Resource is removed")
	_check(
		not profile.has_method("_process")
			and not profile.has_method("_physics_process")
			and not profile.has_method("generate")
			and not profile.has_method("save"),
		"the data contract exposes no automatic or adjacent-authority seam"
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _dictionary_has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _finish() -> void:
	print("PLANETARY_TERRAIN_PROFILE_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_TERRAIN_PROFILE_TEST_OK")
		quit(0)
		return
	print("PLANETARY_TERRAIN_PROFILE_TEST_FAILURES: %s" % _failures)
	quit(1)
