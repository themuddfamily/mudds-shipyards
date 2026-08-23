extends SceneTree

## Focused Phase 7 synchronization regression. Existing movement, ownership,
## projectile, boarding, and damage/respawn authorities remain the owners of
## their ledgers; this test covers their one detached server snapshot seam.

const Authority := preload("res://scripts/network/network_authoritative_snapshot.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_server_publication_and_detachment()
	_test_order_and_generation_guards()
	_test_replica_server_boundary()
	if _failures.is_empty():
		print("OK: network authoritative snapshot synchronization (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_server_publication_and_detachment() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	var published := authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn)
	_check(published.accepted and published.status == &"published", "server publishes one mixed authority snapshot")
	var snapshot: Dictionary = authority.get_snapshot()
	_check(
		int(snapshot.schema_version) == Authority.SCHEMA_VERSION
		and int(snapshot.server_tick) == 40
		and int(snapshot.event_sequence) == 12
		and int(snapshot.revision) == 1,
		"snapshot carries the server tick, event sequence, and revision"
	)
	var copied_sections: Dictionary = snapshot.sections
	_check(
		(copied_sections.movement as Array).size() == 1
		and (copied_sections.ownership as Array).size() == 1
		and (copied_sections.projectiles as Array).size() == 1
		and (copied_sections.boarding as Array).size() == 1
		and (copied_sections.respawn as Array).size() == 1,
		"movement, ownership, projectile, boarding, and respawn records are synchronized together"
	)
	(sections.movement[0] as Dictionary).entity_id = &"mutated_after_publish"
	(copied_sections.movement as Array).clear()
	_check(
		String(authority.get_section(&"movement")[0].entity_id) == "avatar_a",
		"published sections and returned snapshots are detached from caller mutation"
	)
	var modifiers := authority.get_section(&"ownership")[0] as Dictionary
	_check(
		float(modifiers.get("engine_power", -1.0)) == 0.8
		and bool(modifiers.get("weapon_disabled", true)) == false,
		"authoritative component modifiers remain detached in the ship snapshot"
	)
	var audit := authority.audit()
	_check(
		bool(audit.server_owns_movement_snapshot)
		and bool(audit.server_owns_ship_ownership_snapshot)
		and bool(audit.server_owns_projectile_snapshot)
		and bool(audit.server_owns_boarding_snapshot)
		and bool(audit.server_owns_respawn_snapshot)
		and not bool(audit.client_can_mutate_snapshot),
		"audit exposes one server-owned synchronization boundary without replica mutation"
	)


func _test_order_and_generation_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(
		authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn).accepted,
		"guard fixture publishes its initial generation-bearing state"
	)
	_check(
		authority.publish(99, 39, 13, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn).status == &"stale_server_tick",
		"late server ticks cannot replace authoritative state"
	)
	_check(
		authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn).status == &"stale_event_sequence",
		"duplicate authority events cannot replay a snapshot"
	)
	var invalid := _sections()
	(invalid.respawn[0] as Dictionary).entity_generation = 0
	_check(
		authority.publish(99, 41, 13, invalid.movement, invalid.ownership, invalid.projectiles, invalid.boarding, invalid.respawn).status == &"invalid_section_generation",
		"respawn records reject stale lifecycle generations before publication"
	)
	var duplicate := _sections()
	duplicate.ownership.append((duplicate.ownership[0] as Dictionary).duplicate(true))
	_check(
		authority.publish(99, 41, 13, duplicate.movement, duplicate.ownership, duplicate.projectiles, duplicate.boarding, duplicate.respawn).status == &"duplicate_section_identity",
		"duplicate ship identities cannot enter one synchronized snapshot"
	)
	var invalid_modifiers := _sections()
	(invalid_modifiers.ownership[0] as Dictionary)["weapon_power"] = 1.5
	_check(
		authority.publish(99, 41, 13, invalid_modifiers.movement, invalid_modifiers.ownership, invalid_modifiers.projectiles, invalid_modifiers.boarding, invalid_modifiers.respawn).status == &"invalid_component_modifiers",
		"component modifiers reject non-normalized authoritative values"
	)


func _test_replica_server_boundary() -> void:
	var server := Authority.new(99)
	var sections := _sections()
	_check(
		server.publish(99, 50, 20, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn).accepted,
		"server creates a replica packet from committed authority records"
	)
	var packet := server.get_snapshot()
	var replica := Authority.new(99)
	_check(
		replica.apply_replica(7, packet).status == &"unauthorized_source",
		"a client cannot inject a supposedly authoritative snapshot"
	)
	var applied := replica.apply_replica(99, packet)
	_check(
		applied.accepted
		and applied.status == &"replica_applied"
		and int(replica.get_snapshot().server_tick) == 50,
		"replica accepts the server packet and retains its ordering metadata"
	)
	_check(
		replica.apply_replica(99, packet).status == &"stale_snapshot",
		"replica rejects duplicate snapshots without advancing state"
	)
	(packet.sections.projectiles as Array)[0].state = &"client_mutated"
	_check(
		String((replica.get_section(&"projectiles")[0] as Dictionary).state) == "flying",
		"replica state is detached from transport packet mutation"
	)


func _sections() -> Dictionary:
	return {
		"movement": [{
			"entity_id": &"avatar_a",
			"entity_generation": 2,
			"owner_peer_id": 7,
			"mode": &"on_foot",
		}],
		"ownership": [{
			"ship_id": &"jovian_a",
			"ship_generation": 4,
			"owner_peer_id": 7,
			"ownership_generation": 1,
			"engine_power": 0.8,
			"weapon_power": 1.0,
			"targeting_power": 0.6,
			"engine_disabled": false,
			"weapon_disabled": false,
			"targeting_disabled": false,
		}],
		"projectiles": [{
			"projectile_id": &"projectile_1",
			"projectile_generation": 1,
			"source_entity_id": &"jovian_a",
			"source_generation": 4,
			"state": &"flying",
		}],
		"boarding": [{
			"seat_id": &"jovian_pilot",
			"seat_generation": 3,
			"occupant_peer_id": 7,
			"avatar_id": &"avatar_a",
			"vessel_id": &"jovian_a",
			"role": &"pilot",
		}],
		"respawn": [{
			"entity_id": &"jovian_a",
			"entity_generation": 4,
			"component_generation": 2,
			"state": &"active",
		}],
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
