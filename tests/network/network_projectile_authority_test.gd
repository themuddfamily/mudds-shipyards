extends SceneTree

## Focused, detached regression for server-owned projectile and damage events.
## It deliberately does not create MultiplayerPeer, physics bodies, or health
## nodes; those production adapters remain separate multiplayer work.

const Intent := preload("res://scripts/network/network_projectile_intent.gd")
const Authority := preload("res://scripts/network/network_projectile_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wire_contract()
	_test_server_spawn_and_motion()
	_test_impact_and_damage_commit()
	_test_lifecycle_guards()
	if _failures.is_empty():
		print("OK: network projectile authority (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_wire_contract() -> void:
	var intent = Intent.create(
		7, &"fighter_a", 2, 4, 0, 12, &"pulse", Vector3.ZERO, Vector3.FORWARD
	)
	_check(intent.is_valid(), "fire intent accepts the typed transport contract")
	var decoded = Intent.from_dictionary(intent.to_dictionary())
	_check(
		decoded.is_valid()
		and decoded.get_source_generation() == 2
		and decoded.get_normalized_direction().is_equal_approx(Vector3.FORWARD),
		"fire intent round-trips as detached data"
	)
	var forged = intent.to_dictionary()
	forged["damage"] = 9999.0
	_check(not Intent.from_dictionary(forged).is_valid(), "client cannot add a damage field")
	var malformed = intent.to_dictionary()
	malformed.direction = [NAN, 0.0, 0.0]
	_check(not Intent.from_dictionary(malformed).is_valid(), "non-finite direction fails closed")


func _new_authority() -> Authority:
	var authority := Authority.new(99, 3, 1)
	_check(
		authority.register_source(
			99, 7, &"fighter_a", 2, &"blue",
			{"pulse": {"speed": 100.0, "damage": 18.0, "lifetime": 1.0}}
		).accepted,
		"server registers source and authoritative weapon profile"
	)
	_check(authority.set_server_tick(99, 10).accepted, "server tick is caller-driven")
	return authority


func _fire(authority: Authority, peer_id := 7, sequence := 0, tick := 10) -> Dictionary:
	var intent = Intent.create(
		peer_id, &"fighter_a", 2, 1, sequence, tick, &"pulse", Vector3.ZERO, Vector3.FORWARD
	)
	return authority.accept_fire(peer_id, intent.to_dictionary())


func _fire_with_transport_peer(authority: Authority, transport_peer: int, packet_peer: int) -> Dictionary:
	var intent = Intent.create(
		packet_peer, &"fighter_a", 2, 1, 0, 10, &"pulse", Vector3.ZERO, Vector3.FORWARD
	)
	return authority.accept_fire(transport_peer, intent.to_dictionary())


func _test_server_spawn_and_motion() -> void:
	var authority := _new_authority()
	var spoofed := _fire_with_transport_peer(authority, 8, 7)
	_check(not spoofed.accepted and spoofed.status == &"spoofed_peer", "transport sender cannot spoof packet peer")
	var spawned := _fire(authority)
	_check(spawned.accepted and spawned.status == &"spawned", "owner request creates a server projectile")
	var projectile: Dictionary = spawned.projectile
	_check(
		float(projectile.damage) == 18.0
		and float(projectile.speed) == 100.0
		and projectile.source_entity_id == &"fighter_a",
		"spawn uses server profile values rather than client damage"
	)
	var duplicate := _fire(authority, 7, 0)
	_check(not duplicate.accepted and duplicate.status == &"stale_sequence", "duplicate fire sequence cannot replay")
	var advanced := authority.advance(99, 11, 0.1)
	_check(advanced.accepted and (advanced.projectiles as Array).size() == 1, "server advances one detached projectile")
	var moved: Dictionary = (advanced.projectiles as Array)[0]
	_check(float(moved.position.z) < -9.9, "projectile motion is server-clocked and directional")


func _test_impact_and_damage_commit() -> void:
	var authority := _new_authority()
	var spawned := _fire(authority)
	var projectile_id: StringName = spawned.projectile.projectile_id
	var impact := authority.resolve_impact(
		99, projectile_id, &"target_a", 4, Vector3(0, 0, -5), Vector3.BACK
	)
	_check(impact.accepted and impact.status == &"damage_event", "server collision creates one damage event")
	var event: Dictionary = impact.damage_event
	_check(
		float(event.damage) == 18.0
		and event.target_entity_id == &"target_a"
		and event.target_generation == 4,
		"damage event carries server amount and target generation"
	)
	var second_impact := authority.resolve_impact(
		99, projectile_id, &"target_b", 1, Vector3.ZERO, Vector3.UP
	)
	_check(not second_impact.accepted and second_impact.status == &"projectile_not_flying", "one projectile cannot damage twice")
	var committed := authority.commit_damage_application(99, projectile_id, 18.0, 82.0, false)
	_check(committed.accepted and committed.status == &"damage_committed", "existing damage owner can commit one bounded result")
	_check(authority.get_projectile(projectile_id).is_empty(), "resolved projectile leaves active ledger")
	var replay := authority.commit_damage_application(99, projectile_id, 1.0, 81.0, false)
	_check(not replay.accepted and replay.status == &"unknown_projectile", "damage commit cannot replay after removal")


func _test_lifecycle_guards() -> void:
	var authority := _new_authority()
	var spawned := _fire(authority)
	var projectile_id: StringName = spawned.projectile.projectile_id
	var self_hit := authority.resolve_impact(99, projectile_id, &"fighter_a", 2, Vector3.ZERO, Vector3.UP)
	_check(not self_hit.accepted and self_hit.status == &"self_hit_blocked", "self-hit is rejected before damage")
	var stale = Intent.create(7, &"fighter_a", 1, 1, 1, 10, &"pulse", Vector3.ZERO, Vector3.FORWARD)
	_check(authority.accept_fire(7, stale.to_dictionary()).status == &"stale_source_generation", "stale source generation cannot fire")
	var expired := {}
	for tick in range(11, 15):
		expired = authority.advance(99, tick, 0.25)
	_check(expired.accepted and (expired.expired_projectile_ids as Array).size() == 1, "server expires projectiles from physics time")
	var late_impact := authority.resolve_impact(99, projectile_id, &"target_a", 1, Vector3.ZERO, Vector3.UP)
	_check(not late_impact.accepted and late_impact.status == &"unknown_projectile", "expired projectile cannot produce damage")
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_projectile_spawn)
		and bool(audit.server_owns_projectile_motion)
		and bool(audit.server_owns_damage_amount)
		and not bool(audit.server_owns_health_store)
		and not bool(audit.client_can_mutate_projectiles),
		"audit names server projectile/damage ownership without a duplicate health store"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
