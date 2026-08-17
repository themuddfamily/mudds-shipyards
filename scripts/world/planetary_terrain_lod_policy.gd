class_name PlanetaryTerrainLodPolicy
extends RefCounted

## Pure, deterministic clipmap-selection policy for one validated
## [PlanetaryTerrainProfile].
##
## Configuration freezes only detached value data. Evaluation selects policy
## hints; it never generates heights, tiles, meshes, collision, or scene state.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"planetary_terrain_lod_v1"

var _configured := false
var _profile_id: StringName = &""
var _source_profile_schema_version := 0
var _lod_strategy: StringName = &""
var _ring_distances_meters := PackedFloat64Array()
var _collision_lod_ring_index := -1
var _collision_maximum_distance_meters := 0.0
var _tile_resolution_vertices_per_edge := 0
var _maximum_visible_tile_count := 0
var _maximum_resident_tile_count := 0
var _maximum_collision_tile_count := 0


## Freezes a valid profile once. A rejected configuration leaves the policy
## retryable; a successful configuration is immutable.
func configure(profile: PlanetaryTerrainProfile) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if profile == null:
		return _result(false, &"missing_profile")
	var source_audit := profile.audit()
	if not profile.is_profile_valid() or not bool(
		source_audit.get("valid", false)
	):
		return _result(false, &"invalid_profile", {
			"profile_errors": (
				source_audit.get("errors", PackedStringArray()) \
					as PackedStringArray
			).duplicate(),
		})
	var source_snapshot := profile.get_snapshot()
	if not _profile_snapshot_is_valid(source_snapshot):
		return _result(false, &"invalid_profile_snapshot")

	_configured = true
	_profile_id = source_snapshot.get("profile_id", &"") as StringName
	_source_profile_schema_version = int(
		source_snapshot.get("schema_version", 0)
	)
	_lod_strategy = source_snapshot.get("lod_strategy", &"") as StringName
	_ring_distances_meters = (
		source_snapshot.get(
			"clipmap_ring_distances_meters", PackedFloat64Array()
		) as PackedFloat64Array
	).duplicate()
	_collision_lod_ring_index = int(
		source_snapshot.get("collision_lod_ring_index", -1)
	)
	_collision_maximum_distance_meters = float(
		source_snapshot.get("collision_maximum_distance_meters", 0.0)
	)
	_tile_resolution_vertices_per_edge = int(
		source_snapshot.get("tile_resolution_vertices_per_edge", 0)
	)
	_maximum_visible_tile_count = int(
		source_snapshot.get("maximum_visible_tile_count", 0)
	)
	_maximum_resident_tile_count = int(
		source_snapshot.get("maximum_resident_tile_count", 0)
	)
	_maximum_collision_tile_count = int(
		source_snapshot.get("maximum_collision_tile_count", 0)
	)
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


## Evaluates one caller-owned camera distance and collision requirement. Integer
## and float distances are accepted; booleans and coercible strings are not.
func evaluate(
		camera_to_surface_distance_meters: Variant,
		collision_needed: Variant
	) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if not _is_valid_distance(camera_to_surface_distance_meters):
		return _result(false, &"invalid_camera_to_surface_distance")
	if typeof(collision_needed) != TYPE_BOOL:
		return _result(false, &"invalid_collision_need")

	var distance_meters := float(camera_to_surface_distance_meters)
	var render_ring_index := _select_render_ring(distance_meters)
	var render_participates := render_ring_index >= 0
	var collision_participates := bool(collision_needed) \
		and distance_meters <= _collision_maximum_distance_meters
	var render_ring_inner_distance := 0.0
	var render_ring_outer_distance := 0.0
	if render_participates:
		render_ring_outer_distance = _ring_distances_meters[render_ring_index]
		if render_ring_index > 0:
			render_ring_inner_distance = _ring_distances_meters[
				render_ring_index - 1
			]

	var budget_hints := {
		"tile_resolution_vertices_per_edge": (
			_tile_resolution_vertices_per_edge if render_participates else 0
		),
		"visible_tile_count_ceiling": (
			_maximum_visible_tile_count if render_participates else 0
		),
		"resident_tile_count_ceiling": (
			_maximum_resident_tile_count if render_participates else 0
		),
		"collision_tile_count_ceiling": (
			_maximum_collision_tile_count if collision_participates else 0
		),
	}
	return _result(true, &"evaluated", {
		"camera_to_surface_distance_meters": distance_meters,
		"collision_needed": bool(collision_needed),
		"render_participates": render_participates,
		"render_ring_index": render_ring_index,
		"render_ring_inner_distance_meters": render_ring_inner_distance,
		"render_ring_outer_distance_meters": render_ring_outer_distance,
		"render_ring_count": _ring_distances_meters.size(),
		"collision_participates": collision_participates,
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": (
			_collision_maximum_distance_meters
		),
		"tile_budget_hints": budget_hints,
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"configured": _configured,
		"profile_id": _profile_id,
		"source_profile_schema_version": _source_profile_schema_version,
		"lod_strategy": _lod_strategy,
		"clipmap_ring_distances_meters": _ring_distances_meters.duplicate(),
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": (
			_collision_maximum_distance_meters
		),
		"tile_resolution_vertices_per_edge": (
			_tile_resolution_vertices_per_edge
		),
		"maximum_visible_tile_count": _maximum_visible_tile_count,
		"maximum_resident_tile_count": _maximum_resident_tile_count,
		"maximum_collision_tile_count": _maximum_collision_tile_count,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("terrain LOD policy is not configured")
	elif not _frozen_contract_is_valid():
		errors.append("frozen terrain LOD contract is invalid")
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"ordering_policy": &"first_inclusive_near_to_far_ring",
		"outside_outer_ring_policy": &"no_render_participation",
		"collision_policy": &"caller_need_and_inclusive_profile_distance",
		"tile_budget_policy": &"profile_ceilings_gated_by_participation",
		"purity": {
			"delta_or_clock_input": false,
			"mutates_source_profile": false,
			"mutates_policy_during_evaluation": false,
		},
		"authority": {
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
		},
		"policy_specific_authority": {
			"height_generation": false,
			"terrain_mesh": false,
			"landing": false,
			"clock": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _select_render_ring(distance_meters: float) -> int:
	for index in _ring_distances_meters.size():
		if distance_meters <= _ring_distances_meters[index]:
			return index
	return -1


func _frozen_contract_is_valid() -> bool:
	return _profile_snapshot_is_valid({
		"schema_version": _source_profile_schema_version,
		"profile_id": _profile_id,
		"lod_strategy": _lod_strategy,
		"clipmap_ring_distances_meters": _ring_distances_meters.duplicate(),
		"collision_lod_ring_index": _collision_lod_ring_index,
		"collision_maximum_distance_meters": (
			_collision_maximum_distance_meters
		),
		"tile_resolution_vertices_per_edge": (
			_tile_resolution_vertices_per_edge
		),
		"maximum_visible_tile_count": _maximum_visible_tile_count,
		"maximum_resident_tile_count": _maximum_resident_tile_count,
		"maximum_collision_tile_count": _maximum_collision_tile_count,
	})


static func _profile_snapshot_is_valid(snapshot: Dictionary) -> bool:
	if snapshot.get("schema_version") != PlanetaryTerrainProfile.SCHEMA_VERSION \
		or not snapshot.get("profile_id") is StringName \
		or (snapshot.get("profile_id") as StringName).is_empty() \
		or snapshot.get("lod_strategy") != PlanetaryTerrainProfile.LOD_STRATEGY:
		return false
	var rings_value: Variant = snapshot.get(
		"clipmap_ring_distances_meters", PackedFloat64Array()
	)
	if not rings_value is PackedFloat64Array:
		return false
	var rings := rings_value as PackedFloat64Array
	if rings.size() < PlanetaryTerrainProfile.MIN_LOD_RING_COUNT \
		or rings.size() > PlanetaryTerrainProfile.MAX_LOD_RING_COUNT:
		return false
	var previous := 0.0
	for index in rings.size():
		var distance := rings[index]
		if not is_finite(distance) or distance <= previous \
			or distance > PlanetaryTerrainProfile.MAX_LOD_DISTANCE_METERS:
			return false
		previous = distance

	var collision_index_value: Variant = snapshot.get(
		"collision_lod_ring_index", -1
	)
	var collision_distance_value: Variant = snapshot.get(
		"collision_maximum_distance_meters", NAN
	)
	if typeof(collision_index_value) != TYPE_INT \
		or not _is_finite_float_value(collision_distance_value):
		return false
	var collision_index := int(collision_index_value)
	var collision_distance := float(collision_distance_value)
	if collision_index < 0 or collision_index >= rings.size() \
		or collision_distance <= 0.0 \
		or collision_distance > rings[collision_index]:
		return false

	var tile_resolution_value: Variant = snapshot.get(
		"tile_resolution_vertices_per_edge", 0
	)
	var maximum_visible_value: Variant = snapshot.get(
		"maximum_visible_tile_count", 0
	)
	var maximum_resident_value: Variant = snapshot.get(
		"maximum_resident_tile_count", 0
	)
	var maximum_collision_value: Variant = snapshot.get(
		"maximum_collision_tile_count", 0
	)
	if typeof(tile_resolution_value) != TYPE_INT \
		or typeof(maximum_visible_value) != TYPE_INT \
		or typeof(maximum_resident_value) != TYPE_INT \
		or typeof(maximum_collision_value) != TYPE_INT:
		return false
	var tile_resolution := int(tile_resolution_value)
	var visible_tiles := int(maximum_visible_value)
	var resident_tiles := int(maximum_resident_value)
	var collision_tiles := int(maximum_collision_value)
	if not _is_power_of_two_plus_one(tile_resolution) \
		or tile_resolution < (
			PlanetaryTerrainProfile.MIN_TILE_RESOLUTION_VERTICES_PER_EDGE
		) or tile_resolution > (
			PlanetaryTerrainProfile.MAX_TILE_RESOLUTION_VERTICES_PER_EDGE
		):
		return false
	return visible_tiles >= 1 \
		and visible_tiles <= PlanetaryTerrainProfile.MAX_VISIBLE_TILE_COUNT \
		and resident_tiles >= visible_tiles \
		and resident_tiles <= PlanetaryTerrainProfile.MAX_RESIDENT_TILE_COUNT \
		and collision_tiles >= 1 \
		and collision_tiles <= visible_tiles


static func _is_valid_distance(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 \
		and number <= PlanetaryTerrainProfile.MAX_LOD_DISTANCE_METERS


static func _is_finite_float_value(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT and is_finite(float(value))


static func _is_power_of_two_plus_one(value: int) -> bool:
	var edge_intervals := value - 1
	return edge_intervals > 0 \
		and (edge_intervals & (edge_intervals - 1)) == 0


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"profile_id": _profile_id,
		"policy_version": POLICY_VERSION,
	}
	result.merge(details, true)
	return result.duplicate(true)
