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
	var stale := published_packet.duplicate(true)
	stale["projectile"] = _projectile(0, &"flying", Vector3.ZERO)
	_check(client._apply_projectile_replica_snapshot(stale).get("status") == &"invalid_projectile_snapshot",
		"malformed generation is rejected")
	var terminal_packet := published_packet.duplicate(true)
	terminal_packet["terminal"] = true
	terminal_packet["projectile"] = _projectile(1, &"expired", Vector3.ZERO)
	_check(client._apply_projectile_replica_snapshot(terminal_packet).get("status") == &"projectile_terminal_applied",
		"terminal packet retires client presentation")
	_check(int(client.get_presentation_cursor_audit().get("projectile_count", 0)) == 0,
		"terminal cleanup removes the replica cursor")
	var oversized := published_packet.duplicate(true)
	var oversized_projectile: Dictionary = _projectile(1, &"flying", Vector3.ZERO)
	oversized_projectile["padding"] = "x".repeat(7000)
	oversized["projectile"] = oversized_projectile
	_check(client._apply_projectile_replica_snapshot(oversized).get("status") == &"projectile_packet_too_large",
		"oversized packet is rejected")
	client._projectile_replica_migration_generation = 2
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
	server._projectile._projectiles[projectile.get("projectile_id")] = projectile.duplicate(true)
	var resync: Dictionary = server.publish_projectile_resync(2, 11)
	_check(bool(resync.get("accepted", false)) and int(resync.get("projectile_count", 0)) == 1,
		"late-join resync enumerates active authority projectiles")
	_check(server.publish_projectile_snapshot(projectile, [9]).get("status") == &"peer_not_admitted",
		"server rejects unknown recipient")
	server._on_peer_disconnected(2)
	_check(server.get_projectile_replication_budget(2).is_empty(), "disconnect clears projectile budget")
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


func _packet(projectile: Dictionary, tick: int, revision: int) -> Dictionary:
	var snapshot := projectile.duplicate(true)
	snapshot["last_update_tick"] = tick
	return {
		"revision": revision,
		"server_tick": tick,
		"migration_generation": 1,
		"projectile": snapshot,
		"terminal": false,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
