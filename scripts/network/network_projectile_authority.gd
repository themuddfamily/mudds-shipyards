class_name NetworkProjectileAuthority
extends RefCounted

## Server-owned projectile ledger and damage-event boundary.
##
## This contract does not spawn a Node3D, query physics, or keep a second
## health store. A server adapter advances the detached projectile snapshots,
## feeds collision hits to `resolve_impact()`, and applies the returned
## authoritative damage event through the existing Damageable/CombatResolver
## owner. Clients never provide damage, speed, faction, target, or impact data.

const Intent := preload("res://scripts/network/network_projectile_intent.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_projectile_damage_authority_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const DEFAULT_MAX_TICK_BEHIND := 6
const DEFAULT_MAX_TICK_AHEAD := 2
const MAX_DELTA := 0.25
const MAX_PROJECTILES := 256

var _authority_peer_id := 1
var _max_tick_behind := DEFAULT_MAX_TICK_BEHIND
var _max_tick_ahead := DEFAULT_MAX_TICK_AHEAD
var _server_tick := 0
var _event_sequence := 0
var _next_projectile_id := 1
var _sources: Dictionary = {}
var _projectiles: Dictionary = {}
var _last_sequence_by_source_stream: Dictionary = {}
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


## Registers identity, faction, and weapon values owned by the server. A weapon
## profile must provide positive finite `speed`, `damage`, and `lifetime`.
func register_source(
	source_peer_id: int,
	owner_peer_id: int,
	source_entity_id: StringName,
	source_generation: int,
	faction_id: StringName,
	weapon_profiles: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if owner_peer_id <= 0 or not _valid_id(source_entity_id) or not _valid_positive_integer(source_generation):
		return _remember(_result(false, &"invalid_source_identity"))
	if faction_id.is_empty():
		return _remember(_result(false, &"invalid_faction"))
	var profiles := _normalize_profiles(weapon_profiles)
	if profiles.is_empty() or profiles.size() != weapon_profiles.size():
		return _remember(_result(false, &"invalid_weapon_profiles"))
	if _sources.has(source_entity_id):
		return _remember(_result(false, &"duplicate_source"))
	_sources[source_entity_id] = {
		"owner_peer_id": owner_peer_id,
		"source_generation": source_generation,
		"faction_id": faction_id,
		"weapon_profiles": profiles,
		"active": true,
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {"source_entity_id": source_entity_id}))


func retire_source(
	source_peer_id: int,
	source_entity_id: StringName,
	source_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _sources.has(source_entity_id):
		return _remember(_result(false, &"unknown_source"))
	var source := _sources[source_entity_id] as Dictionary
	if int(source.source_generation) != source_generation:
		return _remember(_result(false, &"stale_source_generation"))
	_sources.erase(source_entity_id)
	var retired: Array = []
	for projectile_id_variant in _projectiles.keys():
		var projectile_id := StringName(projectile_id_variant)
		var projectile := _projectiles[projectile_id] as Dictionary
		if projectile.source_entity_id == source_entity_id:
			retired.append(projectile_id)
			_projectiles.erase(projectile_id)
	_event_sequence += 1
	return _remember(_result(true, &"retired", {"projectile_ids": retired}))


func set_server_tick(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	_server_tick = server_tick
	return _remember(_result(true, &"server_tick_advanced", {"server_tick": _server_tick}))


## Accepts a client packet and creates a server-owned projectile record. The
## request sequence is consumed before any later physics or damage step.
func accept_fire(source_peer_id: int, wire: Dictionary) -> Dictionary:
	var intent = Intent.from_dictionary(wire)
	if not intent.is_valid():
		return _remember(_result(false, &"invalid_intent", {"errors": intent.get_validation_errors()}))
	if source_peer_id != intent.get_peer_id():
		return _remember(_result(false, &"spoofed_peer"))
	if not _sources.has(intent.get_source_entity_id()):
		return _remember(_result(false, &"unknown_source"))
	var source := _sources[intent.get_source_entity_id()] as Dictionary
	if int(source.owner_peer_id) != source_peer_id:
		return _remember(_result(false, &"not_source_owner"))
	if int(source.source_generation) != intent.get_source_generation():
		return _remember(_result(false, &"stale_source_generation"))
	if intent.get_client_tick() < _server_tick - _max_tick_behind:
		return _remember(_result(false, &"client_tick_too_old"))
	if intent.get_client_tick() > _server_tick + _max_tick_ahead:
		return _remember(_result(false, &"client_tick_too_far_ahead"))
	var stream_key := _stream_key(intent.get_source_entity_id(), intent.get_stream_id())
	var previous_sequence := int(_last_sequence_by_source_stream.get(stream_key, -1))
	if intent.get_sequence() <= previous_sequence:
		return _remember(_result(false, &"stale_sequence"))
	_last_sequence_by_source_stream[stream_key] = intent.get_sequence()
	var profiles := source.weapon_profiles as Dictionary
	if not profiles.has(intent.get_weapon_id()):
		return _remember(_result(false, &"unknown_weapon"))
	if _projectiles.size() >= MAX_PROJECTILES:
		return _remember(_result(false, &"projectile_capacity"))
	var profile := profiles[intent.get_weapon_id()] as Dictionary
	var projectile_id := StringName("projectile_%d" % _next_projectile_id)
	_next_projectile_id += 1
	var projectile := {
		"projectile_id": projectile_id,
		"projectile_generation": 1,
		"source_entity_id": intent.get_source_entity_id(),
		"source_generation": intent.get_source_generation(),
		"owner_peer_id": source.owner_peer_id,
		"faction_id": source.faction_id,
		"weapon_id": intent.get_weapon_id(),
		"position": intent.get_origin(),
		"direction": intent.get_normalized_direction(),
		"speed": float(profile.speed),
		"damage": float(profile.damage),
		"lifetime": float(profile.lifetime),
		"remaining_lifetime": float(profile.lifetime),
		"spawn_tick": _server_tick,
		"last_update_tick": _server_tick,
		"state": &"flying",
	}
	_projectiles[projectile_id] = projectile
	_event_sequence += 1
	return _remember(_result(true, &"spawned", {
		"projectile": projectile.duplicate(true),
		"event_sequence": _event_sequence,
	}))


## Advances all projectiles using server physics time. No client clock is used.
## Returned snapshots are detached and may be replicated to clients.
func advance(source_peer_id: int, server_tick: int, delta: float) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative_integer(server_tick) or server_tick < _server_tick:
		return _remember(_result(false, &"stale_server_tick"))
	if not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA:
		return _remember(_result(false, &"invalid_delta"))
	_server_tick = server_tick
	var active: Array = []
	var expired: Array = []
	for projectile_id_variant in _projectiles.keys():
		var projectile_id := StringName(projectile_id_variant)
		var projectile := _projectiles[projectile_id] as Dictionary
		if projectile.state != &"flying":
			continue
		projectile.position += projectile.direction * projectile.speed * delta
		projectile.remaining_lifetime = maxf(0.0, projectile.remaining_lifetime - delta)
		projectile.last_update_tick = server_tick
		if projectile.remaining_lifetime <= 0.0:
			projectile.state = &"expired"
			expired.append(projectile_id)
			_projectiles.erase(projectile_id)
		else:
			active.append(projectile.duplicate(true))
	return _remember(_result(true, &"advanced", {
		"server_tick": server_tick,
		"projectiles": active,
		"expired_projectile_ids": expired,
	}))


## Converts one server collision into one authoritative damage event. It does
## not apply health itself; the existing damage owner consumes the event once
## and may then call commit_damage_application().
func resolve_impact(
	source_peer_id: int,
	projectile_id: StringName,
	target_entity_id: StringName,
	target_generation: int,
	impact_position: Vector3,
	impact_normal: Vector3
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _projectiles.has(projectile_id):
		return _remember(_result(false, &"unknown_projectile"))
	var projectile := _projectiles[projectile_id] as Dictionary
	if projectile.state != &"flying":
		return _remember(_result(false, &"projectile_not_flying"))
	if not _valid_id(target_entity_id) or not _valid_positive_integer(target_generation):
		return _remember(_result(false, &"invalid_target_identity"))
	if target_entity_id == StringName(projectile.source_entity_id):
		return _remember(_result(false, &"self_hit_blocked"))
	if not impact_position.is_finite() or not impact_normal.is_finite():
		return _remember(_result(false, &"invalid_impact"))
	projectile.state = &"impact_pending"
	projectile.target_entity_id = target_entity_id
	projectile.target_generation = target_generation
	projectile.impact_position = impact_position
	projectile.impact_normal = impact_normal
	_event_sequence += 1
	return _remember(_result(true, &"damage_event", {
		"damage_event": {
			"schema_version": SCHEMA_VERSION,
			"event_sequence": _event_sequence,
			"projectile_id": projectile_id,
			"projectile_generation": projectile.projectile_generation,
			"source_entity_id": projectile.source_entity_id,
			"source_generation": projectile.source_generation,
			"source_peer_id": projectile.owner_peer_id,
			"source_faction_id": projectile.faction_id,
			"weapon_id": projectile.weapon_id,
			"target_entity_id": target_entity_id,
			"target_generation": target_generation,
			"impact_position": _encode_vector(impact_position),
			"impact_normal": _encode_vector(impact_normal),
			"damage": projectile.damage,
		},
	}))


## Records the result from the existing authoritative Damageable owner. The
## server still enforces the maximum/profile amount and accepts this only once.
func commit_damage_application(
	source_peer_id: int,
	projectile_id: StringName,
	applied_damage: float,
	remaining_health: float,
	destroyed: bool
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _projectiles.has(projectile_id):
		return _remember(_result(false, &"unknown_projectile"))
	var projectile := _projectiles[projectile_id] as Dictionary
	if projectile.state != &"impact_pending":
		return _remember(_result(false, &"damage_event_not_pending"))
	if not is_finite(applied_damage) or applied_damage < 0.0 or applied_damage > float(projectile.damage) + 0.0001:
		return _remember(_result(false, &"invalid_applied_damage"))
	if not is_finite(remaining_health) or remaining_health < 0.0:
		return _remember(_result(false, &"invalid_remaining_health"))
	projectile.state = &"resolved"
	projectile.applied_damage = applied_damage
	projectile.remaining_health = remaining_health
	projectile.destroyed = destroyed
	_event_sequence += 1
	var committed := projectile.duplicate(true)
	_projectiles.erase(projectile_id)
	return _remember(_result(true, &"damage_committed", {
		"event_sequence": _event_sequence,
		"projectile": committed,
	}))


func get_projectile(projectile_id: StringName) -> Dictionary:
	return (_projectiles.get(projectile_id, {}) as Dictionary).duplicate(true)


func get_projectiles_snapshot() -> Array:
	var projectiles: Array = []
	for projectile_variant in _projectiles.values():
		projectiles.append((projectile_variant as Dictionary).duplicate(true))
	projectiles.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("projectile_id", "")) < str(right.get("projectile_id", ""))
	)
	return projectiles


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_projectile_spawn": true,
		"server_owns_projectile_motion": true,
		"server_owns_damage_amount": true,
		"server_owns_health_store": false,
		"client_can_mutate_projectiles": false,
		"registered_source_count": _sources.size(),
		"active_projectile_count": _projectiles.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _normalize_profiles(raw: Dictionary) -> Dictionary:
	var profiles := {}
	for key_variant in raw.keys():
		var weapon_id := StringName(key_variant)
		var profile_variant: Variant = raw[key_variant]
		if not profile_variant is Dictionary or not _valid_id(weapon_id):
			return {}
		var profile := profile_variant as Dictionary
		for required in ["speed", "damage", "lifetime"]:
			if not profile.get(required) is int and not profile.get(required) is float:
				return {}
			if not is_finite(float(profile.get(required))) or float(profile.get(required)) <= 0.0:
				return {}
		profiles[weapon_id] = {
			"speed": float(profile.speed),
			"damage": float(profile.damage),
			"lifetime": float(profile.lifetime),
		}
	return profiles


func _stream_key(source_entity_id: StringName, stream_id: int) -> StringName:
	return StringName("%s:%d" % [str(source_entity_id), stream_id])


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


func _encode_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


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
	return result
