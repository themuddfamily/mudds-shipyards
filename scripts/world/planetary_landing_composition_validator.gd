class_name PlanetaryLandingCompositionValidator
extends RefCounted

## Pure join between one composed planetary world, its terrain datum, one
## detached coordinate-frame snapshot, and one landing-region definition.
## This validator retains no inputs and grants no runtime authority.

const CoordinateFrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")

const SCHEMA_VERSION := 1
const RADIUS_DATUM: StringName = &"body_center_to_sea_level"
const FRAME_SEAM: StringName = &"landing_region_via_planetary_body_local"

const _FRAME_SNAPSHOT_KEYS := [
	"schema_version", "configured", "body_id", "orbital_frame_id",
	"meters_per_world_unit", "body_radius_meters", "orbital_cell_size_meters",
	"body_center_orbital_coordinate", "surface_reference_direction",
	"surface_reference_body_local", "surface_north_direction",
	"surface_tangent_basis", "origin_shift_threshold_meters",
	"world_streaming_origin_orbital_coordinate", "generation", "pending_rebase",
	"last_rebase_result", "rebase_request_count", "rebase_commit_count",
	"rebase_cancel_count",
]


func validate_composition(
		world: PlanetaryWorldDefinition,
		terrain: PlanetaryTerrainProfile,
		coordinate_frame_snapshot: Dictionary,
		region: PlanetaryLandingRegionDefinition
	) -> Dictionary:
	var errors: Array[Dictionary] = []
	var world_valid := world != null and world.is_definition_valid()
	var terrain_valid := terrain != null and terrain.is_profile_valid()
	var frame_valid := _is_valid_frame_snapshot(coordinate_frame_snapshot)
	var region_valid := region != null and region.is_definition_valid()

	if world == null:
		_append_error(errors, &"missing_world_definition", &"world", "a planetary world definition is required")
	elif not world_valid:
		_append_error(errors, &"invalid_world_definition", &"world", "the planetary world definition is invalid")
	if terrain == null:
		_append_error(errors, &"missing_terrain_profile", &"terrain", "a resolved terrain profile is required")
	elif not terrain_valid:
		_append_error(errors, &"invalid_terrain_profile", &"terrain", "the resolved terrain profile is invalid")
	if coordinate_frame_snapshot.is_empty():
		_append_error(errors, &"missing_coordinate_frame_snapshot", &"coordinate_frame_snapshot", "a detached configured coordinate-frame snapshot is required")
	elif not frame_valid:
		_append_error(errors, &"invalid_coordinate_frame_snapshot", &"coordinate_frame_snapshot", "the coordinate-frame snapshot is malformed or unconfigured")
	if region == null:
		_append_error(errors, &"missing_landing_region", &"region", "a landing-region definition is required")
	elif not region_valid:
		_append_error(errors, &"invalid_landing_region", &"region", "the landing-region definition is invalid")

	if world_valid and region_valid:
		if region.world_id != world.world_id:
			_append_error(errors, &"landing_world_id_mismatch", &"world_id", "landing-region world ID must equal the resolved world ID")
		if not world.landing_region_ids.has(str(region.region_id)):
			_append_error(errors, &"landing_region_not_referenced", &"region_id", "the resolved world must reference the landing-region ID")
	if world_valid and terrain_valid \
			and world.terrain_definition_id != terrain.profile_id:
		_append_error(errors, &"landing_terrain_profile_id_mismatch", &"terrain_definition_id", "the world terrain ID must equal the resolved terrain profile ID")
	if frame_valid and region_valid:
		if region.body_id != coordinate_frame_snapshot.get("body_id", &""):
			_append_error(errors, &"landing_body_id_mismatch", &"body_id", "landing-region body ID must equal the coordinate-frame body ID")
	if region != null and not _basis_is_radially_outward(
		region.body_local_basis, region.body_local_center_m
	):
		_append_error(errors, &"landing_basis_not_radially_outward", &"body_local_basis", "landing-region basis +Y must align with its outward radial normal")

	if world_valid and terrain_valid and frame_valid and region_valid:
		var world_radius := world.get_body_radius_meters()
		if world_radius != terrain.get_planet_radius_meters() \
				or world_radius != float(coordinate_frame_snapshot.get("body_radius_meters", 0.0)) \
				or world_radius != region.body_radius_m:
			_append_error(errors, &"landing_body_radius_mismatch", &"body_radius_m", "world, terrain, coordinate frame, and landing region must share one exact sea-level radius")
		if region.minimum_elevation_m != terrain.get_minimum_elevation_meters():
			_append_error(errors, &"landing_minimum_elevation_mismatch", &"minimum_elevation_m", "landing and terrain minimum elevations must be exactly equal")
		if region.maximum_elevation_m != terrain.get_maximum_elevation_meters():
			_append_error(errors, &"landing_maximum_elevation_mismatch", &"maximum_elevation_m", "landing and terrain maximum elevations must be exactly equal")

	var error_codes := PackedStringArray()
	for error in errors:
		error_codes.append(str(error.get("code", &"unknown_error")))
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"error_codes": error_codes,
		"world_id": world.world_id if world != null else &"",
		"body_id": region.body_id if region != null else &"",
		"region_id": region.region_id if region != null else &"",
		"terrain_profile_id": terrain.profile_id if terrain != null else &"",
		"coordinate_frame_generation": int(coordinate_frame_snapshot.get("generation", 0)),
		"radius_datum": RADIUS_DATUM,
		"frame_seam": FRAME_SEAM,
		"body_radius_meters": world.get_body_radius_meters() if world != null else 0.0,
		"region_center_body_local_meters": region.body_local_center_m if region != null else Vector3.ZERO,
		"evidence": _evidence_snapshot(world, terrain, region),
		"authority": get_authority_report(),
	}.duplicate(true)


func audit(
		world: PlanetaryWorldDefinition,
		terrain: PlanetaryTerrainProfile,
		coordinate_frame_snapshot: Dictionary,
		region: PlanetaryLandingRegionDefinition
	) -> Dictionary:
	return validate_composition(
		world, terrain, coordinate_frame_snapshot, region
	).duplicate(true)


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


static func _is_valid_frame_snapshot(snapshot: Dictionary) -> bool:
	if not _has_exact_string_keys(snapshot, _FRAME_SNAPSHOT_KEYS):
		return false
	if not snapshot.schema_version is int \
			or int(snapshot.schema_version) != CoordinateFrameScript.SCHEMA_VERSION \
			or not snapshot.configured is bool or not bool(snapshot.configured):
		return false
	if not snapshot.body_id is StringName or not _is_stable_id(str(snapshot.body_id)) \
			or not snapshot.orbital_frame_id is StringName \
			or not _is_stable_id(str(snapshot.orbital_frame_id)):
		return false
	if not _is_finite_number(snapshot.meters_per_world_unit) \
			or float(snapshot.meters_per_world_unit) != CoordinateFrameScript.METERS_PER_WORLD_UNIT \
			or not _is_finite_number(snapshot.body_radius_meters) \
			or float(snapshot.body_radius_meters) < CoordinateFrameScript.MIN_BODY_RADIUS_METERS \
			or float(snapshot.body_radius_meters) > CoordinateFrameScript.MAX_BODY_RADIUS_METERS \
			or not _is_finite_number(snapshot.orbital_cell_size_meters) \
			or float(snapshot.orbital_cell_size_meters) < CoordinateFrameScript.MIN_ORBITAL_CELL_SIZE_METERS \
			or float(snapshot.orbital_cell_size_meters) > CoordinateFrameScript.MAX_ORBITAL_CELL_SIZE_METERS:
		return false
	if not snapshot.generation is int or int(snapshot.generation) < 1 \
			or int(snapshot.generation) > CoordinateFrameScript.MAX_GENERATION:
		return false
	if not snapshot.body_center_orbital_coordinate is Dictionary \
			or not snapshot.world_streaming_origin_orbital_coordinate is Dictionary \
			or not snapshot.pending_rebase is Dictionary \
			or not snapshot.last_rebase_result is Dictionary:
		return false
	var cell_size := float(snapshot.orbital_cell_size_meters)
	var frame_id := snapshot.orbital_frame_id as StringName
	if not _is_valid_orbital_coordinate(
		snapshot.body_center_orbital_coordinate as Dictionary, frame_id, cell_size
	) or not _is_valid_orbital_coordinate(
		snapshot.world_streaming_origin_orbital_coordinate as Dictionary,
		frame_id,
		cell_size
	):
		return false
	if not snapshot.surface_reference_direction is Vector3 \
			or not snapshot.surface_reference_body_local is Vector3 \
			or not snapshot.surface_north_direction is Vector3 \
			or not snapshot.surface_tangent_basis is Basis:
		return false
	var up := snapshot.surface_reference_direction as Vector3
	var reference := snapshot.surface_reference_body_local as Vector3
	var north := snapshot.surface_north_direction as Vector3
	var basis := snapshot.surface_tangent_basis as Basis
	if not up.is_finite() or not north.is_finite() or not reference.is_finite() \
			or not up.is_normalized() or not north.is_normalized() \
			or not is_zero_approx(up.dot(north)) or not basis.is_finite() \
			or not basis.is_orthonormal() or basis.determinant() <= 0.0 \
			or not basis.x.is_equal_approx(north.cross(up).normalized()) \
			or not basis.y.is_equal_approx(up) or not basis.z.is_equal_approx(-north) \
			or not reference.is_equal_approx(up * float(snapshot.body_radius_meters)):
		return false
	if not _is_finite_number(snapshot.origin_shift_threshold_meters) \
			or float(snapshot.origin_shift_threshold_meters) \
				< CoordinateFrameScript.MIN_ORIGIN_SHIFT_THRESHOLD_METERS \
			or float(snapshot.origin_shift_threshold_meters) \
				> CoordinateFrameScript.MAX_ORIGIN_SHIFT_THRESHOLD_METERS:
		return false
	for key in ["rebase_request_count", "rebase_commit_count", "rebase_cancel_count"]:
		if not snapshot[key] is int or int(snapshot[key]) < 0:
			return false
	if int(snapshot.rebase_commit_count) > int(snapshot.rebase_request_count) \
			or int(snapshot.rebase_cancel_count) > int(snapshot.rebase_request_count) \
			or int(snapshot.rebase_commit_count) + int(snapshot.rebase_cancel_count) \
				> int(snapshot.rebase_request_count):
		return false
	return true


static func _is_valid_orbital_coordinate(
		coordinate: Dictionary, expected_frame_id: StringName, cell_size: float
	) -> bool:
	var expected_keys := [
		"schema_version", "frame_id", "cell_x", "cell_y", "cell_z",
		"offset_meters",
	]
	if not _has_exact_string_keys(coordinate, expected_keys) \
			or not coordinate.schema_version is int \
			or int(coordinate.schema_version) \
				!= CoordinateFrameScript.COORDINATE_SCHEMA_VERSION \
			or not coordinate.frame_id is StringName \
			or coordinate.frame_id != expected_frame_id:
		return false
	for key in ["cell_x", "cell_y", "cell_z"]:
		if not coordinate[key] is int \
				or absi(int(coordinate[key])) > CoordinateFrameScript.MAX_SAFE_INTEGER:
			return false
	if not coordinate.offset_meters is Vector3:
		return false
	var offset := coordinate.offset_meters as Vector3
	var half_cell := cell_size * 0.5
	return offset.is_finite() \
		and offset.x >= -half_cell and offset.x < half_cell \
		and offset.y >= -half_cell and offset.y < half_cell \
		and offset.z >= -half_cell and offset.z < half_cell


static func _basis_is_radially_outward(basis: Basis, center: Vector3) -> bool:
	return center.is_finite() and not center.is_zero_approx() and basis.is_finite() \
		and basis.y.dot(center.normalized()) >= 1.0 - 0.0001


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	return true


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") \
			or value.ends_with("_") or value.contains("__"):
		return false
	var first := value.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) \
				and not (code >= 48 and code <= 57) and code != 95:
			return false
	return true


static func _evidence_snapshot(
		world: PlanetaryWorldDefinition,
		terrain: PlanetaryTerrainProfile,
		region: PlanetaryLandingRegionDefinition
	) -> Dictionary:
	return {
		"world": (world.audit().get("evidence", {}) as Dictionary).duplicate(true) if world != null else {},
		"terrain": (terrain.audit().get("evidence", {}) as Dictionary).duplicate(true) if terrain != null else {},
		"landing_region": region.get_evidence_snapshot() if region != null else {},
	}.duplicate(true)


static func _append_error(
		errors: Array[Dictionary],
		code: StringName,
		field: StringName,
		message: String
	) -> void:
	errors.append({"code": code, "field": field, "message": message})
