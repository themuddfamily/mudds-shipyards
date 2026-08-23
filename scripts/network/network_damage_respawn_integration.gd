class_name NetworkDamageRespawnIntegration
extends RefCounted

## Server-owned handoff ledger for network damage through recovery to respawn.
##
## This is an integration boundary, not a second health, collision, landing,
## or spawn owner. A server adapter supplies the already-authoritative
## `NetworkProjectileAuthority` damage event and the detached
## `ComponentDamageModel` receipt. The existing `CombatRecoveryPolicy` gates
## the short crash-recovery window, while `NetworkLandingAuthority` supplies
## opaque respawn reservation/commit receipts. Clients never provide damage,
## component health, recovery time, transforms, or the next generation.

const RecoveryPolicy := preload("res://scripts/combat/combat_recovery_policy.gd")

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_damage_respawn_integration_v1"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_ENTITIES := 256
const MAX_DAMAGE_EVENT_AMOUNT := 1_000_000_000.0
const MAX_RECOVERY_SECONDS := 60.0

const STATE_ACTIVE: StringName = &"active"
const STATE_RECOVERING: StringName = &"recovering"
const STATE_RECOVERY_READY: StringName = &"recovery_ready"
const STATE_RESPAWN_PENDING: StringName = &"respawn_pending"
const STATES := [STATE_ACTIVE, STATE_RECOVERING, STATE_RECOVERY_READY, STATE_RESPAWN_PENDING]

var _authority_peer_id := 1
var _event_sequence := 0
var _entities: Dictionary = {}
var _last_result: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_last_result = _result(false, &"uninitialized")


## Registers identity only. Component health remains in the supplied model and
## projectile motion/damage amount remains in NetworkProjectileAuthority.
func register_entity(
	source_peer_id: int,
	owner_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	component_generation: int,
	recovery_seconds: float = 2.0,
	invulnerability_seconds: float = 0.75
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if owner_peer_id <= 0 or not _valid_id(entity_id) \
		or not _valid_positive_integer(entity_generation) \
		or not _valid_positive_integer(component_generation):
		return _remember(_result(false, &"invalid_entity_identity"))
	if _entities.has(entity_id):
		return _remember(_result(false, &"duplicate_entity"))
	if _entities.size() >= MAX_ENTITIES:
		return _remember(_result(false, &"entity_capacity"))
	if not _valid_recovery_window(recovery_seconds, invulnerability_seconds):
		return _remember(_result(false, &"invalid_recovery_window"))
	_entities[entity_id] = {
		"entity_id": entity_id,
		"owner_peer_id": owner_peer_id,
		"entity_generation": entity_generation,
		"component_generation": component_generation,
		"state": STATE_ACTIVE,
		"recovery_seconds": recovery_seconds,
		"invulnerability_seconds": invulnerability_seconds,
		"recovery_policy": RecoveryPolicy.new(recovery_seconds, invulnerability_seconds),
		"last_damage_event_sequence": -1,
		"last_component_sequence": -1,
		"damage_event_count": 0,
		"last_damage_event": {},
		"last_component_receipt": {},
		"respawn_target_id": &"",
		"respawn_token": &"",
	}
	_event_sequence += 1
	return _remember(_result(true, &"registered", {"entity_id": entity_id}))


func retire_entity(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.get("entity_generation", -1)) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	_entities.erase(entity_id)
	_event_sequence += 1
	return _remember(_result(true, &"retired", {"entity_id": entity_id}))


## Joins one server projectile receipt to one server component-damage receipt.
## The caller must pass the exact target generation and no client-provided
## amount is trusted. A destroyed receipt starts the bounded recovery policy.
func record_damage(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	damage_event: Dictionary,
	component_receipt: Dictionary,
	destroyed: bool
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.get("entity_generation", -1)) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	if entity.get("state", &"") != STATE_ACTIVE:
		return _remember(_result(false, &"damage_not_allowed_in_state"))
	var event_gate := _validate_damage_event(entity, entity_id, entity_generation, damage_event)
	if not event_gate.is_empty():
		return _remember(_result(false, event_gate.get("reason", &"invalid_damage_event")))
	var component_gate := _validate_component_receipt(entity, component_receipt)
	if not component_gate.is_empty():
		return _remember(_result(false, component_gate.get("reason", &"invalid_component_receipt")))
	var policy := entity.get("recovery_policy") as CombatRecoveryPolicy
	if destroyed:
		var started := policy.begin(entity_generation)
		if not bool(started.get("accepted", false)):
			return _remember(_result(false, &"recovery_start_rejected"))
		entity["state"] = STATE_RECOVERING
	entity["last_damage_event_sequence"] = int(damage_event.get("event_sequence", -1))
	entity["last_component_sequence"] = int(component_receipt.get("sequence", -1))
	entity["damage_event_count"] = int(entity.get("damage_event_count", 0)) + 1
	entity["last_damage_event"] = damage_event.duplicate(true)
	entity["last_component_receipt"] = component_receipt.duplicate(true)
	_event_sequence += 1
	return _remember(_result(true, &"damage_destroyed" if destroyed else &"damage_recorded", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"component_generation": entity.component_generation,
		"event_sequence": damage_event.event_sequence,
		"recovery_generation": entity_generation if destroyed else 0,
	}))


## Advances only the existing crash-recovery timing policy. Physics, health,
## presentation, and respawn instantiation remain owned by production seams.
func tick_recovery(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	delta: float
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _entities.has(entity_id):
		return _remember(_result(false, &"unknown_entity"))
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _remember(_result(false, &"stale_entity_generation"))
	if entity.state != STATE_RECOVERING:
		return _remember(_result(false, &"not_recovering"))
	var policy := entity.recovery_policy as CombatRecoveryPolicy
	var advanced := policy.tick(delta, entity_generation)
	if not bool(advanced.get("accepted", false)):
		return _remember(_result(false, advanced.get("reason", &"recovery_rejected")))
	if bool(policy.is_ready()):
		entity.state = STATE_RECOVERY_READY
	_event_sequence += 1
	return _remember(_result(true, &"recovery_ready" if policy.is_ready() else &"recovery_advanced", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"elapsed": policy.get_elapsed(),
	}))


## Accepts the opaque reservation returned by NetworkLandingAuthority. This
## makes the integration fail closed if the crash window has not completed or
## if a response is replayed for another lifecycle generation.
func reserve_respawn(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	reservation: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var entity_gate := _entity_for_generation(entity_id, entity_generation)
	if not bool(entity_gate.get("accepted", false)):
		return _remember(entity_gate)
	var entity := entity_gate.entity as Dictionary
	if entity.state != STATE_RECOVERY_READY:
		return _remember(_result(false, &"recovery_not_ready"))
	if not bool(reservation.get("accepted", false)) \
		or StringName(reservation.get("status", &"")) != &"respawn_reserved":
		return _remember(_result(false, &"invalid_respawn_reservation"))
	var token := StringName(reservation.get("respawn_token", &""))
	var target_id := StringName(reservation.get("target_id", &""))
	if not _valid_id(token) or not _valid_id(target_id):
		return _remember(_result(false, &"invalid_respawn_reservation"))
	entity.state = STATE_RESPAWN_PENDING
	entity.respawn_target_id = target_id
	entity.respawn_token = token
	_event_sequence += 1
	return _remember(_result(true, &"respawn_reserved", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"target_id": target_id,
		"respawn_token": token,
	}))


## Commits the landing-authority result and the component model's reset receipt
## together. Both generations must advance exactly once before the entity is
## visible as active again.
func commit_respawn(
	source_peer_id: int,
	entity_id: StringName,
	entity_generation: int,
	commit: Dictionary,
	component_reset: Dictionary
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var entity_gate := _entity_for_generation(entity_id, entity_generation)
	if not bool(entity_gate.get("accepted", false)):
		return _remember(entity_gate)
	var entity := entity_gate.entity as Dictionary
	if entity.state != STATE_RESPAWN_PENDING:
		return _remember(_result(false, &"respawn_not_pending"))
	if not bool(commit.get("accepted", false)) \
		or StringName(commit.get("status", &"")) != &"respawn_committed":
		return _remember(_result(false, &"invalid_respawn_commit"))
	if StringName(commit.get("entity_id", &"")) != entity_id \
		or int(commit.get("entity_generation", -1)) != entity_generation + 1 \
		or StringName(commit.get("target_id", &"")) != StringName(entity.respawn_target_id) \
		or StringName(commit.get("respawn_token", &"")) != StringName(entity.respawn_token):
		return _remember(_result(false, &"respawn_identity_mismatch"))
	if not bool(component_reset.get("accepted", false)) \
		or StringName(component_reset.get("reason", &"")) != &"reset":
		return _remember(_result(false, &"invalid_component_reset"))
	var next_component_generation := int(entity.component_generation) + 1
	if int(component_reset.get("generation", -1)) != next_component_generation:
		return _remember(_result(false, &"component_generation_mismatch"))
	entity.entity_generation = entity_generation + 1
	entity.component_generation = next_component_generation
	entity.state = STATE_ACTIVE
	entity.last_damage_event_sequence = -1
	entity.last_component_sequence = -1
	entity.last_damage_event = {}
	entity.last_component_receipt = {}
	entity.respawn_target_id = &""
	entity.respawn_token = &""
	entity.recovery_policy = RecoveryPolicy.new(
		float(entity.recovery_seconds), float(entity.invulnerability_seconds)
	)
	_event_sequence += 1
	return _remember(_result(true, &"respawn_committed", {
		"entity_id": entity_id,
		"entity_generation": entity.entity_generation,
		"component_generation": entity.component_generation,
	}))


func get_entity_snapshot(entity_id: StringName) -> Dictionary:
	if not _entities.has(entity_id):
		return {}
	var entity := _entities[entity_id] as Dictionary
	var policy := entity.get("recovery_policy") as CombatRecoveryPolicy
	return {
		"entity_id": entity.entity_id,
		"owner_peer_id": entity.owner_peer_id,
		"entity_generation": entity.entity_generation,
		"component_generation": entity.component_generation,
		"state": entity.state,
		"last_damage_event_sequence": entity.last_damage_event_sequence,
		"last_component_sequence": entity.last_component_sequence,
		"damage_event_count": entity.damage_event_count,
		"last_damage_event": entity.last_damage_event.duplicate(true),
		"last_component_receipt": entity.last_component_receipt.duplicate(true),
		"recovery": policy.get_snapshot(),
		"respawn_target_id": entity.respawn_target_id,
		"respawn_token": entity.respawn_token,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0,
		"server_owns_damage_event_order": true,
		"server_owns_component_generation": true,
		"server_owns_recovery_gate": true,
		"server_owns_respawn_generation": true,
		"client_can_mutate_health": false,
		"client_can_mutate_recovery": false,
		"client_can_mutate_respawn": false,
		"owns_health_store": false,
		"owns_collision": false,
		"owns_spawn_instantiation": false,
		"registered_entity_count": _entities.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_damage_event(
	entity: Dictionary,
	entity_id: StringName,
	entity_generation: int,
	damage_event: Dictionary
) -> Dictionary:
	if StringName(damage_event.get("target_entity_id", &"")) != entity_id \
		or int(damage_event.get("target_generation", -1)) != entity_generation:
		return {"reason": &"damage_target_generation_mismatch"}
	var event_sequence := int(damage_event.get("event_sequence", -1))
	if not _valid_positive_integer(event_sequence) \
		or event_sequence <= int(entity.last_damage_event_sequence):
		return {"reason": &"stale_damage_event"}
	var damage := float(damage_event.get("damage", NAN))
	if not is_finite(damage) or damage <= 0.0 or damage > MAX_DAMAGE_EVENT_AMOUNT:
		return {"reason": &"invalid_damage_amount"}
	if not _valid_id(StringName(damage_event.get("projectile_id", &""))):
		return {"reason": &"invalid_projectile_identity"}
	return {}


func _validate_component_receipt(entity: Dictionary, receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("accepted", false)) \
		or StringName(receipt.get("reason", &"")) != &"applied":
		return {"reason": &"invalid_component_receipt"}
	if int(receipt.get("generation", -1)) != int(entity.component_generation):
		return {"reason": &"stale_component_generation"}
	if not _valid_id(StringName(receipt.get("component_id", &""))):
		return {"reason": &"invalid_component_identity"}
	var sequence := int(receipt.get("sequence", -1))
	if sequence < 0 or sequence <= int(entity.last_component_sequence):
		return {"reason": &"stale_component_sequence"}
	var applied := float(receipt.get("applied_damage", NAN))
	if not is_finite(applied) or applied <= 0.0:
		return {"reason": &"invalid_component_damage"}
	return {}


func _entity_for_generation(entity_id: StringName, entity_generation: int) -> Dictionary:
	if not _entities.has(entity_id):
		return _result(false, &"unknown_entity")
	var entity := _entities[entity_id] as Dictionary
	if int(entity.entity_generation) != entity_generation:
		return _result(false, &"stale_entity_generation")
	return {"accepted": true, "entity": entity}


func _valid_recovery_window(recovery_seconds: float, invulnerability_seconds: float) -> bool:
	return is_finite(recovery_seconds) and recovery_seconds > 0.0 \
		and recovery_seconds <= MAX_RECOVERY_SECONDS \
		and is_finite(invulnerability_seconds) and invulnerability_seconds >= 0.0 \
		and invulnerability_seconds <= recovery_seconds


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
