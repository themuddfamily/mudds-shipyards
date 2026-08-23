extends SceneTree

## Focused composition of the existing server damage/respawn publication seam
## into canonical snapshots. No ENet peer or gameplay node is created: the
## server lifecycle ledger owns mutation and replicas only retain presentation.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	_check(
		server.register_damage_entity(1, &"damage_ship", 1, 1, 0.1, 0.0).accepted,
		"server registers one generation-scoped damage lifecycle"
	)
	var active := server.publish_damage_respawn_snapshot(
		&"damage_ship", 1, 100.0, &"active", false, 0, [], 1, _healthy_summary()
	)
	var canonical_active := server.publish_snapshot(1, [], [], [])
	var active_record := _damage_record(canonical_active.get("packet", {}), &"damage_ship")
	_check(
		active.accepted and canonical_active.accepted
		and int(canonical_active.packet.authority_peer_id) == 1
		and int(active_record.damage_revision) == 1
		and int(active_record.entity_generation) == 1
		and int(active_record.component_generation) == 1
		and is_equal_approx(float(active_record.maximum_health), 100.0)
		and is_equal_approx(float(active_record.engine_power), 1.0),
		"standalone health and component summary enter the canonical authority envelope"
	)
	var replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		replica.apply_replica_snapshot(1, canonical_active.packet).accepted
		and replica.get_authoritative_snapshot().sections.respawn[0].state == &"active",
		"a fresh replica receives current damage state without replaying mutation"
	)

	var damage_event := {
		"event_sequence": 1,
		"projectile_id": &"projectile_1",
		"target_entity_id": &"damage_ship",
		"target_generation": 1,
		"damage": 100.0,
	}
	var component_receipt := {
		"accepted": true,
		"reason": &"applied",
		"generation": 1,
		"sequence": 0,
		"component_id": &"hull",
		"applied_damage": 100.0,
	}
	var recorded := server.record_damage(
		&"damage_ship", 1, damage_event, component_receipt, true
	)
	var destroyed := server.publish_damage_respawn_snapshot(
		&"damage_ship", 1, 0.0, &"destroyed", true, 1, [], 2, _destroyed_summary()
	)
	var canonical_destroyed := server.publish_snapshot(2, [], [], [])
	var destroyed_record := _damage_record(canonical_destroyed.get("packet", {}), &"damage_ship")
	_check(
		recorded.accepted and destroyed.accepted and canonical_destroyed.accepted
		and destroyed_record.state == &"destroyed"
		and bool(destroyed_record.destroyed)
		and int(destroyed_record.damage_event_count) == 1
		and int(destroyed_record.recovery_generation) == 1,
		"server-owned destruction and recovery identity reach the canonical snapshot"
	)
	_check(
		replica.apply_replica_snapshot(1, canonical_destroyed.packet).accepted
		and replica.apply_replica_snapshot(1, canonical_active.packet).status == &"stale_snapshot",
		"replica rejects a reordered pre-destruction canonical envelope"
	)

	var ready := server.tick_damage_recovery(&"damage_ship", 1, 0.1)
	var reservation := {
		"accepted": true,
		"status": &"respawn_reserved",
		"respawn_token": &"respawn_token_1",
		"target_id": &"spawn_alpha",
	}
	var reserved := server.reserve_damage_respawn(&"damage_ship", 1, reservation)
	var pending := server.publish_damage_respawn_snapshot(
		&"damage_ship", 1, 0.0, &"respawn_pending", true, 1, [], 3,
		_destroyed_summary()
	)
	var canonical_pending := server.publish_snapshot(3, [], [], [])
	_check(
		ready.accepted and ready.status == &"recovery_ready" and reserved.accepted
		and pending.accepted and canonical_pending.accepted
		and _damage_record(canonical_pending.packet, &"damage_ship").state == &"respawn_pending",
		"recovery-ready reservation is presented as a server-owned pending respawn"
	)
	var commit := {
		"accepted": true,
		"status": &"respawn_committed",
		"entity_id": &"damage_ship",
		"entity_generation": 2,
		"target_id": &"spawn_alpha",
		"respawn_token": &"respawn_token_1",
	}
	var component_reset := {
		"accepted": true,
		"reason": &"reset",
		"generation": 2,
	}
	var committed := server.commit_damage_respawn(
		&"damage_ship", 1, commit, component_reset
	)
	var respawned := server.publish_damage_respawn_snapshot(
		&"damage_ship", 2, 100.0, &"active", false, 0, [], 4, _healthy_summary()
	)
	var canonical_respawned := server.publish_snapshot(4, [], [], [])
	var respawned_record := _damage_record(canonical_respawned.get("packet", {}), &"damage_ship")
	_check(
		committed.accepted and respawned.accepted and canonical_respawned.accepted
		and int(respawned_record.entity_generation) == 2
		and int(respawned_record.component_generation) == 2
		and respawned_record.state == &"active" and not bool(respawned_record.destroyed),
		"committed respawn advances entity and component generations before publication"
	)
	_check(
		server.publish_damage_respawn_snapshot(
			&"damage_ship", 1, 0.0, &"destroyed", true, 1, [], 5,
			_destroyed_summary()
		).status == &"stale_damage_entity",
		"retired entity generation cannot republish damage authority"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(
		late_replica.apply_replica_snapshot(1, canonical_respawned.packet).accepted
		and int(late_replica.get_authoritative_snapshot().sections.respawn[0].entity_generation) == 2,
		"late replica receives the current respawned generation only"
	)
	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	_check(
		client.publish_damage_respawn_snapshot(
			&"damage_ship", 2, 100.0, &"active", false, 0, [], 5,
			_healthy_summary()
		).status == &"authority_required"
		and client.publish_snapshot(5, [], [], []).status == &"authority_required"
		and client.commit_damage_respawn(&"damage_ship", 1, commit, component_reset).status == &"authority_required",
		"presentation replicas cannot publish or commit damage/respawn authority"
	)
	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_ENET_DAMAGE_CANONICAL_SNAPSHOT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _healthy_summary() -> Dictionary:
	return {
		"maximum_health": 100.0,
		"engine_power": 1.0,
		"weapon_power": 1.0,
		"targeting_power": 1.0,
		"engine_disabled": false,
		"weapon_disabled": false,
		"targeting_disabled": false,
	}


func _destroyed_summary() -> Dictionary:
	return {
		"maximum_health": 100.0,
		"engine_power": 0.0,
		"weapon_power": 0.0,
		"targeting_power": 0.0,
		"engine_disabled": true,
		"weapon_disabled": true,
		"targeting_disabled": true,
	}


func _damage_record(packet: Dictionary, entity_id: StringName) -> Dictionary:
	var sections := packet.get("sections", {}) as Dictionary
	for record_variant in sections.get(&"respawn", []) as Array:
		var record := record_variant as Dictionary
		if StringName(record.get("entity_id", &"")) == entity_id:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
