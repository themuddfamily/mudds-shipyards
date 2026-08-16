class_name WorldLocationDefinition
extends Resource

## Side-effect-free identity and navigation anchor for a named world location.
##
## A location definition deliberately describes a place, not what happens there.
## It has no scene-node dependency and grants no reward, ship, berth, or mission
## authority; consumers may use its stable anchor for presentation or activities.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

@export_category("Identity")
@export var location_id: StringName = &"unnamed_location"
@export var display_name := "Unnamed location"
@export var sector_id: StringName = &"unnamed_sector"
@export_multiline var content_note := ""

@export_category("Anchor")
@export var anchor_source_id: StringName = &"unspecified_anchor"
@export var anchor_position := Vector3.ZERO


func get_anchor_position() -> Vector3:
	return anchor_position


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_stable_id(errors, "location_id", str(location_id))
	_validate_stable_id(errors, "sector_id", str(sector_id))
	_validate_stable_id(errors, "anchor_source_id", str(anchor_source_id))
	if display_name.is_empty() or display_name != display_name.strip_edges() \
		or display_name.contains("\n") or display_name.contains("\r"):
		errors.append("display_name must be non-empty, trimmed, and single-line")
	if content_note.is_empty() or content_note != content_note.strip_edges():
		errors.append("content_note must be non-empty and trimmed")
	if not _is_finite_vector(anchor_position):
		errors.append("anchor_position must be finite")
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"location_id": location_id,
		"display_name": display_name,
		"sector_id": sector_id,
		"anchor_source_id": anchor_source_id,
		"anchor_position": anchor_position,
		"evidence_status": EVIDENCE_STATUS,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
	}


static func _validate_stable_id(errors: PackedStringArray, field_name: String, value: String) -> void:
	if not _is_stable_id(value):
		errors.append("%s must be a 1-64 character lowercase snake_case identifier" % field_name)


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") or value.ends_with("_") \
		or value.contains("__"):
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
