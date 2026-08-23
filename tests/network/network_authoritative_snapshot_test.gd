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
	_test_damage_respawn_lifecycle_guards()
	_test_boarding_ownership_lifecycle_guards()
	_test_projectile_lifecycle_guards()
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
	var invalid_damage := _sections()
	(invalid_damage.respawn[0] as Dictionary).health = 101.0
	_check(
		authority.publish(99, 41, 13, invalid_damage.movement, invalid_damage.ownership, invalid_damage.projectiles, invalid_damage.boarding, invalid_damage.respawn, invalid_damage.landing).status == &"invalid_damage_record",
		"canonical damage records reject hull health beyond the bounded maximum"
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


func _test_damage_respawn_lifecycle_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
		"damage fixture publishes its active hull generation")
	var damaged := _sections()
	(damaged.respawn[0] as Dictionary).state = &"damaged"
	(damaged.respawn[0] as Dictionary).health = 60.0
	(damaged.respawn[0] as Dictionary).engine_power = 0.7
	(damaged.respawn[0] as Dictionary).damage_revision = 5
	(damaged.respawn[0] as Dictionary).damage_server_tick = 41
	_check(authority.publish(99, 41, 13, damaged.movement, damaged.ownership, damaged.projectiles, damaged.boarding, damaged.respawn, damaged.landing).accepted,
		"newer damage revision updates bounded hull and component presentation")
	var destroyed := damaged.duplicate(true)
	(destroyed.respawn[0] as Dictionary).state = &"destroyed"
	(destroyed.respawn[0] as Dictionary).health = 0.0
	(destroyed.respawn[0] as Dictionary).destroyed = true
	(destroyed.respawn[0] as Dictionary).recovery_generation = 4
	(destroyed.respawn[0] as Dictionary).damage_revision = 6
	(destroyed.respawn[0] as Dictionary).damage_server_tick = 42
	_check(authority.publish(99, 42, 14, destroyed.movement, destroyed.ownership, destroyed.projectiles, destroyed.boarding, destroyed.respawn, destroyed.landing).accepted,
		"destroyed hull enters the canonical recovery generation")
	var respawning := destroyed.duplicate(true)
	(respawning.respawn[0] as Dictionary).state = &"respawn_pending"
	(respawning.respawn[0] as Dictionary).damage_revision = 7
	(respawning.respawn[0] as Dictionary).damage_server_tick = 43
	_check(authority.publish(99, 43, 15, respawning.movement, respawning.ownership, respawning.projectiles, respawning.boarding, respawning.respawn, respawning.landing).accepted,
		"server-owned respawn reservation advances presentation without changing generation")
	var respawned := _sections()
	(respawned.respawn[0] as Dictionary).entity_generation = 5
	(respawned.respawn[0] as Dictionary).component_generation = 3
	(respawned.respawn[0] as Dictionary).damage_revision = 8
	(respawned.respawn[0] as Dictionary).damage_server_tick = 44
	_check(authority.publish(99, 44, 16, respawned.movement, respawned.ownership, respawned.projectiles, respawned.boarding, respawned.respawn, respawned.landing).accepted,
		"respawn advances both entity and component generations before active presentation")
	var stale_entity := respawned.duplicate(true)
	(stale_entity.respawn[0] as Dictionary).entity_generation = 4
	(stale_entity.respawn[0] as Dictionary).damage_revision = 9
	(stale_entity.respawn[0] as Dictionary).damage_server_tick = 45
	_check(authority.publish(99, 45, 17, stale_entity.movement, stale_entity.ownership, stale_entity.projectiles, stale_entity.boarding, stale_entity.respawn, stale_entity.landing).status == &"stale_damage_entity_generation",
		"newer envelope cannot regress the respawned entity generation")
	var stale_component := respawned.duplicate(true)
	(stale_component.respawn[0] as Dictionary).component_generation = 2
	(stale_component.respawn[0] as Dictionary).damage_revision = 9
	(stale_component.respawn[0] as Dictionary).damage_server_tick = 45
	_check(authority.publish(99, 45, 17, stale_component.movement, stale_component.ownership, stale_component.projectiles, stale_component.boarding, stale_component.respawn, stale_component.landing).status == &"stale_damage_component_generation",
		"newer envelope cannot regress component lifecycle generation")
	var stale_revision := respawned.duplicate(true)
	(stale_revision.respawn[0] as Dictionary).damage_revision = 7
	(stale_revision.respawn[0] as Dictionary).damage_server_tick = 45
	_check(authority.publish(99, 45, 17, stale_revision.movement, stale_revision.ownership, stale_revision.projectiles, stale_revision.boarding, stale_revision.respawn, stale_revision.landing).status == &"stale_damage_revision",
		"newer envelope cannot reorder an older damage lifecycle record")
	var stale_tick := respawned.duplicate(true)
	(stale_tick.respawn[0] as Dictionary).damage_revision = 9
	(stale_tick.respawn[0] as Dictionary).damage_server_tick = 43
	_check(authority.publish(99, 45, 17, stale_tick.movement, stale_tick.ownership, stale_tick.projectiles, stale_tick.boarding, stale_tick.respawn, stale_tick.landing).status == &"stale_damage_server_tick",
		"newer envelope cannot regress the per-entity damage server tick")


func _test_boarding_ownership_lifecycle_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
		"ownership fixture publishes one boarded seat")
	var transferred := _sections()
	(transferred.ownership[0] as Dictionary).owner_peer_id = 8
	(transferred.ownership[0] as Dictionary).owner_peer_generation = 1
	(transferred.ownership[0] as Dictionary).ownership_generation = 2
	(transferred.ownership[0] as Dictionary).ownership_revision = 4
	(transferred.ownership[0] as Dictionary).ownership_server_tick = 41
	(transferred.ownership[0] as Dictionary).state = &"transferred"
	(transferred.boarding[0] as Dictionary).occupant_peer_id = 8
	(transferred.boarding[0] as Dictionary).occupant_peer_generation = 1
	(transferred.boarding[0] as Dictionary).boarding_revision = 4
	(transferred.boarding[0] as Dictionary).boarding_server_tick = 41
	(transferred.boarding[0] as Dictionary).state = &"transferred"
	_check(authority.publish(99, 41, 13, transferred.movement, transferred.ownership, transferred.projectiles, transferred.boarding, transferred.respawn, transferred.landing).accepted,
		"server transfer advances owner and occupant generations with record revisions")
	var released := transferred.duplicate(true)
	(released.ownership[0] as Dictionary).owner_peer_id = 0
	(released.ownership[0] as Dictionary).owner_peer_generation = 0
	(released.ownership[0] as Dictionary).ownership_generation = 3
	(released.ownership[0] as Dictionary).ownership_revision = 5
	(released.ownership[0] as Dictionary).ownership_server_tick = 42
	(released.ownership[0] as Dictionary).state = &"released"
	(released.boarding[0] as Dictionary).occupant_peer_id = 0
	(released.boarding[0] as Dictionary).occupant_peer_generation = 0
	(released.boarding[0] as Dictionary).avatar_id = &""
	(released.boarding[0] as Dictionary).boarding_revision = 5
	(released.boarding[0] as Dictionary).boarding_server_tick = 42
	(released.boarding[0] as Dictionary).state = &"released"
	_check(authority.publish(99, 42, 14, released.movement, released.ownership, released.projectiles, released.boarding, released.respawn, released.landing).accepted,
		"released ownership and seat remain explicit presentation tombstones")
	var stale_owner_generation := released.duplicate(true)
	(stale_owner_generation.ownership[0] as Dictionary).ownership_generation = 2
	(stale_owner_generation.ownership[0] as Dictionary).ownership_revision = 6
	(stale_owner_generation.ownership[0] as Dictionary).ownership_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_owner_generation.movement, stale_owner_generation.ownership, stale_owner_generation.projectiles, stale_owner_generation.boarding, stale_owner_generation.respawn, stale_owner_generation.landing).status == &"stale_ownership_generation",
		"ownership generation cannot regress after release")
	var stale_owner_revision := released.duplicate(true)
	(stale_owner_revision.ownership[0] as Dictionary).ownership_revision = 4
	(stale_owner_revision.ownership[0] as Dictionary).ownership_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_owner_revision.movement, stale_owner_revision.ownership, stale_owner_revision.projectiles, stale_owner_revision.boarding, stale_owner_revision.respawn, stale_owner_revision.landing).status == &"stale_ownership_revision",
		"ownership record revision rejects reorder")
	var stale_owner_tick := released.duplicate(true)
	(stale_owner_tick.ownership[0] as Dictionary).ownership_revision = 6
	(stale_owner_tick.ownership[0] as Dictionary).ownership_server_tick = 41
	_check(authority.publish(99, 43, 15, stale_owner_tick.movement, stale_owner_tick.ownership, stale_owner_tick.projectiles, stale_owner_tick.boarding, stale_owner_tick.respawn, stale_owner_tick.landing).status == &"stale_ownership_server_tick",
		"ownership server tick rejects reordered transition records")
	var stale_seat_generation := released.duplicate(true)
	(stale_seat_generation.boarding[0] as Dictionary).seat_generation = 2
	(stale_seat_generation.boarding[0] as Dictionary).boarding_revision = 6
	(stale_seat_generation.boarding[0] as Dictionary).boarding_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_seat_generation.movement, stale_seat_generation.ownership, stale_seat_generation.projectiles, stale_seat_generation.boarding, stale_seat_generation.respawn, stale_seat_generation.landing).status == &"stale_boarding_seat_generation",
		"seat generation cannot regress after release")
	var stale_boarding_revision := released.duplicate(true)
	(stale_boarding_revision.boarding[0] as Dictionary).boarding_revision = 4
	(stale_boarding_revision.boarding[0] as Dictionary).boarding_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_boarding_revision.movement, stale_boarding_revision.ownership, stale_boarding_revision.projectiles, stale_boarding_revision.boarding, stale_boarding_revision.respawn, stale_boarding_revision.landing).status == &"stale_boarding_revision",
		"boarding record revision rejects reorder")
	var stale_boarding_tick := released.duplicate(true)
	(stale_boarding_tick.boarding[0] as Dictionary).boarding_revision = 6
	(stale_boarding_tick.boarding[0] as Dictionary).boarding_server_tick = 41
	_check(authority.publish(99, 43, 15, stale_boarding_tick.movement, stale_boarding_tick.ownership, stale_boarding_tick.projectiles, stale_boarding_tick.boarding, stale_boarding_tick.respawn, stale_boarding_tick.landing).status == &"stale_boarding_server_tick",
		"boarding server tick rejects reordered transition records")


func _test_projectile_lifecycle_guards() -> void:
	var authority := Authority.new(99)
	var sections := _sections()
	_check(authority.publish(99, 40, 12, sections.movement, sections.ownership, sections.projectiles, sections.boarding, sections.respawn, sections.landing).accepted,
		"projectile fixture publishes one active server-owned generation")
	var impacted := _sections()
	(impacted.projectiles[0] as Dictionary).projectile_revision = 4
	(impacted.projectiles[0] as Dictionary).projectile_server_tick = 41
	(impacted.projectiles[0] as Dictionary).terminal = true
	(impacted.projectiles[0] as Dictionary).state = &"impacted"
	_check(authority.publish(99, 41, 13, impacted.movement, impacted.ownership, impacted.projectiles, impacted.boarding, impacted.respawn, impacted.landing).accepted,
		"impact advances the exact projectile generation to a terminal tombstone")
	var resurrection := impacted.duplicate(true)
	(resurrection.projectiles[0] as Dictionary).projectile_revision = 5
	(resurrection.projectiles[0] as Dictionary).projectile_server_tick = 42
	(resurrection.projectiles[0] as Dictionary).terminal = false
	(resurrection.projectiles[0] as Dictionary).state = &"active"
	_check(authority.publish(99, 42, 14, resurrection.movement, resurrection.ownership, resurrection.projectiles, resurrection.boarding, resurrection.respawn, resurrection.landing).status == &"projectile_generation_terminal",
		"a newer envelope cannot resurrect an impacted projectile generation")
	var next_generation := _sections()
	(next_generation.projectiles[0] as Dictionary).projectile_generation = 2
	(next_generation.projectiles[0] as Dictionary).source_generation = 5
	(next_generation.projectiles[0] as Dictionary).projectile_revision = 5
	(next_generation.projectiles[0] as Dictionary).projectile_server_tick = 42
	(next_generation.projectiles[0] as Dictionary).state = &"spawned"
	_check(authority.publish(99, 42, 14, next_generation.movement, next_generation.ownership, next_generation.projectiles, next_generation.boarding, next_generation.respawn, next_generation.landing).accepted,
		"a strictly newer projectile and source generation can replace a tombstone")
	var stale_generation := next_generation.duplicate(true)
	(stale_generation.projectiles[0] as Dictionary).projectile_generation = 1
	(stale_generation.projectiles[0] as Dictionary).projectile_revision = 6
	(stale_generation.projectiles[0] as Dictionary).projectile_server_tick = 43
	(stale_generation.projectiles[0] as Dictionary).terminal = true
	(stale_generation.projectiles[0] as Dictionary).state = &"aborted"
	_check(authority.publish(99, 43, 15, stale_generation.movement, stale_generation.ownership, stale_generation.projectiles, stale_generation.boarding, stale_generation.respawn, stale_generation.landing).status == &"stale_projectile_generation",
		"a terminal record cannot regress the projectile lifecycle generation")
	var stale_source := next_generation.duplicate(true)
	(stale_source.projectiles[0] as Dictionary).projectile_id = &"projectile_2"
	(stale_source.projectiles[0] as Dictionary).projectile_generation = 1
	(stale_source.projectiles[0] as Dictionary).source_generation = 4
	(stale_source.projectiles[0] as Dictionary).projectile_revision = 6
	(stale_source.projectiles[0] as Dictionary).projectile_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_source.movement, stale_source.ownership, stale_source.projectiles, stale_source.boarding, stale_source.respawn, stale_source.landing).status == &"stale_projectile_source_generation",
		"a different projectile cannot regress its source lifecycle generation")
	var stale_revision := next_generation.duplicate(true)
	(stale_revision.projectiles[0] as Dictionary).projectile_revision = 4
	(stale_revision.projectiles[0] as Dictionary).projectile_server_tick = 43
	_check(authority.publish(99, 43, 15, stale_revision.movement, stale_revision.ownership, stale_revision.projectiles, stale_revision.boarding, stale_revision.respawn, stale_revision.landing).status == &"stale_projectile_revision",
		"projectile record revision rejects reordered lifecycle state")
	var stale_tick := next_generation.duplicate(true)
	(stale_tick.projectiles[0] as Dictionary).projectile_revision = 6
	(stale_tick.projectiles[0] as Dictionary).projectile_server_tick = 41
	_check(authority.publish(99, 43, 15, stale_tick.movement, stale_tick.ownership, stale_tick.projectiles, stale_tick.boarding, stale_tick.respawn, stale_tick.landing).status == &"stale_projectile_server_tick",
		"projectile server tick rejects reordered motion state")


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
		String((replica.get_section(&"projectiles")[0] as Dictionary).state) == "active",
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
			"owner_peer_generation": 4,
			"ownership_generation": 1,
			"ownership_revision": 3,
			"ownership_server_tick": 40,
			"state": &"owned",
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
			"owner_peer_id": 7,
			"projectile_revision": 3,
			"projectile_server_tick": 40,
			"position": Vector3(4.0, 1.0, 2.0),
			"terminal": false,
			"state": &"active",
		}],
		"boarding": [{
			"seat_id": &"jovian_pilot",
			"seat_generation": 3,
			"occupant_peer_id": 7,
			"occupant_peer_generation": 4,
			"avatar_id": &"avatar_a",
			"vessel_id": &"jovian_a",
			"ship_generation": 4,
			"role": &"pilot",
			"boarding_revision": 3,
			"boarding_server_tick": 40,
			"state": &"boarded",
		}],
		"respawn": [{
			"entity_id": &"jovian_a",
			"entity_generation": 4,
			"component_generation": 2,
			"damage_revision": 4,
			"damage_server_tick": 40,
			"health": 100.0,
			"maximum_health": 100.0,
			"destroyed": false,
			"recovery_generation": 0,
			"damage_event_count": 0,
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
