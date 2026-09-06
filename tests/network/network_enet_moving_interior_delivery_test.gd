extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _failures: Array[String] = []
var _assertions := 0


func _initialize() -> void:
	await process_frame
	var branches: Array[SubViewport] = []
	var adapters: Array[Adapter] = []
	for branch_name in ["Server", "ClientA", "ClientB"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		branches.append(branch)
		var adapter := Adapter.new()
		adapter.name = "Session"
		branch.add_child(adapter)
		adapters.append(adapter)
	var server := adapters[0]
	var client_a := adapters[1]
	var client_b := adapters[2]
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve UDP port")
	var port := probe.get_local_port()
	probe.stop()
	_check(server.host(port, 2).accepted, "host real ENet session")
	_check(client_a.join("127.0.0.1", port).accepted and client_b.join("127.0.0.1", port).accepted, "connect two recipients")
	await _pump(func() -> bool: return not client_a.get_server_offer().is_empty() and not client_b.get_server_offer().is_empty())
	var peer_a := client_a.multiplayer.get_unique_id()
	var peer_b := client_b.multiplayer.get_unique_id()
	server.publish_moving_interior_snapshot(_relationship(1), [peer_a], 1)
	server.publish_moving_interior_snapshot(_relationship(1), [peer_b], 1)
	await _pump(func() -> bool: return client_b.get_moving_interior_jitter_state().next_revision == 2)
	_check(client_b.get_moving_interior_jitter_state().next_revision == 2, "targeted publication starts each recipient at revision one")
	for tick in range(2, 11):
		server.publish_moving_interior_snapshot(_relationship(tick), [peer_a], 1)
	server.publish_moving_interior_snapshot(_relationship(11), [peer_a], 11)
	await _pump(func() -> bool: return _sample_tick(client_a) == 11)
	_check(_sample_tick(client_a) == 11, "coalesced revisions do not strand subsequent delivery")
	_check(client_a.get_moving_interior_jitter_state().pending_revisions.is_empty(), "recipient ordering has no gaps after coalescing")
	_check((server._moving_recipient_pending.get(peer_a, {}) as Dictionary).is_empty(), "flushed pending entries are retired")
	server._seat_moving_relationships["%d:crew" % peer_a] = _relationship(12)
	server._seat_moving_relationships["%d:other" % peer_a] = _relationship(3, &"other")
	_check(server.publish_moving_interior_resync(peer_a, 21).accepted, "publish resync containing independently timed entities")
	server.publish_moving_interior_snapshot(_relationship(13), [peer_a], 21)
	await _pump(func() -> bool: return _sample_tick(client_a) == 13)
	_check(_sample_tick(client_a) == 13, "snapshot after multi-entity resync continues recipient sequence")
	_check(_sample_tick(client_a, &"other") == 3, "resync preserves each entity own tick ordering")
	var prior_revision := int(client_a.get_moving_interior_jitter_state().next_revision)
	var stale_resync := {
		"authority_peer_id": 1, "recipient_peer_id": peer_a, "migration_generation": 1,
		"revision": 100, "snapshot_revision": 1, "relationships": [],
	}
	server._send_moving_interior_resync.rpc_id(peer_a, stale_resync)
	await _pump(func() -> bool: return client_a._last_result.get("status") == &"stale_moving_interior_resync")
	_check(client_a.get_moving_interior_jitter_state().next_revision == prior_revision,
		"stale resync cannot move recipient cursor backward")
	_check(client_a.get_moving_interior_jitter_state().pending_revisions.is_empty(),
		"resync and resumed delivery leave no stranded packets")
	for adapter in adapters:
		adapter.shutdown()
	for branch in branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	if _failures.is_empty():
		print("NETWORK_ENET_MOVING_INTERIOR_DELIVERY_TEST_OK (%d assertions)" % _assertions)
	for failure in _failures:
		printerr("FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)


func _relationship(tick: int, entity: StringName = &"crew") -> Dictionary:
	return Relationship.create(tick, entity, 1, &"frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(float(tick), 0.0, 0.0))).get_snapshot()


func _sample_tick(client: Adapter, entity: StringName = &"crew") -> int:
	return int((client._moving_replica_samples.get(entity, {}) as Dictionary).get("server_tick", -1))


func _pump(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not predicate.call():
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
