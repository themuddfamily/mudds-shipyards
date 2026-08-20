class_name NetworkReplicationInterestAuthority
extends RefCounted

## Server-owned replication-interest and entity-ownership boundary.
##
## This detached ledger does not perform RPC, node lookup, visibility tests, or
## transform interpolation. A server adapter publishes already-authoritative
## state and asks for a bounded per-peer replication batch. Clients receive
## only entities inside their registered interest region; they cannot publish
## state, transfer ownership, or bypass lifecycle generations.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_replication_interest_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_ENTITIES := 512
const MAX_PEERS := 128
const MAX_STATE_FIELDS := 64
const MAX_INTEREST_RADIUS := 1_000_000.0
const DEFAULT_MAX_UPDATES_PER_TICK := 16

var _authority_peer_id := 1
var _max_updates_per_tick := DEFAULT_MAX_UPDATES_PER_TICK
var _server_tick := 0
var _event_sequence := 0
var _entities: Dictionary = {}
var _peers: Dictionary = {}
var _last_sent_revision_by_peer: Dictionary = {}
var _updates_used_by_peer_tick: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_max_updates_per_tick: int = DEFAULT_MAX_UPDATES_PER_TICK
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_max_updates_per_tick = maxi(1, p_max_updates_per_tick)
	_last_result = _result(false, &"uninitialized")


## Peers and interest regions are server lifecycle state. A region is a
## subscription hint, not an ownership grant.
func register_peer(source_peer_id: int, peer_id: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0:
		return _remember(_result(false, &"invalid_peer_id"))
	if _peers.has(peer_id):
		return _remember(_result(false, &"duplicate_peer"))
	if _peers.size() >= MAX_PEERS:
		return _remember(_result(false, &"peer_capacity"))
	_peers[peer_id] = {
		"peer_id": peer_id,
		"center": Vector3.ZERO,
		"radius": 0.0,
		"max_entities": MAX_ENTITIES,
		"active": true,
	}
	_last_sent_revision_by_peer[peer_id] = {}
	_event_sequence += 1
	return _remember(_result(true, &"peer_registered", {"peer_id": peer_id}))


func set_peer_interest(
	source_peer_id: int,
	peer_id: int,
	center: Vector3,
	radius: float,
	max_entities: int = MAX_ENTITIES
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _peers.has(peer_id):
		return _remember(_result(false, &"unknown_peer"))
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0 or radius > MAX_INTEREST_RADIUS:
		return _remember(_result(false, &"invalid_interest_region"))
	if max_entities <= 0 or max_entities > MAX_ENTITIES:
		return _remember(_result(false, &"invalid_interest_capacity"))
	var peer := _peers[peer_id] as Dictionary
	peer["center"] = center
	peer["radius"] = radius
	peer["max_entities"] = max_entities
	return _remember(_result(true, &"interest_updated", {
		"peer_id": peer_id,
		"center": _encode_vector(center),
		"radius": radius,
		"max_entities": max_entities,
	}))


func register_entity(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	owner_peer_id: int,
	position: Vector3,
	replication_radius: float = 1000.0
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_id(entity_id) or not _valid_positive_integer(entity_generation):
		return _remember(_result(false, &"invalid_entity_identity"))
	if owner_peer_id < 0 or not position.is_finite() or not is_finite(replication_radius) \
		or replication_radius <= 0.0 or replication_radius > MAX_INTEREST_RADIUS:
		return _remember(_result(false, &"invalid_entity_state"))
	if _entities.has(entity_id):
		return _remember(_result(false, &"duplicate_entity"))
	if _entities.size() >= MAX_ENTITIES:
		return _remember(_result(false, &"entity_capacity"))
	_entities[entity_id] = {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"owner_peer_id": owner_peer_id,
		"ownership_generation": 0,
		"position": position,
		"replication_radius": replication_radius,
		"state": {},
		"state_revision": 0,
		"last_state_tick": _server_tick,
	}
	_event_sequence += 1
	return _remember(_result(true, &"entity_registered", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"owner_peer_id": owner_peer_id,
	}))


## State publication is an internal server adapter seam. The source peer is
## intentionally the authority process, never the entity's client owner.
func publish_state(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	server_tick: int,
	position: Vector3,
	state: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	if not position.is_finite() or state.size() > MAX_STATE_FIELDS:
		return _remember(_result(false, &"invalid_entity_state"))
	_server_tick = server_tick
	entity.position = position
	entity.state = state.duplicate(true)
	entity.state_revision = int(entity.state_revision) + 1
	entity.last_state_tick = server_tick
	_event_sequence += 1
	return _remember(_result(true, &"state_published", {
		"entity_id": entity_id,
		"state_revision": entity.state_revision,
		"server_tick": server_tick,
	}))


## Ownership transfers are server-only and generation fenced. Ownership is
## metadata included in replication; it never authorizes client state writes.
func transfer_ownership(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	expected_owner_peer_id: int,
	new_owner_peer_id: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	if expected_owner_peer_id < 0 or new_owner_peer_id < 0:
		return _remember(_result(false, &"invalid_owner_peer_id"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	if int(entity.owner_peer_id) != expected_owner_peer_id:
		return _remember(_result(false, &"owner_mismatch"))
	entity.owner_peer_id = new_owner_peer_id
	entity.ownership_generation = int(entity.ownership_generation) + 1
	entity.state_revision = int(entity.state_revision) + 1
	_event_sequence += 1
	return _remember(_result(true, &"ownership_transferred", {
		"entity": entity.duplicate(true),
		"event_sequence": _event_sequence,
	}))


func retire_entity(source_peer_id: int, entity_id: StringName, entity_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	_entities.erase(entity_id)
	for peer_id in _last_sent_revision_by_peer:
		(_last_sent_revision_by_peer[peer_id] as Dictionary).erase(entity_id)
	_event_sequence += 1
	return _remember(_result(true, &"entity_retired", {"entity_id": entity_id}))


## Produces one bounded, detached batch. Entities are sorted by stable ID so
## budget exhaustion is deterministic and cannot be influenced by dictionary
## insertion order. Unchanged revisions are not resent.
func replicate(source_peer_id: int, peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _peers.has(peer_id):
		return _remember(_result(false, &"unknown_peer"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	var used_key := "%d:%d" % [peer_id, server_tick]
	var used := int(_updates_used_by_peer_tick.get(used_key, 0))
	var remaining := maxi(0, _max_updates_per_tick - used)
	var peer := _peers[peer_id] as Dictionary
	var sent := []
	var deferred := []
	var candidates: Array = []
	for entity_variant in _entities.values():
		var entity := entity_variant as Dictionary
		if _in_interest(entity, peer):
			candidates.append(entity)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.entity_id) < str(right.entity_id)
	)
	var sent_revisions := _last_sent_revision_by_peer[peer_id] as Dictionary
	for entity in candidates:
		var revision := int(entity.state_revision)
		if revision <= int(sent_revisions.get(entity.entity_id, -1)):
			continue
		if remaining <= 0:
			deferred.append(entity.entity_id)
			continue
		sent.append(_replication_entry(entity))
		sent_revisions[entity.entity_id] = revision
		remaining -= 1
	used += 1
	_updates_used_by_peer_tick[used_key] = used
	var status: StringName = &"replicated" if not sent.is_empty() else (&"rate_limited" if not deferred.is_empty() else &"no_changes")
	return _remember(_result(true, status, {
		"peer_id": peer_id,
		"server_tick": server_tick,
		"entities": sent,
		"deferred_entity_ids": deferred,
		"remaining_budget": remaining,
	}))


func get_entity_snapshot(entity_id: StringName) -> Dictionary:
	if not _entities.has(entity_id):
		return {}
	return (_entities[entity_id] as Dictionary).duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"authority_peer_id": _authority_peer_id,
		"server_owns_interest": true,
		"server_owns_replication_budget": true,
		"server_owns_entity_generations": true,
		"server_owns_ownership_transfers": true,
		"client_can_mutate_state": false,
		"client_can_transfer_ownership": false,
		"registered_entity_count": _entities.size(),
		"registered_peer_count": _peers.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _in_interest(entity: Dictionary, peer: Dictionary) -> bool:
	var distance: float = (entity.position as Vector3).distance_to(peer.center as Vector3)
	return distance <= minf(float(entity.replication_radius), float(peer.radius))


func _replication_entry(entity: Dictionary) -> Dictionary:
	return {
		"entity_id": entity.entity_id,
		"entity_generation": entity.entity_generation,
		"owner_peer_id": entity.owner_peer_id,
		"ownership_generation": entity.ownership_generation,
		"position": _encode_vector(entity.position),
		"state_revision": entity.state_revision,
		"server_tick": entity.last_state_tick,
		"state": entity.state.duplicate(true),
	}.duplicate(true)


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative_integer(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _encode_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
