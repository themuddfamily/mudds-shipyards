class_name NetworkMovingInteriorRelationshipStream
extends RefCounted

## Runtime presentation gate for delayed moving-interior relationships.
## The server remains the only source of accepted samples; a long tick gap
## freezes the last resolved pose until ordered updates resume.

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const MAX_TRACKED_ENTITIES := 128
const DEFAULT_MAX_HOLD_TICKS := 15

var _authority_peer_id := 1
var _max_hold_ticks := DEFAULT_MAX_HOLD_TICKS
var _migration_generation := 1
var _last_ticks: Dictionary = {}
var _current: Dictionary = {}
var _pending: Dictionary = {}
var _frozen: Dictionary = {}
var _last_result: Dictionary = {}


func _init(p_authority_peer_id: int = 1, p_max_hold_ticks: int = DEFAULT_MAX_HOLD_TICKS) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_hold_ticks = clampi(p_max_hold_ticks, 1, 120)


func accept_snapshot(source_peer_id: int, snapshot: Dictionary, migration_generation: int = 1) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if migration_generation != _migration_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	var relationship := Relationship.from_dictionary(snapshot)
	if not relationship.is_valid():
		return _remember(_result(false, &"invalid_relationship"))
	var entity_id := relationship.get_entity_id()
	var tick := relationship.get_server_tick()
	var previous_tick := int(_last_ticks.get(entity_id, -1))
	if previous_tick >= 0 and tick <= previous_tick:
		return _remember(_result(false, &"stale_or_reordered_tick"))
	if not _last_ticks.has(entity_id) and _last_ticks.size() >= MAX_TRACKED_ENTITIES:
		return _remember(_result(false, &"entity_capacity"))
	var gap := tick - previous_tick if previous_tick >= 0 else 0
	_last_ticks[entity_id] = tick
	if gap > _max_hold_ticks and _current.has(entity_id):
		_pending[entity_id] = relationship
		_frozen[entity_id] = true
		return _remember(_result(true, &"gap_hold", {"entity_id": entity_id, "gap_ticks": gap, "frozen": true}))
	_current[entity_id] = relationship
	_pending.erase(entity_id)
	var resumed := bool(_frozen.get(entity_id, false))
	_frozen.erase(entity_id)
	return _remember(_result(true, &"resumed" if resumed else &"accepted", {
		"entity_id": entity_id, "tick": tick, "resumed": resumed, "frozen": false,
	}))


func get_presentation(entity_id: StringName, frame_world_transform: Transform3D) -> Dictionary:
	if not _current.has(entity_id):
		return _result(false, &"entity_not_tracked")
	var relationship := _current[entity_id] as Relationship
	return _result(true, &"frozen" if bool(_frozen.get(entity_id, false)) else &"current", {
		"entity_id": entity_id,
		"frozen": bool(_frozen.get(entity_id, false)),
		"transform": relationship.resolve_world_transform(frame_world_transform),
	})


func reset_migration(source_peer_id: int, migration_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if migration_generation <= _migration_generation:
		return _remember(_result(false, &"stale_migration_generation"))
	_migration_generation = migration_generation
	_last_ticks.clear()
	_current.clear()
	_pending.clear()
	_frozen.clear()
	return _remember(_result(true, &"migration_reset"))


func get_snapshot() -> Dictionary:
	return {
		"migration_generation": _migration_generation,
		"tracked_entities": _current.size(),
		"frozen_entities": _frozen.size(),
		"max_hold_ticks": _max_hold_ticks,
	}.duplicate(true)


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
