extends SceneTree

## A join that cannot become a session has to end as a stopped session.
##
## Two ways a join fails after `join()` has already reported `client_started`:
##   * nobody answers at the address, so ENet gives up and raises
##     `connection_failed` (not `server_disconnected`: it was never connected);
##   * the host answers but refuses the hello (here, a protocol mismatch).
## Either way the joining adapter must stop, say why, and be free to join again,
## and a refused peer must not keep an ENet slot on the host.
##
## Real loopback ENet, each adapter on its own `SceneMultiplayer` branch.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _branches: Array[Node] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _unanswered_join_stops_the_session()
	await _refused_hello_stops_the_client_and_frees_the_slot()
	for branch in _branches:
		if is_instance_valid(branch):
			branch.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_SESSION_JOIN_FAILURE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _unanswered_join_stops_the_session() -> void:
	var client := _make_adapter("UnansweredClient")
	var stops: Array[StringName] = []
	client.session_stopped.connect(func(reason: StringName) -> void: stops.append(reason))
	var port := _reserve_loopback_port()
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"a join to a silent loopback port starts connecting")
	# Keep ENet's give-up short so the suite does not wait out the default.
	var link: ENetPacketPeer = client._peer.get_peer(1)
	if link != null:
		link.set_timeout(50, 300, 600)
	var stopped := await _wait_until(func() -> bool: return not stops.is_empty(), 8.0)
	_check(stopped, "a join nobody answers ends as a stopped session")
	_check(stops.has(&"connection_failed"), "the stop says the connection failed (got %s)" % [stops])
	_check(not client.is_server() and not client._configured,
		"the failed join no longer holds the adapter")
	var again := client.join("127.0.0.1", port)
	_check(bool(again.get("accepted", false)),
		"the same adapter can join again after the failure (got %s)" % again.get("status"))
	client.shutdown(&"test_complete")


func _refused_hello_stops_the_client_and_frees_the_slot() -> void:
	var host := _make_adapter("RefusingHost")
	var client := _make_adapter("RefusedClient")
	var port := _reserve_loopback_port()
	_check(bool(host.host(port, 1).get("accepted", false)), "a one-slot host is listening")
	var stops: Array[StringName] = []
	client.session_stopped.connect(func(reason: StringName) -> void: stops.append(reason))
	client.configure_handshake_versions(Adapter.NETWORK_PROTOCOL_VERSION + 1, Adapter.NETWORK_BUILD_VERSION)
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"a mismatched client starts connecting")
	var stopped := await _wait_until(func() -> bool: return not stops.is_empty(), 6.0)
	_check(stopped, "a refused hello ends the client's session instead of leaving it connecting")
	_check(stops.has(&"protocol_version_mismatch"),
		"the client's stop carries the host's refusal (got %s)" % [stops])
	var freed := await _wait_until(func() -> bool: return host.multiplayer.get_peers().is_empty(), 6.0)
	_check(freed, "the host drops the refused peer's ENet link")
	_check(host._peer_generations.is_empty(), "the refused peer was never admitted")
	# The only slot is free again: a matching client is admitted.
	var good := _make_adapter("MatchingClient")
	_check(bool(good.join("127.0.0.1", port).get("accepted", false)), "a matching client connects")
	var admitted := await _wait_until(
		func() -> bool: return not good.get_server_offer().is_empty(), 6.0
	)
	_check(admitted, "the freed slot admits the next matching client")
	good.shutdown(&"test_complete")
	if client._configured:
		client.shutdown(&"test_complete")
	host.shutdown(&"test_complete")


func _make_adapter(branch_name: String) -> Adapter:
	var branch := SubViewport.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	_branches.append(branch)
	var adapter := Adapter.new()
	adapter.name = "NetworkSession"
	branch.add_child(adapter)
	return adapter


func _reserve_loopback_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append("FAIL: " + description)
