class_name NetworkMovingInteriorRelationshipValidator
extends RefCounted

## Server-authority gate for relationships arriving at a replica.
## Packet gaps are observable and tolerated; stale generations, reordering,
## duplicate ticks, and non-authoritative senders are rejected.

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _authority_peer_id := 1
var _latest_by_entity: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = p_authority_peer_id


func accept(source_peer_id: int, raw_snapshot: Dictionary) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _rejection(&"unauthorized_sender")
	var relationship: NetworkMovingInteriorRelationship = Relationship.from_dictionary(raw_snapshot)
	if not relationship.is_valid():
		return _rejection(&"invalid_snapshot", relationship.get_validation_errors())
	var entity_id := relationship.get_entity_id()
	var previous: Dictionary = _latest_by_entity.get(entity_id, {})
	if not previous.is_empty():
		var previous_generation := int(previous.get("entity_generation", 0))
		if relationship.get_entity_generation() < previous_generation:
			return _rejection(&"stale_entity_generation")
		if relationship.get_entity_generation() == previous_generation:
			var previous_tick := int(previous.get("server_tick", -1))
			if relationship.get_server_tick() <= previous_tick:
				return _rejection(&"stale_or_duplicate_tick")
			var previous_frame_generation := int(previous.get("parent_frame_generation", 0))
			if relationship.get_parent_frame_id() == StringName(previous.get("parent_frame_id", &"")) \
				and relationship.get_parent_frame_generation() < previous_frame_generation:
				return _rejection(&"stale_frame_generation")
	var gap_detected := false
	if not previous.is_empty() and relationship.get_entity_generation() == int(previous.get("entity_generation", 0)):
		gap_detected = relationship.get_server_tick() > int(previous.get("server_tick", 0)) + 1
	_latest_by_entity[entity_id] = relationship.get_snapshot()
	return {
		"accepted": true,
		"status": &"accepted",
		"snapshot": relationship.get_snapshot(),
		"gap_detected": gap_detected,
		"validation_errors": PackedStringArray(),
	}


func get_latest(entity_id: StringName) -> Dictionary:
	return (_latest_by_entity.get(entity_id, {}) as Dictionary).duplicate(true)


func resolve_world_transform(entity_id: StringName, frame_world_transform: Transform3D) -> Transform3D:
	var latest := get_latest(entity_id)
	if latest.is_empty():
		return Transform3D.IDENTITY
	return Relationship.from_dictionary(latest).resolve_world_transform(frame_world_transform)


func retire(entity_id: StringName) -> bool:
	return _latest_by_entity.erase(entity_id)


func clear() -> void:
	_latest_by_entity.clear()


func audit() -> Dictionary:
	return {
		"authority_peer_id": _authority_peer_id,
		"tracked_entities": _latest_by_entity.size(),
		"packet_gaps_are_tolerated": true,
		"stale_generations_rejected": true,
		"replica_mutates_authority": false,
	}.duplicate(true)


func _rejection(status: StringName, errors: PackedStringArray = PackedStringArray()) -> Dictionary:
	return {
		"accepted": false,
		"status": status,
		"snapshot": {},
		"gap_detected": false,
		"validation_errors": errors.duplicate(),
	}
