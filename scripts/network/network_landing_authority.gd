class_name NetworkLandingAuthority
extends RefCounted

## Server-owned landing lease and respawn transition boundary.
##
## This detached contract does not move a ship, test collision, choose a
## landing pose, or instantiate a respawn. A production adapter validates those
## facts and commits the returned lease/token. Clients can request a target,
## but cannot claim occupancy, coordinates, or the next lifecycle generation.

const Intent := preload("res://scripts/network/network_landing_intent.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_landing_respawn_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2
const MAX_ENTITIES := 256
const MAX_TARGETS := 256

const STATE_FLYING: StringName = &"flying"
const STATE_LANDING_PENDING: StringName = &"landing_pending"
const STATE_LANDED: StringName = &"landed"
const STATE_DESTROYED: StringName = &"destroyed"
const STATE_RESPAWN_PENDING: StringName = &"respawn_pending"
const STATES := [STATE_FLYING, STATE_LANDING_PENDING, STATE_LANDED, STATE_DESTROYED, STATE_RESPAWN_PENDING]

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _server_tick := 0
var _event_sequence := 0
var _next_lease_id := 1
var _entities: Dictionary = {}
var _landing_targets: Dictionary = {}
var _respawn_targets: Dictionary = {}
var _last_sequence_by_entity_stream: Dictionary = {}
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


func register_entity(
	source_peer_id: int,
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	state: StringName = STATE_FLYING
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if owner_peer_id <= 0 or not _valid_id(entity_id) or not _valid_positive_integer(entity_generation):
		return _remember(_result(false, &"invalid_entity_identity"))
	if not STATES.has(state) or state == STATE_LANDING_PENDING or state == STATE_RESPAWN_PENDING:
		return _remember(_result(false, &"invalid_entity_state"))
	if _entities.size() >= MAX_ENTITIES or _entities.has(entity_id):
		return _remember(_result(false, &"duplicate_entity" if _entities.has(entity_id) else &"entity_capacity"))
	_entities[entity_id] = {
		"entity_id": entity_id,
		"owner_peer_id": owner_peer_id,
		"entity_generation": entity_generation,
		"state": state,
		"lease_id": &"",
		"target_id": &"",
		"stream_id": -1,
		"last_sequence": -1,
		"last_client_tick": -1,
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {"entity_id": entity_id}))


func register_landing_target(
	source_peer_id: int,
	target_id: StringName,
	region_id: StringName,
	target_generation: int = 1
) -> Dictionary:
	return _register_target(source_peer_id, _landing_targets, target_id, region_id, target_generation, &"landing_target")


func register_respawn_target(
	source_peer_id: int,
	target_id: StringName,
	region_id: StringName,
	target_generation: int = 1
) -> Dictionary:
	return _register_target(source_peer_id, _respawn_targets, target_id, region_id, target_generation, &"respawn_target")


func set_server_tick(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	return _remember(_result(true, &"server_tick_advanced", {"server_tick": _server_tick}))


## Server lifecycle input. A destroyed generation is not respawnable until the
## adapter marks it destroyed, and only the server chooses the next generation.
func mark_destroyed(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	if entity.state in [STATE_LANDING_PENDING, STATE_RESPAWN_PENDING]:
		return _remember(_result(false, &"transition_in_progress"))
	if entity.state == STATE_DESTROYED:
		return _remember(_result(false, &"already_destroyed"))
	_clear_entity_target(entity)
	entity.state = STATE_DESTROYED
	_event_sequence += 1
	return _remember(_result(true, &"destroyed", {"entity_generation": entity_generation}))


## Validates sender, lifecycle generation, target identity, tick window, and
## monotonic sequence before atomically reserving one server-owned target.
func accept_intent(source_peer_id: int, wire: Dictionary) -> Dictionary:
	var intent = Intent.from_dictionary(wire)
	if not intent.is_valid():
		return _remember(_result(false, &"invalid_intent", {"errors": intent.get_validation_errors()}))
	if source_peer_id != intent.get_peer_id():
		return _remember(_result(false, &"spoofed_peer"))
	if not _entities.has(intent.get_entity_id()):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[intent.get_entity_id()] as Dictionary
	if int(entity.owner_peer_id) != source_peer_id:
		return _remember(_result(false, &"not_entity_owner"))
	if int(entity.entity_generation) != intent.get_entity_generation():
		return _remember(_result(false, &"stale_entity_generation"))
	if intent.get_client_tick() < _server_tick - _max_tick_behind:
		return _remember(_result(false, &"client_tick_too_old"))
	if intent.get_client_tick() > _server_tick + _max_tick_ahead:
		return _remember(_result(false, &"client_tick_too_far_ahead"))
	var stream_key := "%s:%d" % [String(intent.get_entity_id()), intent.get_stream_id()]
	var previous_sequence := int(_last_sequence_by_entity_stream.get(stream_key, -1))
	if intent.get_sequence() <= previous_sequence:
		return _remember(_result(false, &"stale_sequence"))
	_last_sequence_by_entity_stream[stream_key] = intent.get_sequence()
	if intent.get_action() == Intent.ACTION_LANDING:
		return _remember(_accept_landing(entity, intent))
	return _remember(_accept_respawn(entity, intent))


func commit_landing(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	lease_id: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var checked := _check_transition(entity_id, entity_generation, lease_id, STATE_LANDING_PENDING)
	if not checked.accepted:
		return _remember(checked)
	var entity := _entities[entity_id] as Dictionary
	var target_id: StringName = entity.target_id
	var target := _landing_targets[target_id] as Dictionary
	target.occupied = true
	entity.state = STATE_LANDED
	_event_sequence += 1
	return _remember(_result(true, &"landing_committed", {
		"entity_id": entity_id, "entity_generation": entity_generation,
		"target_id": target_id, "lease_id": lease_id,
	}))


func abort_landing(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	lease_id: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var checked := _check_transition(entity_id, entity_generation, lease_id, STATE_LANDING_PENDING)
	if not checked.accepted:
		return _remember(checked)
	var entity := _entities[entity_id] as Dictionary
	_clear_entity_target(entity)
	entity.state = STATE_FLYING
	_event_sequence += 1
	return _remember(_result(true, &"landing_aborted", {"entity_id": entity_id}))


func commit_respawn(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	respawn_token: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var checked := _check_transition(entity_id, entity_generation, respawn_token, STATE_RESPAWN_PENDING)
	if not checked.accepted:
		return _remember(_result(false, checked.status))
	var entity := _entities[entity_id] as Dictionary
	var target_id: StringName = entity.target_id
	var target := _respawn_targets[target_id] as Dictionary
	var next_generation := entity_generation + 1
	if not _valid_positive_integer(next_generation):
		return _remember(_result(false, &"entity_generation_exhausted"))
	target.active = true
	entity.entity_generation = next_generation
	entity.state = STATE_FLYING
	_clear_entity_target(entity)
	_event_sequence += 1
	return _remember(_result(true, &"respawn_committed", {
		"entity_id": entity_id,
		"entity_generation": next_generation,
		"target_id": target_id,
		"respawn_token": respawn_token,
	}))


func get_entity_snapshot(entity_id: StringName) -> Dictionary:
	if not _entities.has(entity_id):
		return {}
	return (_entities[entity_id] as Dictionary).duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_landing_leases": true,
		"server_owns_target_occupancy": true,
		"server_owns_respawn_generation": true,
		"server_owns_transforms": false,
		"server_owns_collision": false,
		"server_owns_spawn_instantiation": false,
		"client_can_mutate_state": false,
		"registered_entity_count": _entities.size(),
		"registered_landing_target_count": _landing_targets.size(),
		"registered_respawn_target_count": _respawn_targets.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _accept_landing(entity: Dictionary, intent) -> Dictionary:
	if entity.state != STATE_FLYING:
		return _result(false, &"landing_not_allowed_in_state")
	if not _landing_targets.has(intent.get_target_id()):
		return _result(false, &"unknown_landing_target")
	var target := _landing_targets[intent.get_target_id()] as Dictionary
	if target.region_id != intent.get_region_id():
		return _result(false, &"landing_region_mismatch")
	if target.occupied:
		return _result(false, &"landing_target_occupied")
	var lease_id := StringName("landing_lease_%d" % _next_lease_id)
	_next_lease_id += 1
	target.occupied = true
	entity.state = STATE_LANDING_PENDING
	entity.lease_id = lease_id
	entity.target_id = intent.get_target_id()
	_event_sequence += 1
	return _result(true, &"landing_reserved", {
		"entity_id": entity.entity_id if entity.has("entity_id") else &"",
		"lease_id": lease_id,
		"target_id": intent.get_target_id(),
		"event_sequence": _event_sequence,
	})


func _accept_respawn(entity: Dictionary, intent) -> Dictionary:
	if entity.state != STATE_DESTROYED:
		return _result(false, &"respawn_not_allowed_in_state")
	if not _respawn_targets.has(intent.get_target_id()):
		return _result(false, &"unknown_respawn_target")
	var target := _respawn_targets[intent.get_target_id()] as Dictionary
	if target.region_id != intent.get_region_id():
		return _result(false, &"respawn_region_mismatch")
	if target.active:
		return _result(false, &"respawn_target_occupied")
	var token := StringName("respawn_token_%d" % _next_lease_id)
	_next_lease_id += 1
	target.active = true
	entity.state = STATE_RESPAWN_PENDING
	entity.lease_id = token
	entity.target_id = intent.get_target_id()
	_event_sequence += 1
	return _result(true, &"respawn_reserved", {
		"respawn_token": token,
		"target_id": intent.get_target_id(),
		"event_sequence": _event_sequence,
	})


func _register_target(
	source_peer_id: int,
	store: Dictionary,
	target_id: StringName,
	region_id: StringName,
	target_generation: int,
	kind: StringName
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(target_id) or not _valid_id(region_id) or not _valid_positive_integer(target_generation):
		return _remember(_result(false, &"invalid_target_identity"))
	if store.size() >= MAX_TARGETS or store.has(target_id):
		return _remember(_result(false, &"duplicate_target" if store.has(target_id) else &"target_capacity"))
	store[target_id] = {
		"target_id": target_id,
		"region_id": region_id,
		"target_generation": target_generation,
		"occupied": false,
		"active": false,
	}
	_event_sequence += 1
	return _remember(_result(true, &"%s_registered" % kind, {"target_id": target_id}))


func _check_transition(
	entity_id: StringName,
	entity_generation: int,
	lease_id: StringName,
	expected_state: StringName
) -> Dictionary:
	if not _entities.has(entity_id):
		return _result(false, &"unknown_entity")
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _result(false, &"stale_entity_generation")
	if entity.state != expected_state:
		return _result(false, &"transition_not_pending")
	if StringName(entity.lease_id) != lease_id:
		return _result(false, &"invalid_transition_token")
	return _result(true, &"transition_valid")


func _clear_entity_target(entity: Dictionary) -> void:
	var target_id := StringName(entity.target_id)
	if not target_id.is_empty():
		if _landing_targets.has(target_id):
			(_landing_targets[target_id] as Dictionary).occupied = false
		if _respawn_targets.has(target_id):
			(_respawn_targets[target_id] as Dictionary).active = false
	entity.lease_id = &""
	entity.target_id = &""


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
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
