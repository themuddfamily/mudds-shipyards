extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _failures: Array[String] = []
var _assertions := 0
var _canonical: Array[Dictionary] = []
var _interior: Array[Dictionary] = []
var _server: Adapter
var _client: Adapter


func _initialize() -> void:
	await process_frame
	var branches: Array[SubViewport] = []
	for branch_name in ["Server", "Client"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		branches.append(branch)
	_server = Adapter.new()
	_client = Adapter.new()
	_server.name = "Session"
	_client.name = "Session"
	branches[0].add_child(_server)
	branches[1].add_child(_client)
	_client.snapshot_applied.connect(func(result: Dictionary) -> void: _canonical.append(result))
	_client.moving_interior_result.connect(func(result: Dictionary) -> void: _interior.append(result))
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ENet port")
	var port := probe.get_local_port()
	probe.stop()
	_check(_server.host(port, 2).accepted, "host real ENet session")
	_check(_client.join("127.0.0.1", port).accepted, "connect real ENet client")
	await _pump(func() -> bool: return not _client.get_server_offer().is_empty())
	_check(not _client.get_server_offer().is_empty(), "client admitted")
	_server.publish_snapshot(1, [], [], [])
	await _pump(func() -> bool: return _canonical.size() == 1)
	_check(_canonical.size() == 1 and _canonical[0].accepted, "canonical revision one applies")
	_send_interior(1, 1)
	await _pump(func() -> bool: return _interior.size() == 1)
	_check(_interior.size() == 1 and _interior[0].status == &"moving_interior_presented", "interior revision one independently applies")
	_send_interior(3, 3)
	_server.publish_snapshot(2, [], [], [])
	await _pump(func() -> bool: return _canonical.size() == 2 and _interior.size() == 2)
	_check(_canonical.size() == 2 and _canonical[1].accepted, "canonical delta applies while interior revision waits")
	_check(_client.get_moving_interior_jitter_state().pending_revisions == [3], "interior future revision remains in its own buffer")
	_send_interior(2, 2)
	await _pump(func() -> bool: return _interior.size() == 3)
	_check(_client.get_moving_interior_jitter_state().next_revision == 4, "interior gap drains only interior packets")
	_check(_client.get_snapshot_jitter_state().next_revision == 3, "interior releases preserve canonical cursor")
	_server._send_moving_interior_resync.rpc_id(_client.multiplayer.get_unique_id(), {
		"authority_peer_id": 1, "recipient_peer_id": _client.multiplayer.get_unique_id(),
		"migration_generation": 2, "revision": 1, "relationships": [_relationship(1)],
	})
	_server.publish_snapshot(3, [], [], [])
	await _pump(func() -> bool: return _canonical.size() == 3)
	_check(_canonical.size() == 3 and _canonical[2].accepted, "interior resync preserves canonical decoder and cursor")
	_check(_client.get_moving_interior_jitter_state().migration_generation == 2, "interior resync resets its own generation")
	_check(_client.get_snapshot_jitter_state().migration_generation == 1, "interior resync preserves canonical generation")
	_client.shutdown()
	_server.shutdown()
	for branch in branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	if _failures.is_empty():
		print("NETWORK_ENET_SNAPSHOT_STREAMS_TEST_OK (%d assertions)" % _assertions)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)


func _send_interior(revision: int, tick: int) -> void:
	_server._broadcast_moving_interior_snapshot.rpc_id(_client.multiplayer.get_unique_id(), {
		"revision": revision, "server_tick": tick, "migration_generation": 1,
		"relationship": _relationship(tick),
	})


func _relationship(tick: int) -> Dictionary:
	return Relationship.create(tick, &"crew", 1, &"frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(float(tick), 0.0, 0.0))).get_snapshot()


func _pump(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and not predicate.call():
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
