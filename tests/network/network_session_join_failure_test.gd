extends SceneTree

## A join that cannot become a session has to end as a stopped session.
##
## Ways a join fails after `join()` has already reported `client_started`:
##   * nobody answers at the address, so ENet gives up and raises
##     `connection_failed` (not `server_disconnected`: it was never connected);
##   * the host answers but refuses the hello (here, a protocol mismatch).
##   * the transport stays healthy but the host never offers admission.
## Either way the joining adapter must stop, say why, and be free to join again,
## and a refused peer must not keep an ENet slot on the host.
##
## Real loopback ENet, each adapter on its own `SceneMultiplayer` branch.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

class OrdinaryHeartbeat extends Node:
	var ticks := 0

	func _process(_delta: float) -> void:
		ticks += 1


var _assertions := 0
var _failures := PackedStringArray()
var _branches: Array[Node] = []
var _raw_hosts: Array[ENetMultiplayerPeer] = []
var _dropped_packets := 0
var _dropped_hellos := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var was_paused := paused
	var mouse_mode := Input.mouse_mode
	await _unanswered_join_stops_the_session()
	await _refused_hello_stops_the_client_and_frees_the_slot()
	if _failures.is_empty() and await _paused_non_admitting_host_reaches_deadline():
		await _cancelled_attempt_cannot_expire_its_replacement()
		await _fresh_retry_is_admitted_and_outlives_its_deadline()
	paused = was_paused
	Input.mouse_mode = mouse_mode
	for raw_host in _raw_hosts:
		raw_host.close()
	_raw_hosts.clear()
	for branch in _branches:
		if is_instance_valid(branch):
			var adapter := branch.get_node_or_null("NetworkSession") as Adapter
			if adapter != null:
				adapter.shutdown(&"test_complete")
				adapter.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
			set_multiplayer(null, branch.get_path())
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


func _paused_non_admitting_host_reaches_deadline() -> bool:
	var port := _reserve_loopback_port()
	var raw_host := _make_raw_host(port)
	var client := _make_adapter("PausedPendingClient")
	var heartbeat := OrdinaryHeartbeat.new()
	root.add_child(heartbeat)
	await process_frame
	var stops: Array[StringName] = []
	var stopped_at: Array[int] = []
	client.session_stopped.connect(func(reason: StringName) -> void:
		stops.append(reason)
		stopped_at.append(Time.get_ticks_msec())
	)
	var started_at := Time.get_ticks_msec()
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"the production-default pending join starts")
	var pending_peer: ENetMultiplayerPeer = client._peer
	var connected := await _wait_until(func() -> bool:
		return pending_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and _dropped_hellos > 0,
		1.0)
	_check(connected, "the raw host establishes a real ENet link and receives/discards the client's admission hello")
	if not connected:
		client.shutdown(&"test_complete")
		raw_host.close()
		heartbeat.queue_free()
		return false
	var heartbeat_before_pause := heartbeat.ticks
	paused = true
	var stopped := await _wait_until(func() -> bool: return not stops.is_empty(),
		maxf(0.0, float(started_at + 7000 - Time.get_ticks_msec()) / 1000.0))
	_check(heartbeat.ticks == heartbeat_before_pause,
		"ordinary gameplay processing stays frozen throughout the automatic paused deadline")
	if not stopped and pending_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_check(false, "the raw-host fixture must keep the native pending link alive for the full observation")
		paused = false
		client.shutdown(&"test_complete")
		raw_host.close()
		heartbeat.queue_free()
		return false
	# Freeze this single diagnostic before testing unchanged production. All
	# postconditions are gated so the missing runtime clock has one clear failure.
	_check(stopped,
		"BROWSER_JOIN_DEADLINE: a paused connected host withholding admission stops the pending join within 7 seconds")
	if not stopped:
		paused = false
		client.shutdown(&"test_complete")
		raw_host.close()
		heartbeat.queue_free()
		return false
	_check(_dropped_packets > 0 and client.get_server_offer().is_empty(),
		"the raw host services ENet while discarding admission RPC traffic")
	_check(stops == [&"connection_timeout"], "exactly one application deadline stops the join")
	_check(stopped_at[0] - started_at >= Adapter.HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS
		and stopped_at[0] - started_at < 7000,
		"the automatic deadline uses the authored 5000ms budget")
	_check(not client.is_session_active() and client._peer == null
		and client.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and pending_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED,
		"deadline synchronously closes the native peer and restores the offline API")
	_check(client.get_session_end_reason_snapshot().get("reason") == &"timeout",
		"application connection_timeout follows the existing normalized timeout end path")
	paused = false
	raw_host.close()
	heartbeat.queue_free()
	return true


func _cancelled_attempt_cannot_expire_its_replacement() -> void:
	var port := _reserve_loopback_port()
	var raw_host := _make_raw_host(port)
	var client := _make_adapter("ReplacementPendingClient")
	var stops: Array[StringName] = []
	var replacement_results: Array[Dictionary] = []
	# Real UI cancellation may synchronously begin another attempt from stopped.
	client.session_stopped.connect(func(reason: StringName) -> void:
		stops.append(reason)
		if reason == &"manual_cancel":
			replacement_results.append(client.join("127.0.0.1", port))
	)
	var old_started_at := Time.get_ticks_msec()
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"a cancellable production-default join starts")
	var old_peer: ENetMultiplayerPeer = client._peer
	await _wait_until(func() -> bool: return Time.get_ticks_msec() >= old_started_at + 1200, 1.5)
	client.cancel_direct_connect()
	var replacement_started_at := Time.get_ticks_msec()
	var replacement_peer: ENetMultiplayerPeer = client._peer
	_check(replacement_results.size() == 1 and bool(replacement_results[0].get("accepted", false))
		and replacement_peer != old_peer,
		"cancel callback can immediately replace the native pending peer")
	await _wait_until(func() -> bool:
		return Time.get_ticks_msec() >= old_started_at + Adapter.HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS + 200,
		5.0)
	_check(client.is_session_active() and client._peer == replacement_peer
		and stops == [&"manual_cancel"],
		"the cancelled attempt's old deadline cannot stop its pending replacement")
	var replacement_stopped := await _wait_until(func() -> bool: return stops.size() > 1, 2.0)
	_check(replacement_stopped and stops == [&"manual_cancel", &"connection_timeout"]
		and Time.get_ticks_msec() - replacement_started_at >= Adapter.HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS,
		"the reentrant replacement keeps its own complete automatic deadline")
	client.shutdown(&"test_complete")
	raw_host.close()


func _fresh_retry_is_admitted_and_outlives_its_deadline() -> void:
	var port := _reserve_loopback_port()
	var raw_host := _make_raw_host(port)
	var client := _make_adapter("RetryAdmittedClient")
	var stops: Array[StringName] = []
	client.session_stopped.connect(func(reason: StringName) -> void: stops.append(reason))
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"a retry fixture first starts a non-admitting join")
	var expired := await _wait_until(func() -> bool: return not stops.is_empty(), 7.0)
	_check(expired and stops == [&"connection_timeout"], "a fresh retry starts after actual application expiry")
	if not expired:
		client.shutdown(&"test_complete")
		raw_host.close()
		return
	raw_host.close()
	var host := _make_adapter("RetryAdmittingHost")
	_check(bool(host.host(port, 1).get("accepted", false)), "a real admission authority replaces the raw host")
	var retry_started_at := Time.get_ticks_msec()
	_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
		"the same expired adapter starts a fresh retry")
	var retry_peer: ENetMultiplayerPeer = client._peer
	var admitted := await _wait_until(func() -> bool: return not client.get_server_offer().is_empty(), 2.0)
	_check(admitted and not host._peer_generations.is_empty(),
		"the retry receives valid admission from the production host")
	await _wait_until(func() -> bool:
		return Time.get_ticks_msec() >= retry_started_at + Adapter.HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS + 200,
		6.0)
	_check(client.is_session_active() and client._peer == retry_peer
		and not client.get_server_offer().is_empty() and stops == [&"connection_timeout"],
		"a valid admitted session stays live beyond its retired join deadline")
	client.shutdown(&"test_complete")
	host.shutdown(&"test_complete")


func _make_raw_host(port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	_check(peer.create_server(port, 4) == OK, "a raw loopback host listens without admission code")
	_raw_hosts.append(peer)
	return peer


func _poll_raw_hosts() -> void:
	for peer in _raw_hosts:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			continue
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var packet := peer.get_packet()
			# Inspect only identifying bytes, never decode or answer the RPC.
			# An actual hello contains the protocol identity plus its schema keys.
			var wire_hex := packet.hex_encode()
			if wire_hex.contains("mudds_shipyards".to_utf8_buffer().hex_encode()) \
					and wire_hex.contains("peer_generation".to_utf8_buffer().hex_encode()) \
					and wire_hex.contains("package_generation".to_utf8_buffer().hex_encode()):
				_dropped_hellos += 1
			_dropped_packets += 1


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
		_poll_raw_hosts()
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
