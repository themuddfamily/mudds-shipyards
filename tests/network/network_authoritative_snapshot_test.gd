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
	_test_landing_lifecycle_guards()
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
	var published := authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing)
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
		and (copied_sections.respawn as Array).size() == 1
		and (copied_sections.landing as Array).size() == 1,
		"movement, ownership, projectile, boarding, respawn, and landing records synchronize together"
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
		and bool(audit.server_owns_landing_snapshot)
		and bool(audit.landing_records_are_presentation_only)
		and not bool(audit.client_can_mutate_snapshot),
		"audit exposes one server-owned synchronization boundary without replica mutation"
	)


func _test_order_and_generation_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(
		authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
		"guard fixture publishes its initial generation-bearing state"
	)
	_check(
		authority.publish(99, 39, 13, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).status == &"stale_server_tick",
		"late server ticks cannot replace authoritative state"
	)
	_check(
		authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).status == &"stale_event_sequence",
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
	var invalid_landing := _sections()
	(invalid_landing.landing[0] as Dictionary).position = Vector3(NAN, 0.0, 0.0)
	_check(
		authority.publish(99, 41, 13, invalid_landing.movement, invalid_landing.ownership, invalid_landing.projectiles, invalid_landing.boarding, invalid_landing.respawn, invalid_landing.landing).status == &"invalid_landing_record",
		"canonical landing records require a finite server-published pose"
	)


func _test_landing_lifecycle_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(
		authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
		"landing fixture publishes an approach-pending server record"
	)
	var aborted := _sections()
	(aborted.landing[0] as Dictionary).state = &"flying"
	(aborted.landing[0] as Dictionary).landing_revision = 6
	(aborted.landing[0] as Dictionary).landing_server_tick = 41
	_check(
		authority.publish(99, 41, 13, aborted.movement, aborted.ownership, aborted.projectiles, aborted.boarding, aborted.respawn, aborted.landing).accepted
		and authority.get_section(&"landing")[0].state == &"flying",
		"an authoritative abort advances the same entity to flying"
	)
	var reserved_again := _sections()
	(reserved_again.landing[0] as Dictionary).landing_revision = 7
	(reserved_again.landing[0] as Dictionary).landing_server_tick = 42
	_check(authority.publish(99, 42, 14, reserved_again.movement, reserved_again.ownership, reserved_again.projectiles, reserved_again.boarding, reserved_again.respawn, reserved_again.landing).accepted,
		"the server can reserve a later approach for the same generation")
	var landed := _sections()
	(landed.landing[0] as Dictionary).state = &"landed"
	(landed.landing[0] as Dictionary).landing_revision = 8
	(landed.landing[0] as Dictionary).landing_server_tick = 43
	_check(authority.publish(99, 43, 15, landed.movement, landed.ownership, landed.projectiles, landed.boarding, landed.respawn, landed.landing).accepted,
		"the committed berth occupancy advances to landed")
	var released := _sections()
	(released.landing[0] as Dictionary).state = &"flying"
	(released.landing[0] as Dictionary).entity_generation = 5
	(released.landing[0] as Dictionary).landing_revision = 9
	(released.landing[0] as Dictionary).landing_server_tick = 44
	_check(
		authority.publish(99, 44, 16, released.movement, released.ownership, released.projectiles, released.boarding, released.respawn, released.landing).accepted
		and int(authority.get_section(&"landing")[0].entity_generation) == 5,
		"berth release publishes flying only with the advanced entity generation"
	)
	var stale_generation := released.duplicate(true)
	(stale_generation.landing[0] as Dictionary).entity_generation = 4
	(stale_generation.landing[0] as Dictionary).landing_revision = 10
	(stale_generation.landing[0] as Dictionary).landing_server_tick = 45
	_check(
		authority.publish(99, 45, 17, stale_generation.movement, stale_generation.ownership, stale_generation.projectiles, stale_generation.boarding, stale_generation.respawn, stale_generation.landing).status == &"stale_landing_generation",
		"a newer envelope cannot regress a released landing entity generation"
	)
	var stale_revision := released.duplicate(true)
	(stale_revision.landing[0] as Dictionary).landing_revision = 8
	(stale_revision.landing[0] as Dictionary).landing_server_tick = 45
	_check(
		authority.publish(99, 45, 17, stale_revision.movement, stale_revision.ownership, stale_revision.projectiles, stale_revision.boarding, stale_revision.respawn, stale_revision.landing).status == &"stale_landing_revision",
		"a newer envelope cannot reorder an older landing record"
	)


func _test_replica_server_boundary() -> void:
	var server := Authority.new(99)
	var sections := _sections()
	_check(
		server.publish(99, 50, 20, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
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
		"landing": [{
			"entity_id": &"jovian_a",
			"entity_generation": 4,
			"landing_revision": 5,
			"landing_server_tick": 40,
			"position": Vector3(10.0, 0.0, 4.0),
			"state": &"landing_pending",
		}],
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
