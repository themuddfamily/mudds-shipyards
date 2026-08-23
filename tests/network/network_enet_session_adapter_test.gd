extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const MovementIntent := preload("res://scripts/network/network_movement_intent.gd")

var _failures: Array[String] = []
var _server: Adapter
var _client: Adapter
var _server_admissions: Array[Dictionary] = []
var _client_applies: Array[Dictionary] = []
var _movement_results: Array[Dictionary] = []
var _branches: Array[Dictionary] = []


func _initialize() -> void:
	var server_branch := SubViewport.new()
	server_branch.name = "NetworkServerBranch"
	var client_branch := SubViewport.new()
	client_branch.name = "NetworkClientBranch"
	root.add_child(server_branch)
	root.add_child(client_branch)
	await process_frame
	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	set_multiplayer(server_api, server_branch.get_path())
	set_multiplayer(client_api, client_branch.get_path())
	_server = Adapter.new()
	_client = Adapter.new()
	_server.name = "NetworkSession"
	_client.name = "NetworkSession"
	server_branch.add_child(_server)
	client_branch.add_child(_client)
	await process_frame
	_branches = [
		{"root": server_branch, "path": server_branch.get_path()},
		{"root": client_branch, "path": client_branch.get_path()},
	]
	_server.peer_admitted.connect(func(peer_id: int, receipt: Dictionary) -> void:
		_server_admissions.append({"peer_id": peer_id, "receipt": receipt})
	)
	_server.movement_intent_result.connect(func(result: Dictionary) -> void:
		_movement_results.append(result)
	)
	_client.snapshot_applied.connect(func(result: Dictionary) -> void:
		_client_applies.append(result)
	)
	var port := _reserve_udp_port()
	var started := _server.host(port, 2)
	_check(bool(started.get("accepted", false)), "server binds an ephemeral ENet port")
	var joined := _client.join("127.0.0.1", _server.get_local_port())
	_check(bool(joined.get("accepted", false)), "client starts against the server port")
	await _pump_until(func() -> bool: return _server_admissions.size() == 1, 3.0)
	_check(_server_admissions.size() == 1, "server admits the connected client through the hello RPC")
	if _server_admissions.size() == 1:
		_check(
			int(_server_admissions[0].get("peer_id", 0)) == _client.multiplayer.get_unique_id(),
			"admission is bound to the transport peer identity"
		)
		_check(not _client.get_server_offer().is_empty(), "client receives the server admission offer")
	var client_peer_id := _client.multiplayer.get_unique_id()
	_check(
		bool(_server.register_avatar(client_peer_id, &"avatar-1", 1).get("accepted", false)),
		"server registers the admitted client's movement avatar"
	)
	_check(bool(_server.set_movement_server_tick(1).get("accepted", false)), "server opens the movement tick window")
	var intent = MovementIntent.create(
		client_peer_id, &"avatar-1", 1, 1, 0, 1, Vector2.RIGHT
	)
	_check(bool(_client.send_movement_intent(intent.to_dictionary()).get("accepted", false)), "client queues movement intent over RPC")
	await _pump_until(func() -> bool: return _movement_results.size() == 1, 3.0)
	_check(
		_movement_results.size() == 1 and bool(_movement_results[0].get("accepted", false)),
		"server accepts the owner-bound movement intent"
	)
	_client.send_movement_intent(intent.to_dictionary())
	await _pump_until(func() -> bool: return _movement_results.size() == 2, 3.0)
	_check(
		_movement_results.size() == 2 and _movement_results[1].get("status") == &"stale_sequence",
		"server rejects a replayed movement sequence"
	)
	var spoofed_intent = MovementIntent.create(
		client_peer_id + 1, &"avatar-1", 1, 1, 1, 1, Vector2.LEFT
	)
	_client.send_movement_intent(spoofed_intent.to_dictionary())
	await _pump_until(func() -> bool: return _movement_results.size() == 3, 3.0)
	_check(
		_movement_results.size() == 3 and _movement_results[2].get("status") == &"spoofed_peer",
		"server rejects a movement packet that spoofs its peer identity"
	)
	var movement := [{
		"entity_id": &"player-1",
		"entity_generation": 1,
		"owner_peer_id": 2,
		"mode": &"authoritative",
	}]
	var published := _server.publish_snapshot(1, movement, [], [])
	_check(bool(published.get("accepted", false)), "server publishes an authoritative snapshot")
	await _pump_until(func() -> bool: return _client_applies.size() == 1, 3.0)
	_check(_client_applies.size() == 1, "client applies the server snapshot through RPC")
	if _client_applies.size() == 1:
		_check(bool(_client_applies[0].get("accepted", false)), "replica accepts the ordered server snapshot")
		_check(
			_client.get_authoritative_snapshot().get("server_tick", -1) == 1,
			"replica exposes the server tick after transport delivery"
		)
	_check(
		not bool(_client.publish_snapshot(2, [], [], []).get("accepted", true)),
		"client cannot publish an authoritative snapshot"
	)
	_server.shutdown()
	_client.shutdown()
	_check(
		(_server.get_snapshot().get("lifecycle", {}) as Dictionary).get("peers", []).is_empty(),
		"server shutdown leaves no admitted peer records"
	)
	for branch in _branches:
		var branch_root := branch.get("root") as Node
		var branch_path: NodePath = branch.get("path")
		if is_instance_valid(branch_root):
			branch_root.free()
		set_multiplayer(null, branch_path)
	print("NETWORK_ENET_SESSION_ADAPTER_TEST_OK (%d assertions)" % _assertions)
	quit(0 if _failures.is_empty() else 1)


var _assertions := 0


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		printerr("FAIL: %s" % message)


func _pump_until(predicate: Callable, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and not bool(predicate.call()):
		await process_frame


func _reserve_udp_port() -> int:
	var probe := UDPServer.new()
	var status := probe.listen(0, "127.0.0.1")
	_check(status == OK, "test reserves a local UDP port")
	var port := probe.get_local_port()
	probe.stop()
	return port
