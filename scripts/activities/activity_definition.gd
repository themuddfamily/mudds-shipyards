class_name ActivityDefinition
extends Resource

## Declarative contract for an activity. Runtime state belongs to an activity
## instance, never this shared resource.

const SCHEMA_VERSION := 1
const ACTIVITY_KIND_CHECKPOINT_ROUTE: StringName = &"checkpoint_route"

@export_category("Identity")
@export var activity_id: StringName = &"unnamed_activity"
@export var display_name := "Unnamed activity"
@export var activity_kind: StringName = ACTIVITY_KIND_CHECKPOINT_ROUTE
@export_multiline var content_note := ""

@export_category("Location")
@export var location: WorldLocationDefinition

@export_category("Checkpoint route")
@export var checkpoint_positions := PackedVector3Array()
@export_range(0.1, 500.0, 0.1) var checkpoint_radius := 32.0


func get_checkpoint_count() -> int:
	return checkpoint_positions.size()


func get_checkpoint_position(index: int) -> Vector3:
	if index < 0 or index >= checkpoint_positions.size():
		return Vector3.INF
	return checkpoint_positions[index]


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	WorldLocationDefinition._validate_stable_id(errors, "activity_id", str(activity_id))
	if display_name.is_empty() or display_name != display_name.strip_edges() \
		or display_name.contains("\n") or display_name.contains("\r"):
		errors.append("display_name must be non-empty, trimmed, and single-line")
	if activity_kind != ACTIVITY_KIND_CHECKPOINT_ROUTE:
		errors.append("activity_kind must be checkpoint_route")
	if content_note.is_empty() or content_note != content_note.strip_edges():
		errors.append("content_note must be non-empty and trimmed")
	if location == null:
		errors.append("location is required")
	elif not location.is_definition_valid():
		errors.append("location definition is invalid")
	if checkpoint_positions.is_empty():
		errors.append("checkpoint_route requires at least one checkpoint")
	if not is_finite(checkpoint_radius) or checkpoint_radius <= 0.0:
		errors.append("checkpoint_radius must be finite and greater than zero")
	for position in checkpoint_positions:
		if not WorldLocationDefinition._is_finite_vector(position):
			errors.append("checkpoint positions must be finite")
			break
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func audit() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"activity_id": activity_id,
		"display_name": display_name,
		"activity_kind": activity_kind,
		"location_id": location.location_id if location != null else &"",
		"checkpoint_count": checkpoint_positions.size(),
		"checkpoint_radius": checkpoint_radius,
		"gameplay_authority": false,
		"grants_rewards": false,
		"ship_authority": false,
		"berth_authority": false,
	}
