class_name PlanetaryTerrainProfile
extends Resource

## Side-effect-free scale, LOD, collision, biome, and landing constraints for
## one planetary terrain data set.
##
## Every distance is expressed in metres, every angle in degrees, and every
## count is an exact integer ceiling. The profile describes what a later
## terrain system may build; it never builds, streams, renders, saves, or owns
## gameplay state itself.

const SCHEMA_VERSION := 1

const LOD_STRATEGY: StringName = &"clipmap_rings"
const PLANET_RADIUS_REFERENCE: StringName = &"sea_level"
const DISTANCE_UNIT: StringName = &"meters"
const ANGLE_UNIT: StringName = &"degrees"
const TILE_RESOLUTION_UNIT: StringName = &"vertices_per_edge"
const TILE_COUNT_UNIT: StringName = &"tiles"
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EVIDENCE_SCOPE: StringName = &"game_scale_terrain_parameters"
const MAX_EVIDENCE_REFERENCES := 32
const MAX_EVIDENCE_REFERENCE_LENGTH := 192

const MIN_PLANET_RADIUS_METERS := 1000.0
const MAX_PLANET_RADIUS_METERS := 100000000.0
const MAX_ABSOLUTE_ELEVATION_METERS := 1000000.0
const MIN_LOD_RING_COUNT := 2
const MAX_LOD_RING_COUNT := 16
const MAX_LOD_DISTANCE_METERS := 10000000.0
const MIN_TILE_RESOLUTION_VERTICES_PER_EDGE := 17
const MAX_TILE_RESOLUTION_VERTICES_PER_EDGE := 1025
const MAX_VISIBLE_TILE_COUNT := 16384
const MAX_RESIDENT_TILE_COUNT := 32768
const MAX_BIOME_LAYER_COUNT := 32
const MAX_LANDING_SLOPE_DEGREES := 45.0
const MAX_LANDING_ROUGHNESS_METERS := 25.0
const MIN_ORIGIN_SHIFT_THRESHOLD_METERS := 100.0
const MAX_ORIGIN_SHIFT_THRESHOLD_METERS := 10000000.0

@export_category("Identity")
@export var profile_id: StringName = &"default_planetary_terrain"
@export var display_name := "Default planetary terrain"

@export_category("Evidence")
@export var evidence_references := PackedStringArray()
@export_multiline var evidence_notes := "New game-scale terrain tuning profile; not a claim about historical or real terrain."

@export_category("Game-scale elevation envelope")
## Sea-level radius used as the deterministic radial reference.
@export var reference_planet_radius_meters := 120000.0
@export var minimum_elevation_meters := -2500.0
@export var maximum_elevation_meters := 8500.0

@export_category("Clipmap LOD")
## Inclusive outer distances from the terrain focus, ordered finest to coarsest.
@export var clipmap_ring_distances_meters := PackedFloat64Array([
	256.0,
	768.0,
	2048.0,
	6144.0,
	18432.0,
])
## Zero is the finest ring. Collision uses this terrain LOD through the exact
## maximum distance below; it does not imply a collision generator.
@export var collision_lod_ring_index := 2
@export var collision_maximum_distance_meters := 1500.0

@export_category("Tile ceilings")
## Terrain grids must be 2^n + 1 vertices per edge so adjacent tiles share an
## exact boundary sample.
@export var tile_resolution_vertices_per_edge := 129
@export var maximum_visible_tile_count := 512
@export var maximum_resident_tile_count := 1024
@export var maximum_collision_tile_count := 256

@export_category("Surface classification")
## Stable ordered layer IDs. Their order is the deterministic material/splat
## channel assignment for a later terrain implementation.
@export var biome_layer_ids := PackedStringArray([
	"bedrock",
	"regolith",
	"ice",
])

@export_category("Landing-site limits")
@export var landing_site_maximum_slope_degrees := 12.0
## Maximum permitted peak-to-mean height deviation inside a later landing-site
## evaluator's footprint.
@export var landing_site_maximum_roughness_meters := 0.75

@export_category("Floating origin")
## Observer distance from the current local origin at which a later owner may
## request a shift. This profile neither observes nor performs that shift.
@export var origin_shift_threshold_meters := 10000.0


func get_clipmap_ring_distances_meters() -> PackedFloat64Array:
	return clipmap_ring_distances_meters.duplicate()


func get_biome_layer_ids() -> PackedStringArray:
	return biome_layer_ids.duplicate()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "profile_id", str(profile_id))
	if display_name.is_empty() or display_name != display_name.strip_edges() \
		or display_name.contains("\n") or display_name.contains("\r") \
		or display_name.length() > 96:
		errors.append("display_name must be a 1-96 character trimmed single line")
	_validate_evidence(errors)

	_validate_range(
		errors,
		"reference_planet_radius_meters",
		reference_planet_radius_meters,
		MIN_PLANET_RADIUS_METERS,
		MAX_PLANET_RADIUS_METERS
	)
	_validate_range(
		errors,
		"minimum_elevation_meters",
		minimum_elevation_meters,
		-MAX_ABSOLUTE_ELEVATION_METERS,
		MAX_ABSOLUTE_ELEVATION_METERS
	)
	_validate_range(
		errors,
		"maximum_elevation_meters",
		maximum_elevation_meters,
		-MAX_ABSOLUTE_ELEVATION_METERS,
		MAX_ABSOLUTE_ELEVATION_METERS
	)
	if is_finite(minimum_elevation_meters) and is_finite(maximum_elevation_meters) \
		and minimum_elevation_meters >= maximum_elevation_meters:
		errors.append("minimum_elevation_meters must be less than maximum_elevation_meters")
	if is_finite(reference_planet_radius_meters) and is_finite(minimum_elevation_meters) \
		and reference_planet_radius_meters + minimum_elevation_meters <= 0.0:
		errors.append("minimum elevation must leave a positive radial surface")

	_validate_clipmap_rings(errors)
	if collision_lod_ring_index < 0 \
		or collision_lod_ring_index >= clipmap_ring_distances_meters.size():
		errors.append("collision_lod_ring_index must identify one configured clipmap ring")
	_validate_range(
		errors,
		"collision_maximum_distance_meters",
		collision_maximum_distance_meters,
		0.001,
		MAX_LOD_DISTANCE_METERS
	)
	if collision_lod_ring_index >= 0 \
		and collision_lod_ring_index < clipmap_ring_distances_meters.size() \
		and is_finite(collision_maximum_distance_meters):
		var collision_ring_limit := clipmap_ring_distances_meters[collision_lod_ring_index]
		if is_finite(collision_ring_limit) \
			and collision_maximum_distance_meters > collision_ring_limit:
			errors.append("collision distance must not exceed its selected clipmap ring")

	if not _is_power_of_two_plus_one(tile_resolution_vertices_per_edge) \
		or tile_resolution_vertices_per_edge < MIN_TILE_RESOLUTION_VERTICES_PER_EDGE \
		or tile_resolution_vertices_per_edge > MAX_TILE_RESOLUTION_VERTICES_PER_EDGE:
		errors.append("tile_resolution_vertices_per_edge must be a bounded 2^n + 1 grid")
	_validate_integer_range(
		errors,
		"maximum_visible_tile_count",
		maximum_visible_tile_count,
		1,
		MAX_VISIBLE_TILE_COUNT
	)
	_validate_integer_range(
		errors,
		"maximum_resident_tile_count",
		maximum_resident_tile_count,
		1,
		MAX_RESIDENT_TILE_COUNT
	)
	_validate_integer_range(
		errors,
		"maximum_collision_tile_count",
		maximum_collision_tile_count,
		1,
		MAX_VISIBLE_TILE_COUNT
	)
	if maximum_resident_tile_count < maximum_visible_tile_count:
		errors.append("maximum_resident_tile_count must cover maximum_visible_tile_count")
	if maximum_collision_tile_count > maximum_visible_tile_count:
		errors.append("maximum_collision_tile_count must not exceed maximum_visible_tile_count")

	_validate_biome_layers(errors)
	_validate_range(
		errors,
		"landing_site_maximum_slope_degrees",
		landing_site_maximum_slope_degrees,
		0.0,
		MAX_LANDING_SLOPE_DEGREES
	)
	_validate_range(
		errors,
		"landing_site_maximum_roughness_meters",
		landing_site_maximum_roughness_meters,
		0.0,
		MAX_LANDING_ROUGHNESS_METERS
	)
	_validate_range(
		errors,
		"origin_shift_threshold_meters",
		origin_shift_threshold_meters,
		MIN_ORIGIN_SHIFT_THRESHOLD_METERS,
		MAX_ORIGIN_SHIFT_THRESHOLD_METERS
	)
	if is_finite(origin_shift_threshold_meters) \
		and is_finite(reference_planet_radius_meters) \
		and origin_shift_threshold_meters >= reference_planet_radius_meters:
		errors.append("origin_shift_threshold_meters must be less than the planet radius reference")
	return errors


func is_profile_valid() -> bool:
	return get_validation_errors().is_empty()


func get_planet_radius_meters() -> float:
	return reference_planet_radius_meters


func get_minimum_elevation_meters() -> float:
	return minimum_elevation_meters


func get_maximum_elevation_meters() -> float:
	return maximum_elevation_meters


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


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": profile_id,
		"display_name": display_name,
		"evidence_references": evidence_references.duplicate(),
		"evidence_notes": evidence_notes,
		"planet_radius_reference": PLANET_RADIUS_REFERENCE,
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"scope": EVIDENCE_SCOPE,
			"references": evidence_references.duplicate(),
			"notes": evidence_notes,
		},
		"authority": get_authority_report(),
		"reference_planet_radius_meters": reference_planet_radius_meters,
		"minimum_elevation_meters": minimum_elevation_meters,
		"maximum_elevation_meters": maximum_elevation_meters,
		"lod_strategy": LOD_STRATEGY,
		"clipmap_ring_distances_meters": get_clipmap_ring_distances_meters(),
		"collision_lod_ring_index": collision_lod_ring_index,
		"collision_maximum_distance_meters": collision_maximum_distance_meters,
		"tile_resolution_vertices_per_edge": tile_resolution_vertices_per_edge,
		"maximum_visible_tile_count": maximum_visible_tile_count,
		"maximum_resident_tile_count": maximum_resident_tile_count,
		"maximum_collision_tile_count": maximum_collision_tile_count,
		"biome_layer_ids": get_biome_layer_ids(),
		"landing_site_maximum_slope_degrees": landing_site_maximum_slope_degrees,
		"landing_site_maximum_roughness_meters": landing_site_maximum_roughness_meters,
		"origin_shift_threshold_meters": origin_shift_threshold_meters,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors.duplicate(),
		"snapshot": get_snapshot(),
		"units": {
			"distance": DISTANCE_UNIT,
			"angle": ANGLE_UNIT,
			"tile_resolution": TILE_RESOLUTION_UNIT,
			"tile_count": TILE_COUNT_UNIT,
		},
		"lod_strategy": LOD_STRATEGY,
		"planet_radius_reference": PLANET_RADIUS_REFERENCE,
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"scope": EVIDENCE_SCOPE,
			"references": evidence_references.duplicate(),
			"notes": evidence_notes,
		},
		"authority": get_authority_report(),
		"deterministic_ordering": &"clipmap_near_to_far_biomes_declared_order",
		"terrain_renderer_authority": false,
		"terrain_generation_authority": false,
		"collision_generation_authority": false,
		"gameplay_authority": false,
		"streaming_authority": false,
		"save_authority": false,
		"network_authority": false,
		"origin_shift_authority": false,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	return audit().duplicate(true)


func _validate_clipmap_rings(errors: PackedStringArray) -> void:
	var ring_count := clipmap_ring_distances_meters.size()
	if ring_count < MIN_LOD_RING_COUNT or ring_count > MAX_LOD_RING_COUNT:
		errors.append("clipmap ring count is outside the supported range")
	var previous := 0.0
	for index in ring_count:
		var distance := clipmap_ring_distances_meters[index]
		if not is_finite(distance) or distance <= 0.0 \
			or distance > MAX_LOD_DISTANCE_METERS:
			errors.append("clipmap ring distances must be finite and bounded")
			continue
		if index > 0 and distance <= previous:
			errors.append("clipmap ring distances must be strictly increasing")
		previous = distance


func _validate_biome_layers(errors: PackedStringArray) -> void:
	if biome_layer_ids.is_empty() or biome_layer_ids.size() > MAX_BIOME_LAYER_COUNT:
		errors.append("biome layer count is outside the supported range")
	var seen := PackedStringArray()
	for layer_id in biome_layer_ids:
		if not _is_stable_id(layer_id):
			errors.append("biome layer IDs must be lowercase snake_case identifiers")
		elif seen.has(layer_id):
			errors.append("biome layer ID '%s' is duplicated" % layer_id)
		else:
			seen.append(layer_id)


static func _validate_range(
	errors: PackedStringArray,
	field_name: String,
	value: float,
	minimum: float,
	maximum: float
) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append("%s must be finite and inside [%s, %s]" % [field_name, minimum, maximum])


static func _validate_integer_range(
	errors: PackedStringArray,
	field_name: String,
	value: int,
	minimum: int,
	maximum: int
) -> void:
	if value < minimum or value > maximum:
		errors.append("%s must be inside [%d, %d]" % [field_name, minimum, maximum])


static func _validate_stable_id(
	errors: PackedStringArray,
	field_name: String,
	value: String
) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a 1-64 character lowercase snake_case identifier" % field_name)


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") \
		or value.ends_with("_") or value.contains("__"):
		return false
	var first_code := value.unicode_at(0)
	if first_code < 97 or first_code > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true


func _validate_evidence(errors: PackedStringArray) -> void:
	if evidence_notes.is_empty() or evidence_notes != evidence_notes.strip_edges():
		errors.append("evidence_notes must be non-empty and trimmed")
	if evidence_references.size() > MAX_EVIDENCE_REFERENCES:
		errors.append("evidence references must contain at most %d entries" % MAX_EVIDENCE_REFERENCES)
	var seen := PackedStringArray()
	for reference in evidence_references:
		if reference.is_empty() or reference != reference.strip_edges() \
			or reference.contains("\n") or reference.contains("\r") \
			or reference.length() > MAX_EVIDENCE_REFERENCE_LENGTH:
			errors.append("evidence references must be non-empty, trimmed, single-line, and at most %d characters" % MAX_EVIDENCE_REFERENCE_LENGTH)
		elif seen.has(reference):
			errors.append("evidence reference '%s' is duplicated" % reference)
		else:
			seen.append(reference)


static func _is_power_of_two_plus_one(value: int) -> bool:
	var edge_intervals := value - 1
	return edge_intervals > 0 and (edge_intervals & (edge_intervals - 1)) == 0
