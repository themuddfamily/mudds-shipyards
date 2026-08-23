class_name BomberPayloadCombatAdapter
extends RefCounted

const ProjectileType := preload("res://scripts/combat/bomber_payload_projectile.gd")
const ResolverType := preload("res://scripts/combat/combat_resolver.gd")
const LiveAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")

## Consumes one terminal BomberPayloadProjectile intent and hands its bounded
## travel segment to CombatResolver. The resolver remains the sole owner of
## world occlusion, faction policy, and Damageable mutation; this adapter keeps
## only a detached terminal/replay ledger.

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

var _authority_peer_id := 1
var _configuration_valid := true
var _active := false
var _generation := 0
var _last_release_sequence := 0
var _consumed_terminal_keys: Dictionary = {}


func _init(p_authority_peer_id: int = 1) -> void:
	_authority_peer_id = p_authority_peer_id
	_configuration_valid = _authority_peer_id > 0


func is_configuration_valid() -> bool:
	return _configuration_valid


func begin_generation(generation: int) -> Dictionary:
	if not _configuration_valid:
		return _result(false, &"invalid_configuration")
	if generation <= 0:
		return _result(false, &"invalid_generation")
	if generation <= _generation:
		return _result(false, &"stale_generation")
	if _active:
		return _result(false, &"authority_active")
	_active = true
	_generation = generation
	_last_release_sequence = 0
	_consumed_terminal_keys.clear()
	return _result(true, &"generation_started", {"generation": _generation})


func reset_for_reuse(generation: int) -> Dictionary:
	if _active:
		return _result(false, &"reset_requires_detach")
	var result := begin_generation(generation)
	if bool(result.get("accepted", false)):
		result["reason"] = &"reentered"
	return result.duplicate(true)


func detach(reason: StringName = &"detached") -> Dictionary:
	if not _configuration_valid:
		return _result(false, &"invalid_configuration")
	if not _active:
		return _result(false, &"already_detached")
	_active = false
	_last_release_sequence = 0
	_consumed_terminal_keys.clear()
	return _result(true, &"detached", {
		"generation": _generation,
		"detach_reason": reason if not reason.is_empty() else &"detached",
	})


## Consumes a projectile's already-emitted terminal intent exactly once. Impact
## intents are narrowed to their actual travel endpoint before resolver query;
## expiry intents are acknowledged without inventing a damage event.
func consume_terminal_intent(
		source_peer_id: int,
		projectile: BomberPayloadProjectile,
		source_entity: Node3D,
		source_id: int,
		live_authority: LiveCombatAuthority
	) -> Dictionary:
	if not _configuration_valid:
		return _result(false, &"invalid_configuration")
	if source_peer_id != _authority_peer_id:
		return _result(false, &"unauthorized_source")
	if not _active:
		return _result(false, &"authority_detached")
	if projectile == null or not is_instance_valid(projectile):
		return _result(false, &"projectile_unavailable")
	if live_authority == null or not is_instance_valid(live_authority):
		return _result(false, &"authority_unavailable")
	var resolver := live_authority.get_resolver() as CombatResolver
	if resolver == null or not is_instance_valid(resolver):
		return _result(false, &"resolver_unavailable")
	var terminal := projectile.get_terminal_intent()
	if terminal.is_empty():
		return _result(false, &"terminal_not_ready")
	var release_record: Dictionary = projectile.get_snapshot().get("release_record", {}) as Dictionary
	if release_record.is_empty():
		return _result(false, &"release_record_unavailable")
	var generation: Variant = terminal.get("generation", null)
	var release_sequence: Variant = terminal.get("release_sequence", null)
	var terminal_sequence: Variant = terminal.get("terminal_sequence", null)
	if not generation is int or int(generation) != _generation:
		return _result(false, &"stale_generation")
	if not _valid_sequence(int(release_sequence)) or not _valid_sequence(int(terminal_sequence)):
		return _result(false, &"invalid_terminal_sequence")
	if int(release_record.get("generation", -1)) != _generation \
			or int(release_record.get("release_sequence", -1)) != int(release_sequence):
		return _result(false, &"release_terminal_mismatch")
	var terminal_key := "%d:%d:%d:%d" % [
		source_id, _generation, int(release_sequence), int(terminal_sequence)
	]
	if _consumed_terminal_keys.has(terminal_key):
		return _result(false, &"duplicate_terminal_intent")
	if int(release_sequence) <= _last_release_sequence:
		return _result(false, &"stale_release_sequence")
	var kind := StringName(terminal.get("kind", &""))
	if kind != &"impact" and kind != &"expiry":
		return _result(false, &"invalid_terminal_kind")
	_consumed_terminal_keys[terminal_key] = true
	_last_release_sequence = int(release_sequence)
	if kind == &"expiry":
		return _result(true, &"expiry_forwarded", {"terminal_intent": terminal})
	if not is_instance_valid(source_entity) or not source_entity.is_inside_tree():
		return _result(false, &"source_unavailable")
	var origin: Variant = release_record.get("release_position", null)
	var endpoint: Variant = terminal.get("position", null)
	if not origin is Vector3 or not endpoint is Vector3 \
			or not (origin as Vector3).is_finite() or not (endpoint as Vector3).is_finite():
		return _result(false, &"invalid_terminal_geometry")
	var weapon_id := StringName(release_record.get("weapon_id", &""))
	var resolver_result := resolver.resolve_projectile_impact(
		source_entity,
		source_id,
		&"",
		weapon_id,
		int(release_sequence),
		origin as Vector3,
		endpoint as Vector3
	)
	return _result(
		bool(resolver_result.get("accepted", false)),
		&"impact_resolved" if bool(resolver_result.get("accepted", false)) else &"resolver_rejected",
		{
			"terminal_intent": terminal,
			"resolver_result": resolver_result,
		}
	)


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"authority_peer_id": _authority_peer_id,
		"active": _active,
		"generation": _generation,
		"last_release_sequence": _last_release_sequence,
		"consumed_terminal_count": _consumed_terminal_keys.size(),
		"authority": {
			"server_admission": true,
			"resolver_delegation": true,
			"world_occlusion": false,
			"faction_policy": false,
			"damage": false,
			"score": false,
		},
	}.duplicate(true)


func _valid_sequence(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key in extra:
		result[key] = extra[key]
	return result.duplicate(true)
