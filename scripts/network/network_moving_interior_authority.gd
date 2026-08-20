class_name NetworkMovingInteriorAuthority
extends RefCounted

## Server-owned moving-interior occupancy and sample handoff boundary.
##
## The production MovingInteriorFrame remains responsible for the physical
## transform compensation.  This detached ledger binds an occupant to one
## frame generation and accepts only server-captured frame-local relationship
## samples.  The returned `sample_handoff` has the same shape as one trace item
## consumed by NetworkMovingInteriorLatencyValidator, so a latency observer can
## measure transport without becoming an occupancy authority.

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_moving_interior_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_FRAMES := 256
const MAX_OCCUPANTS := 1024
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _server_tick := 0
var _event_sequence := 0
var _frames: Dictionary = {}
var _occupants: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_max_tick_behind: int = DEFAULT_MAX_TICK_BEHIND,
	p_max_tick_ahead: int = DEFAULT_MAX_TICK_AHEAD
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_tick_behind = maxi(0, p_max_tick_behind)
	_max_tick_ahead = maxi(0, p_max_tick_ahead)
	_last_result = _result(false, &"uninitialized")


## Frame records are server lifecycle data. Reusing an ID requires retiring the
## old generation first, which prevents a late packet from relatching an old
## moving deck after stream replacement.
func register_frame(
	source_peer_id: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(frame_id) or not _valid_positive_integer(frame_generation):
		return _remember(_result(false, &"invalid_frame_identity"))
	if _frames.has(frame_id):
		var current := _frames[frame_id] as Dictionary
		if frame_generation < int(current.frame_generation):
			return _remember(_result(false, &"stale_frame_generation"))
		return _remember(_result(false, &"duplicate_frame"))
	if _frames.size() >= MAX_FRAMES:
		return _remember(_result(false, &"frame_capacity"))
	_frames[frame_id] = {
		"frame_id": frame_id,
		"frame_generation": frame_generation,
	}
	_event_sequence += 1
	return _remember(_result(true, &"frame_registered", {
		"frame": (_frames[frame_id] as Dictionary).duplicate(true),
	}))


## Retiring a frame is the only server operation that releases all of its
## occupants. The generation check makes this safe across re-entry.
func retire_frame(
	source_peer_id: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _frames.has(frame_id):
		return _remember(_result(false, &"unknown_frame"))
	var frame := _frames[frame_id] as Dictionary
	if int(frame.frame_generation) != frame_generation:
		return _remember(_result(false, &"stale_frame_generation"))
	var released: Array = []
	for entity_variant in _occupants.keys():
		var entity_id := StringName(entity_variant)
		var occupancy := _occupants[entity_id] as Dictionary
		if StringName(occupancy.frame_id) != frame_id:
			continue
		released.append(occupancy.duplicate(true))
		_occupants.erase(entity_id)
	_frames.erase(frame_id)
	_event_sequence += 1
	return _remember(_result(true, &"frame_retired", {
		"frame_id": frame_id,
		"frame_generation": frame_generation,
		"released_occupancies": released,
	}))


func set_server_tick(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	return _remember(_result(true, &"server_tick_advanced", {"server_tick": _server_tick}))


## Occupancy is established only after the production adapter has validated the
## physical overlap/boarding result. This method never looks up a node or
## accepts a client transform.
func register_occupancy(
	source_peer_id: int,
	peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	frame_id: StringName,
	frame_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0 or not _valid_id(entity_id) or not _valid_positive_integer(entity_generation):
		return _remember(_result(false, &"invalid_occupant_identity"))
	if not _frames.has(frame_id):
		return _remember(_result(false, &"unknown_frame"))
	var frame := _frames[frame_id] as Dictionary
	if int(frame.frame_generation) != frame_generation:
		return _remember(_result(false, &"stale_frame_generation"))
	if _occupants.has(entity_id):
		var current := _occupants[entity_id] as Dictionary
		if entity_generation < int(current.entity_generation):
			return _remember(_result(false, &"stale_entity_generation"))
		return _remember(_result(false, &"duplicate_occupancy"))
	if _occupants.size() >= MAX_OCCUPANTS:
		return _remember(_result(false, &"occupancy_capacity"))
	_occupants[entity_id] = {
		"peer_id": peer_id,
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"frame_id": frame_id,
		"frame_generation": frame_generation,
		"last_sample_tick": -1,
		"last_arrival_time_seconds": -1.0,
		"sample_count": 0,
	}
	_event_sequence += 1
	return _remember(_result(true, &"occupancy_registered", {
		"occupancy": (_occupants[entity_id] as Dictionary).duplicate(true),
	}))


## Accepts one server-captured relationship sample and hands it to the
## latency observer. Arrival time is transport instrumentation supplied by the
## server adapter; clients cannot submit this packet because the source must
## be the authority peer.
func handoff_latency_sample(source_peer_id: int, sample: Dictionary) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _has_exact_sample_keys(sample):
		return _remember(_result(false, &"invalid_sample_schema"))
	var arrival_time := float(sample.get("arrival_time_seconds", NAN))
	if not is_finite(arrival_time) or arrival_time < 0.0:
		return _remember(_result(false, &"invalid_arrival_time"))
	var raw_snapshot: Variant = sample.get("snapshot")
	if not raw_snapshot is Dictionary:
		return _remember(_result(false, &"invalid_sample_snapshot"))
	var relationship = Relationship.from_dictionary(raw_snapshot as Dictionary)
	if not relationship.is_valid():
		return _remember(_result(false, &"invalid_relationship", {
			"errors": relationship.get_validation_errors(),
		}))
	var entity_id := relationship.get_entity_id()
	if not _occupants.has(entity_id):
		return _remember(_result(false, &"stale_occupancy"))
	var occupancy := _occupants[entity_id] as Dictionary
	var generation_status := _validate_occupancy_generation(occupancy, relationship)
	if not generation_status.is_empty():
		return _remember(_result(false, generation_status))
	var sample_tick := relationship.get_server_tick()
	var last_sample_tick := int(occupancy.last_sample_tick)
	if sample_tick <= last_sample_tick:
		return _remember(_result(false, &"stale_occupancy_tick"))
	if sample_tick < _server_tick - _max_tick_behind:
		return _remember(_result(false, &"sample_tick_too_old"))
	if sample_tick > _server_tick + _max_tick_ahead:
		return _remember(_result(false, &"sample_tick_too_far_ahead"))
	occupancy.last_sample_tick = sample_tick
	occupancy.last_arrival_time_seconds = arrival_time
	occupancy.sample_count = int(occupancy.sample_count) + 1
	_event_sequence += 1
	var detached_snapshot := relationship.get_snapshot()
	var handoff := {
		"snapshot": detached_snapshot,
		"arrival_time_seconds": arrival_time,
	}
	return _remember(_result(true, &"sample_handed_off", {
		"sample_handoff": handoff,
		"occupancy": occupancy.duplicate(true),
	}))


func retire_occupancy(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _occupants.has(entity_id):
		return _remember(_result(false, &"unknown_occupancy"))
	var occupancy := _occupants[entity_id] as Dictionary
	if int(occupancy.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	_occupants.erase(entity_id)
	_event_sequence += 1
	return _remember(_result(true, &"occupancy_retired", {
		"occupancy": occupancy.duplicate(true),
	}))


func release_peer(source_peer_id: int, peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	var released: Array = []
	for entity_variant in _occupants.keys():
		var entity_id := StringName(entity_variant)
		var occupancy := _occupants[entity_id] as Dictionary
		if int(occupancy.peer_id) != peer_id:
			continue
		released.append(occupancy.duplicate(true))
		_occupants.erase(entity_id)
	if not released.is_empty():
		_event_sequence += 1
	return _remember(_result(true, &"peer_released", {"occupancies": released}))


func get_occupancy(entity_id: StringName) -> Dictionary:
	return (_occupants.get(entity_id, {}) as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var frames: Array = []
	for value in _frames.values():
		frames.append((value as Dictionary).duplicate(true))
	frames.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("frame_id", "")) < str(right.get("frame_id", ""))
	)
	var occupancies: Array = []
	for value in _occupants.values():
		occupancies.append((value as Dictionary).duplicate(true))
	occupancies.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("entity_id", "")) < str(right.get("entity_id", ""))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"server_tick": _server_tick,
		"event_sequence": _event_sequence,
		"frames": frames,
		"occupancies": occupancies,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_frame_generation": true,
		"server_owns_occupancy": true,
		"stale_occupancy_rejected": true,
		"latency_sample_handoff": true,
		"client_can_mutate_occupancy": false,
		"owns_physical_compensation": false,
		"owns_movement": false,
		"registered_frame_count": _frames.size(),
		"occupied_entity_count": _occupants.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_occupancy_generation(occupancy: Dictionary, relationship) -> StringName:
	if relationship.get_entity_generation() != int(occupancy.entity_generation):
		return &"stale_entity_generation" \
			if relationship.get_entity_generation() < int(occupancy.entity_generation) \
			else &"future_entity_generation"
	if relationship.get_parent_frame_id() != StringName(occupancy.frame_id):
		return &"frame_mismatch"
	if relationship.get_parent_frame_generation() != int(occupancy.frame_generation):
		return &"stale_frame_generation" \
			if relationship.get_parent_frame_generation() < int(occupancy.frame_generation) \
			else &"future_frame_generation"
	return &""


func _has_exact_sample_keys(sample: Dictionary) -> bool:
	return sample.size() == 2 and sample.has("snapshot") and sample.has("arrival_time_seconds")


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, payload: Dictionary = {}) -> Dictionary:
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"status": status,
		"event_sequence": _event_sequence,
	}
	for key in payload:
		result[key] = payload[key]
	return result.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result.duplicate(true)
