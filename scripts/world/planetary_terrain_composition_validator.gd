class_name PlanetaryTerrainCompositionValidator
extends RefCounted

## Pure join between one terrain profile and its frozen clipmap policy.
##
## The profile remains authored data and the policy remains a deterministic
## selector. This boundary proves that a later terrain owner will consume the
## same LOD, collision, tile-budget, and biome/material declarations. It never
## generates terrain, allocates tiles, or owns streaming/origin state.

const TerrainProfileScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const TerrainLodPolicyScript := preload("res://scripts/world/planetary_terrain_lod_policy.gd")

const SCHEMA_VERSION := 1
const MATERIAL_ORDER: StringName = &"declared_biome_layer_order"


func validate_composition(
		terrain: PlanetaryTerrainProfile,
		lod_policy: PlanetaryTerrainLodPolicy
	) -> Dictionary:
	var errors: Array[Dictionary] = []
	var terrain_valid := terrain != null and terrain.is_profile_valid()
	var policy_snapshot: Dictionary = {}
	var policy_valid := false
	if terrain == null:
		_append_error(
			errors,
			&"missing_terrain_profile",
			&"terrain",
			"a terrain profile is required"
		)
	elif not terrain_valid:
		_append_error(
			errors,
			&"invalid_terrain_profile",
			&"terrain",
			"the terrain profile is invalid"
		)

	if lod_policy == null:
		_append_error(
			errors,
			&"missing_lod_policy",
			&"lod_policy",
			"a configured terrain LOD policy is required"
		)
	else:
		policy_snapshot = lod_policy.get_snapshot()
		var policy_audit := lod_policy.audit()
		policy_valid = lod_policy.is_configured() and bool(
			policy_audit.get("valid", false)
		)
		if not policy_valid:
			_append_error(
				errors,
				&"invalid_lod_policy",
				&"lod_policy",
				"the terrain LOD policy must be configured and internally valid"
			)

	if terrain_valid and policy_valid:
		_validate_policy_binding(errors, terrain, policy_snapshot)

	var error_codes := PackedStringArray()
	for error in errors:
		error_codes.append(str(error.get("code", &"unknown_error")))
	var terrain_snapshot: Dictionary = (
		terrain.get_snapshot() if terrain != null else {}
	)
	var biome_layers: PackedStringArray = terrain_snapshot.get(
		"biome_layer_ids", PackedStringArray()
	) as PackedStringArray
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"error_codes": error_codes,
		"profile_id": terrain.profile_id if terrain != null else &"",
		"lod_strategy": terrain_snapshot.get("lod_strategy", &""),
		"clipmap_ring_distances_meters": terrain_snapshot.get(
			"clipmap_ring_distances_meters", PackedFloat64Array()
		),
		"collision_lod_ring_index": terrain_snapshot.get(
			"collision_lod_ring_index", -1
		),
		"collision_maximum_distance_meters": terrain_snapshot.get(
			"collision_maximum_distance_meters", 0.0
		),
		"tile_budget": {
			"resolution_vertices_per_edge": terrain_snapshot.get(
				"tile_resolution_vertices_per_edge", 0
			),
			"maximum_visible": terrain_snapshot.get(
				"maximum_visible_tile_count", 0
			),
			"maximum_resident": terrain_snapshot.get(
				"maximum_resident_tile_count", 0
			),
			"maximum_collision": terrain_snapshot.get(
				"maximum_collision_tile_count", 0
			),
		},
		"surface_classification": {
			"biome_layer_ids": biome_layers.duplicate(),
			"material_channel_order": MATERIAL_ORDER,
		},
		"origin_shift_threshold_meters": terrain_snapshot.get(
			"origin_shift_threshold_meters", 0.0
		),
		"policy": policy_snapshot,
		"evidence": (
			(terrain.audit().get("evidence", {}) as Dictionary).duplicate(true)
			if terrain != null else {}
		),
		"authority": get_authority_report(),
	}.duplicate(true)


func audit(
		terrain: PlanetaryTerrainProfile,
		lod_policy: PlanetaryTerrainLodPolicy
	) -> Dictionary:
	return validate_composition(terrain, lod_policy).duplicate(true)


func get_authority_report() -> Dictionary:
	return {
		"renderer": false,
		"gameplay": false,
		"streaming": false,
		"save": false,
		"network": false,
		"physics": false,
		"world_generation": false,
		"terrain_generation": false,
		"collision_generation": false,
		"origin_shift": false,
		"weather_clock": false,
		"audio": false,
	}.duplicate(true)


func _validate_policy_binding(
		errors: Array[Dictionary],
		terrain: PlanetaryTerrainProfile,
		policy_snapshot: Dictionary
	) -> void:
	var profile_snapshot := terrain.get_snapshot()
	var fields := [
		"profile_id", "lod_strategy", "clipmap_ring_distances_meters",
		"collision_lod_ring_index", "collision_maximum_distance_meters",
		"tile_resolution_vertices_per_edge", "maximum_visible_tile_count",
		"maximum_resident_tile_count", "maximum_collision_tile_count",
	]
	for field in fields:
		if profile_snapshot.get(field) != policy_snapshot.get(field):
			_append_error(
				errors,
				&"lod_policy_profile_mismatch",
				StringName(field),
				"the frozen LOD policy must retain the exact terrain profile field"
			)
	if policy_snapshot.get("source_profile_schema_version") \
				!= TerrainProfileScript.SCHEMA_VERSION:
		_append_error(
			errors,
			&"lod_policy_schema_mismatch",
			&"source_profile_schema_version",
			"the LOD policy must identify the current terrain profile schema"
		)


static func _append_error(
		errors: Array[Dictionary],
		code: StringName,
		field: StringName,
		message: String
	) -> void:
	errors.append({"code": code, "field": field, "message": message})
