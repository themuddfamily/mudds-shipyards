class_name NearbySectorOrbitalRegistry
extends RefCounted

## Immutable, authority-free absolute-cell datum for the nearby sector.
##
## The station entry is only a coordinate reference. It does not claim a live
## ShipyardWorld node, Cinder Reach, SpaceBackdrop, or production integration.

const SCHEMA_VERSION := 1
const COORDINATE_SCHEMA_VERSION := 1
const REGISTRY_ID: StringName = &"nearby_sector_orbital_registry"
const FRAME_ID: StringName = &"nearby_sector_orbital"
const STATION_DATUM_ID: StringName = &"shipyard_station_datum"
const EMBER_BODY_CENTER_ID: StringName = &"ember_body_center"
const EMBER_WORLD_ID: StringName = &"ember_moon"
const EMBER_BODY_ID: StringName = &"ember_body"
const CELL_SIZE_METERS := 1_000_000.0
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_RELATIVE_COMPONENT_METERS := 1_000_000_000.0

const COMMON_AUTHORITY_KEYS := [
	"renderer",
	"gameplay",
	"streaming",
	"save",
	"network",
	"physics",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"origin_shift",
	"weather_clock",
	"audio",
]

const _COORDINATE_KEYS := [
	"schema_version", "frame_id", "cell_x", "cell_y", "cell_z", "offset_meters",
]


func get_coordinate(point_id: StringName) -> Dictionary:
	match point_id:
		STATION_DATUM_ID:
			return _coordinate(0, 0, 0, Vector3.ZERO)
		EMBER_BODY_CENTER_ID:
			return _coordinate(0, 0, -8, Vector3.ZERO)
		_:
			return {}


func get_point_ids() -> PackedStringArray:
	return PackedStringArray([str(EMBER_BODY_CENTER_ID), str(STATION_DATUM_ID)])


func validate_coordinate(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return _result(false, &"coordinate_not_dictionary")
	var coordinate := candidate as Dictionary
	if not _has_exact_string_keys(coordinate, _COORDINATE_KEYS):
		return _result(false, &"coordinate_schema_mismatch")
	if not coordinate.schema_version is int \
			or int(coordinate.schema_version) != COORDINATE_SCHEMA_VERSION:
		return _result(false, &"coordinate_version_mismatch")
	if not coordinate.frame_id is StringName or coordinate.frame_id != FRAME_ID:
		return _result(false, &"coordinate_frame_mismatch")
	for key in ["cell_x", "cell_y", "cell_z"]:
		if not coordinate[key] is int or not _is_safe_integer(int(coordinate[key])):
			return _result(false, &"coordinate_cell_out_of_bounds")
	if not coordinate.offset_meters is Vector3:
		return _result(false, &"coordinate_offset_type_mismatch")
	var offset := coordinate.offset_meters as Vector3
	var half_cell := CELL_SIZE_METERS * 0.5
	if not offset.is_finite() or offset.x < -half_cell or offset.x >= half_cell \
			or offset.y < -half_cell or offset.y >= half_cell \
			or offset.z < -half_cell or offset.z >= half_cell:
		return _result(false, &"coordinate_offset_not_canonical")
	return _result(true, &"valid_coordinate", {"coordinate": coordinate.duplicate(true)})


func relative_position_meters(from_point_id: StringName, to_point_id: StringName) -> Dictionary:
	var from_coordinate := get_coordinate(from_point_id)
	var to_coordinate := get_coordinate(to_point_id)
	if from_coordinate.is_empty() or to_coordinate.is_empty():
		return _result(false, &"unknown_point")
	var components := []
	for key in ["cell_x", "cell_y", "cell_z"]:
		var cell_delta := int(to_coordinate[key]) - int(from_coordinate[key])
		var component := float(cell_delta) * CELL_SIZE_METERS
		if not is_finite(component) or absf(component) > MAX_RELATIVE_COMPONENT_METERS:
			return _result(false, &"relative_position_out_of_bounds")
		components.append(component)
	var position := Vector3(components[0], components[1], components[2]) \
		+ (to_coordinate.offset_meters as Vector3) \
		- (from_coordinate.offset_meters as Vector3)
	if not position.is_finite() \
			or absf(position.x) > MAX_RELATIVE_COMPONENT_METERS \
			or absf(position.y) > MAX_RELATIVE_COMPONENT_METERS \
			or absf(position.z) > MAX_RELATIVE_COMPONENT_METERS:
		return _result(false, &"relative_position_out_of_bounds")
	return _result(true, &"relative_position", {
		"from_point_id": from_point_id,
		"to_point_id": to_point_id,
		"position_meters": position,
	})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"registry_id": REGISTRY_ID,
		"frame_id": FRAME_ID,
		"cell_size_meters": CELL_SIZE_METERS,
		"point_ids": get_point_ids(),
		"station_datum_id": STATION_DATUM_ID,
		"station_coordinate": get_coordinate(STATION_DATUM_ID),
		"ember_body_center_id": EMBER_BODY_CENTER_ID,
		"ember_world_id": EMBER_WORLD_ID,
		"ember_body_id": EMBER_BODY_ID,
		"ember_body_center_coordinate": get_coordinate(EMBER_BODY_CENTER_ID),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var station_validation := validate_coordinate(get_coordinate(STATION_DATUM_ID))
	var ember_validation := validate_coordinate(get_coordinate(EMBER_BODY_CENTER_ID))
	var placement := relative_position_meters(STATION_DATUM_ID, EMBER_BODY_CENTER_ID)
	if not bool(station_validation.get("accepted", false)):
		errors.append("station datum is invalid")
	if not bool(ember_validation.get("accepted", false)):
		errors.append("Ember body-centre datum is invalid")
	if not bool(placement.get("accepted", false)) \
			or placement.get("position_meters") != Vector3(0.0, 0.0, -8_000_000.0):
		errors.append("Ember must remain exactly 8,000 km on station-relative -Z")
	var authority := {}
	for key in COMMON_AUTHORITY_KEYS:
		authority[key] = false
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"evidence": {
			"content_class": &"orbital_placement_datum",
			"status": &"new",
			"scope": &"modern_interpretation",
			"references": PackedStringArray([
				"res://docs/EMBER_MOON_ORBITAL_STREAMING.md",
			]),
			"notes": "Original round-number game-scale placement; not recovered historical, backdrop, or Cinder evidence.",
		},
		"authority": authority,
	}.duplicate(true)


func _coordinate(cell_x: int, cell_y: int, cell_z: int, offset: Vector3) -> Dictionary:
	return {
		"schema_version": COORDINATE_SCHEMA_VERSION,
		"frame_id": FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


static func _is_safe_integer(value: int) -> bool:
	return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	return true
