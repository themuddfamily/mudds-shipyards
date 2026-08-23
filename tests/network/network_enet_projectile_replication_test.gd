extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var projectile := _projectile(1, &"flying", Vector3(1.0, 2.0, 3.0))
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	for index in 16:
		_check(server.publish_projectile_snapshot(projectile, [2], false, 1).accepted,
			"bounded projectile publication is accepted")
	var coalesced: Dictionary = server.publish_projectile_snapshot(projectile, [2], false, 1)
	_check(coalesced.get("status") == &"projectile_snapshot_coalesced", "projectile presentation coalesces")
	var budget: Dictionary = server.get_projectile_replication_budget(2)
	_check(int(budget.get("coalesced_count", 0)) == 1, "projectile coalescing is measurable")
	var terminal: Dictionary = server.publish_projectile_snapshot(_projectile(1, &"expired", Vector3.ZERO), [2], false, 1)
	_check(bool(terminal.get("accepted", false)), "terminal transition bypasses presentation budget")
	_check(int(server.get_projectile_replication_budget(2).get("transition_count", 0)) >= 1,
		"terminal transition is retained")
	var client := Adapter.new()
	var published_packet: Dictionary = server.publish_projectile_snapshot(projectile, [], false, 11).get("packet", {}) as Dictionary
	_check(client._apply_projectile_replica_snapshot(published_packet).accepted, "client accepts flying projectile")
	_check(int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 1,
		"client stores presentation-only projectile state")
	_check(client._apply_projectile_replica_snapshot(published_packet).get("status") == &"stale_projectile_revision",
		"exact packet replay is rejected by its per-projectile revision")
	var equal_tick := published_packet.duplicate(true)
	equal_tick["revision"] = int(published_packet.get("revision", 0)) + 1
	_check(client._apply_projectile_replica_snapshot(equal_tick).get("status") == &"stale_projectile_tick",
		"a newer packet revision cannot replay an equal projectile tick")
	var stale := published_packet.duplicate(true)
	stale["projectile"] = _projectile(0, &"flying", Vector3.ZERO)
	_check(client._apply_projectile_replica_snapshot(stale).get("status") == &"invalid_projectile_snapshot",
		"malformed generation is rejected")
	var terminal_packet := published_packet.duplicate(true)
	terminal_packet["revision"] = int(published_packet.get("revision", 0)) + 2
	terminal_packet["terminal"] = true
	terminal_packet["projectile"] = _projectile(1, &"expired", Vector3.ZERO)
	terminal_packet.projectile.last_update_tick = 2
	_check(client._apply_projectile_replica_snapshot(terminal_packet).get("status") == &"projectile_terminal_applied",
		"terminal packet retires client presentation")
	_check(int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 0,
		"terminal cleanup removes the replica cursor")
	_check(client._apply_projectile_replica_snapshot(terminal_packet).get("status") == &"stale_projectile_revision",
		"terminal packet replay is rejected")
	var resurrection := _packet(_projectile(1, &"flying", Vector3.ONE), 12, int(terminal_packet.revision) + 1)
	_check(client._apply_projectile_replica_snapshot(resurrection).get("status") == &"projectile_generation_terminal",
		"a terminal generation cannot be resurrected by a later tick")
	var next_generation := _packet(_projectile(2, &"flying", Vector3.ONE), 13, int(resurrection.revision) + 1)
	var next_generation_result: Dictionary = client._apply_projectile_replica_snapshot(next_generation)
	_check(next_generation_result.get("status") == &"projectile_presented"
		and int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 1,
		"a strictly newer projectile generation replaces and presents after a terminal generation")
	var oversized := published_packet.duplicate(true)
	var oversized_projectile: Dictionary = _projectile(1, &"flying", Vector3.ZERO)
	oversized_projectile["padding"] = "x".repeat(7000)
	oversized["projectile"] = oversized_projectile
	_check(client._apply_projectile_replica_snapshot(oversized).get("status") == &"projectile_packet_too_large",
		"oversized packet is rejected")
	_check(client.reset_snapshot_jitter(3).accepted
		and client._projectile_replica_samples.is_empty()
		and client._projectile_replica_packet_revisions.is_empty()
		and client._projectile_replica_terminal_generations.is_empty()
		and client._projectile_jitter.get_snapshot().migration_generation == 3,
		"explicit reset clears projectile samples, replay fences, tombstones, and jitter")
	_check(client._apply_projectile_replica_snapshot(published_packet).get("status") == &"stale_migration_generation",
		"pre-migration packet cannot repopulate the replica")
	var ordering_client := Adapter.new()
	var tick_packet := _packet(_projectile(1, &"flying", Vector3.ZERO), 10, 1)
	_check(ordering_client._apply_projectile_replica_snapshot(tick_packet).accepted, "ordered baseline is accepted")
	var poisoned := _packet(_projectile(2, &"flying", Vector3.ONE), 9, 2)
	var poisoned_result: Dictionary = ordering_client._apply_projectile_replica_snapshot(poisoned)
	_check(poisoned_result.get("status") == &"stale_projectile_tick",
		"stale tick is rejected before generation mutation")
	var valid_old_generation := _packet(_projectile(1, &"flying", Vector3.ONE), 11, 3)
	var valid_old_result: Dictionary = ordering_client._apply_projectile_replica_snapshot(valid_old_generation)
	_check(bool(valid_old_result.get("accepted", false)),
		"valid prior generation remains usable after stale rejection")
	var migration_terminal := _packet(_projectile(1, &"expired", Vector3.ZERO), 12, 4)
	migration_terminal["terminal"] = true
	_check(ordering_client._apply_projectile_replica_snapshot(migration_terminal).accepted,
		"pre-migration terminal is accepted")
	var migrated := _packet(_projectile(1, &"flying", Vector3(2.0, 0.0, 0.0)), 1, 1, 2)
	_check(ordering_client._apply_projectile_replica_snapshot(migrated).accepted,
		"migration reset clears revision, tick, and terminal fences")
	_check(ordering_client.get_snapshot_jitter_state().migration_generation == 1,
		"shared snapshot jitter remains independent of projectile migration")
	_check(ordering_client._projectile_jitter.get_snapshot().migration_generation == 2,
		"projectile jitter adopts the new migration generation")
	var malformed_migration := _packet(_projectile(2, &"flying", Vector3.INF), 2, 2, 3)
	_check(ordering_client._apply_projectile_replica_snapshot(malformed_migration).get("status") == &"invalid_projectile_snapshot"
		and ordering_client._projectile_replica_migration_generation == 2
		and int(ordering_client.get_presentation_cursor_audit().get("projectile_count", 0)) == 1,
		"malformed higher-migration payload cannot wipe the accepted replica state")
	var invalid_revision_migration := _packet(_projectile(2, &"flying", Vector3.ZERO), 2, 0, 3)
	_check(ordering_client._apply_projectile_replica_snapshot(invalid_revision_migration).get("status") == &"invalid_projectile_snapshot"
		and ordering_client._projectile_replica_migration_generation == 2
		and int(ordering_client.get_presentation_cursor_audit().get("projectile_count", 0)) == 1,
		"invalid higher-migration envelope cannot reset an accepted replica")
	ordering_client._configured = true
	_check(ordering_client.shutdown(&"replication_test").accepted,
		"client shutdown is accepted")
	_check(ordering_client._projectile_replica_samples.is_empty()
		and ordering_client._projectile_replica_packet_revisions.is_empty()
		and ordering_client._projectile_replica_terminal_generations.is_empty()
		and ordering_client._projectile_jitter.get_snapshot().next_revision == 1,
		"shutdown clears projectile samples, replay fences, tombstones, and jitter")
	server._projectile_recipient_budgets.clear()
	server._projectile_recipient_pending.clear()
	server._projectile_published_generations.clear()
	for projectile_index in 40:
		var resync_projectile := projectile.duplicate(true)
		resync_projectile["projectile_id"] = StringName("projectile_resync_%02d" % projectile_index)
		server._projectile._projectiles[resync_projectile.projectile_id] = resync_projectile
	var resync: Dictionary = server.publish_projectile_resync(2, 11)
	var resync_budget := server.get_projectile_replication_budget(2)
	_check(bool(resync.get("accepted", false))
		and int(resync.get("projectile_count", 0)) == 40
		and int(resync_budget.get("snapshot_count", 0)) <= Adapter.PROJECTILE_MAX_SNAPSHOTS_PER_WINDOW
		and int(resync_budget.get("forced_transition_count", 0)) == 0
		and int(resync_budget.get("pending_count", 0)) == 24,
		"late-join resync enumerates authority projectiles without bypassing its bounded window")
	server.publish_projectile_snapshot(
		server.get_projectile(&"projectile_resync_39"), [2], false, 21, false
	)
	_check(int(server.get_projectile_replication_budget(2).get("pending_count", 0)) == 8,
		"a new budget window drains deferred snapshots by projectile identity exactly once")
	server.publish_projectile_snapshot(
		server.get_projectile(&"projectile_resync_00"), [2], false, 21
	)
	_check(int(server.get_projectile_replication_budget(2).get("forced_transition_count", 0)) == 0,
		"a drained resync records publication generation and cannot regain transition bypass")
	_check(server.publish_projectile_snapshot(projectile, [9]).get("status") == &"peer_not_admitted",
		"server rejects unknown recipient")
	server._projectile_replica_packet_revisions[&"disconnect_probe"] = 4
	server._projectile_replica_terminal_generations[&"disconnect_probe"] = 2
	server._projectile_replica_samples[&"disconnect_probe"] = {"position": Vector3.ZERO}
	server._projectile_jitter.push({"revision": 1, "server_tick": 1})
	server._on_peer_disconnected(2)
	_check(server.get_projectile_replication_budget(2).is_empty()
		and server._projectile_replica_packet_revisions.is_empty()
		and server._projectile_replica_terminal_generations.is_empty()
		and server._projectile_replica_samples.is_empty()
		and server._projectile_jitter.get_snapshot().next_revision == 1,
		"disconnect clears projectile budget, replica fences, samples, and jitter")
	server.free()
	client.free()
	ordering_client.free()
	if _failures.is_empty():
		print("OK: ENet projectile replication (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _projectile(generation: int, state: StringName, position: Vector3) -> Dictionary:
	return {
		"projectile_id": &"projectile_7",
		"projectile_generation": generation,
		"source_entity_id": &"bomber_1",
		"source_generation": 2,
		"owner_peer_id": 2,
		"position": position,
		"direction": Vector3.FORWARD,
		"last_update_tick": 1,
		"state": state,
}


func _packet(projectile: Dictionary, tick: int, revision: int, migration_generation: int = 1) -> Dictionary:
	var snapshot := projectile.duplicate(true)
	snapshot["last_update_tick"] = tick
	return {
		"revision": revision,
		"server_tick": tick,
		"migration_generation": migration_generation,
		"projectile": snapshot,
		"terminal": false,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
