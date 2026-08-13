class_name ShotRequest
extends RefCounted

## Typed, transport-friendly description of one authoritative hitscan request.
##
## `source_id` is the stable gameplay/network identity when one is available;
## `source_entity` supplies the live collision hierarchy that must be excluded
## from the ray. A request may use either identity, although live gameplay
## should normally provide both.

var source_entity: Node
var source_id: int = 0
var faction_id: StringName = &""
var weapon_id: StringName = &""
var sequence: int = -1
var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var range: float = 0.0
var damage: float = 0.0


func _init(
	p_source_entity: Node = null,
	p_source_id: int = 0,
	p_faction_id: StringName = &"",
	p_weapon_id: StringName = &"",
	p_sequence: int = -1,
	p_origin: Vector3 = Vector3.ZERO,
	p_direction: Vector3 = Vector3.FORWARD,
	p_range: float = 0.0,
	p_damage: float = 0.0
	) -> void:
	source_entity = p_source_entity
	source_id = p_source_id
	faction_id = p_faction_id
	weapon_id = p_weapon_id
	sequence = p_sequence
	origin = p_origin
	direction = p_direction
	range = p_range
	damage = p_damage


## Returns every malformed field so callers can log one useful rejection.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if source_id < 0:
		errors.append("source_id must not be negative")
	if source_id == 0 and not is_instance_valid(source_entity):
		errors.append("source_entity or source_id is required")
	if weapon_id.is_empty():
		errors.append("weapon_id is required")
	if sequence < 0:
		errors.append("sequence must not be negative")
	if not origin.is_finite():
		errors.append("origin must be finite")
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		errors.append("direction must be finite and non-zero")
	if not is_finite(range) or range <= 0.0:
		errors.append("range must be finite and positive")
	if not is_finite(damage) or damage <= 0.0:
		errors.append("damage must be finite and positive")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_normalized_direction() -> Vector3:
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return direction.normalized()


## Keyed strings keep the resolver ledger free of strong object references.
func get_source_key() -> String:
	if source_id > 0:
		return "source_id:%d" % source_id
	if is_instance_valid(source_entity):
		return "instance_id:%d" % source_entity.get_instance_id()
	return ""


## Stable context passed to damage components and their presentation listeners.
func get_source_context() -> Dictionary:
	return {
		"source_entity": source_entity if is_instance_valid(source_entity) else null,
		"source_id": source_id,
		"faction_id": faction_id,
		"weapon_id": weapon_id,
		"sequence": sequence,
	}
