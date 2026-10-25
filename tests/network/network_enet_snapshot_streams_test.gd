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
	# Publish several revisions before admission so the late peer cannot have
	# the delta decoder baseline or revision-one ordering cursor.
	for tick in range(1, 6):
		_check(_server.publish_snapshot(tick, [{"entity_id": &"late-ship", "entity_generation": 1, "owner_peer_id": 1, "mode": &"authoritative"}], [], []).accepted, "publish before late join")
	_check(_client.join("127.0.0.1", port).accepted, "connect real ENet client")
	await _pump(func() -> bool: return not _client.get_server_offer().is_empty())
	_check(not _client.get_server_offer().is_empty(), "client admitted")
	# A host frame stall must not throttle a peer's reliable window down to one
	# MTU per round trip: both ends of the link hold the throttle at full scale.
	var host_link := (_server.multiplayer.multiplayer_peer as ENetMultiplayerPeer) \
		.get_peer(_client.multiplayer.get_unique_id())
	var client_link := (_client.multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
	_check(host_link != null and client_link != null
		and host_link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION) == 0
		and client_link.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION) == 0,
		"neither end of the link decelerates the ENet packet throttle")
	await _pump(func() -> bool: return _canonical.size() == 1)
	_check(_canonical.size() == 1 and _canonical[0].accepted, "late client immediately applies current full revision")
	_check(_client.get_authoritative_snapshot().revision == 5, "late join bootstraps latest published state")
	_check((_client.get_authoritative_snapshot().sections.movement as Array).size() == 1, "bootstrap carries current canonical entity records")
	_send_interior(1, 1)
	await _pump(func() -> bool: return _interior.size() == 1)
	_check(_interior.size() == 1 and _interior[0].status == &"moving_interior_presented", "interior revision one independently applies")
	_send_interior(3, 3)
	_server.publish_snapshot(6, [], [], [])
	await _pump(func() -> bool: return _canonical.size() == 2 and _interior.size() == 2)
	_check(_canonical.size() == 2 and _canonical[1].accepted, "canonical delta applies while interior revision waits")
	_check(_client.get_moving_interior_jitter_state().pending_revisions == [3], "interior future revision remains in its own buffer")
	_send_interior(2, 2)
	await _pump(func() -> bool: return _interior.size() == 3)
	_check(_client.get_moving_interior_jitter_state().next_revision == 4, "interior gap drains only interior packets")
	_check(_client.get_snapshot_jitter_state().next_revision == 7, "interior releases preserve canonical cursor")
	_server._send_moving_interior_resync.rpc_id(_client.multiplayer.get_unique_id(), {
		"authority_peer_id": 1, "recipient_peer_id": _client.multiplayer.get_unique_id(),
		"migration_generation": 2, "revision": 1, "relationships": [_relationship(1)],
	})
	_server.publish_snapshot(7, [], [], [])
	await _pump(func() -> bool: return _canonical.size() == 3)
	_check(_canonical.size() == 3 and _canonical[2].accepted, "interior resync preserves canonical decoder and cursor")
	_check(_client.get_moving_interior_jitter_state().migration_generation == 2, "interior resync resets its own generation")
	_check(_client.get_snapshot_jitter_state().migration_generation == 1, "interior resync preserves canonical generation")
	var another_branch := SubViewport.new()
	another_branch.name = "AnotherLateClient"
	root.add_child(another_branch)
	set_multiplayer(SceneMultiplayer.new(), another_branch.get_path())
	branches.append(another_branch)
	var another_client := Adapter.new()
	another_client.name = "Session"
	another_branch.add_child(another_client)
	_check(another_client.join("127.0.0.1", port).accepted, "second late peer connects alongside existing replica")
	await _pump(func() -> bool: return int(another_client.get_authoritative_snapshot().revision) == 7)
	_check(another_client.get_authoritative_snapshot().revision == 7, "second peer receives its own full baseline")
	for tick in range(8, 28):
		_server.publish_snapshot(tick, [], [], [])
		await _pump(func() -> bool: return int(_client.get_authoritative_snapshot().revision) == tick)
	_check(_client.get_authoritative_snapshot().revision == 27, "late join keeps receiving deltas across periodic full snapshots")
	await _pump(func() -> bool: return int(another_client.get_authoritative_snapshot().revision) == 27)
	_check(another_client.get_authoritative_snapshot().revision == 27, "per-peer bootstrap preserves both recipients subsequent deltas")
	_check(_canonical.size() == 23, "every publication since the bootstrap applies exactly once")
	_check(_client.get_snapshot_jitter_state().pending_revisions.is_empty(), "late join leaves no stranded canonical revisions")
	# The native link can disappear before SceneMultiplayer delivers its queued
	# peer-disconnected callback. Publications in that window must still reach
	# the other client, without trying an RPC on the retired native channel.
	var lost_peer := _client.multiplayer.get_unique_id()
	var live_peer := another_client.multiplayer.get_unique_id()
	var native_peer := _server.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var lost_revision := int(_server._moving_recipient_revisions.get(lost_peer, 0))
	var projectile_packets: Array[Dictionary] = []
	another_client.projectile_replica_packet.connect(func(packet: Dictionary, result: Dictionary) -> void:
		projectile_packets.append({"packet": packet, "result": result}))
	# Fill the existing per-recipient window, leaving one genuine deferred
	# update on both links before one native link closes.
	for index in range(17):
		var publication := _server.publish_projectile_snapshot(
			_projectile(StringName("disconnect_%02d" % index), 1),
			[lost_peer, live_peer], false, 1, false)
		_check(publication.accepted, "prepare bounded projectile window %d" % index)
	_check(int(_server.get_projectile_replication_budget(lost_peer).get("pending_count", 0)) == 1
		and int(_server.get_projectile_replication_budget(live_peer).get("pending_count", 0)) == 1,
		"both real recipients have one deferred projectile")
	await _pump(func() -> bool: return projectile_packets.size() == 16)
	_check(projectile_packets.size() == 16, "connected client receives the initial projectile window")
	var lost_budget := _server.get_projectile_replication_budget(lost_peer).duplicate(true)
	var lost_pending: Dictionary = (_server._projectile_recipient_pending.get(lost_peer, {}) as Dictionary).duplicate(true)
	var lost_published: Dictionary = (_server._projectile_published_generations.get(lost_peer, {}) as Dictionary).duplicate(true)
	native_peer.disconnect_peer(lost_peer, true)
	_check(_server._peer_generations.has(lost_peer), "native disconnect precedes queued admission cleanup")
	_check(_server.publish_projectile_snapshot(
		_projectile(&"disconnect_fresh", 11), [lost_peer, live_peer], false, 11, false).accepted,
		"fresh flying publication survives another recipient native disconnect")
	_check(_server.publish_projectile_snapshot(
		_projectile(&"disconnect_fresh", 12, &"expired"), [lost_peer, live_peer], true, 12).accepted,
		"terminal publication survives another recipient native disconnect")
	# No poll until this comparison: queued logical cleanup owns final removal.
	_check(_server.get_projectile_replication_budget(lost_peer) == lost_budget
		and _server._projectile_recipient_pending.get(lost_peer, {}) == lost_pending
		and _server._projectile_published_generations.get(lost_peer, {}) == lost_published,
		"closed native link consumes no immediate or deferred projectile delivery work")
	_check(bool((_server._projectile_authoritative_records.get(&"disconnect_fresh", {}) as Dictionary).get("terminal", false)),
		"canonical projectile terminal commits independently of recipient transport")
	_check(_server.publish_snapshot(28, [], [], []).accepted, "authority publication continues during native disconnect window")
	var moving_packet := {"relationship": _relationship(1), "server_tick": 1, "migration_generation": 1}
	_server._send_moving_interior_packet(lost_peer, moving_packet)
	_server._send_moving_interior_packet(lost_peer, {
		"authority_peer_id": 1, "recipient_peer_id": lost_peer,
		"migration_generation": 1, "revision": 1, "relationships": [],
	})
	_check(int(_server._moving_recipient_revisions.get(lost_peer, 0)) == lost_revision,
		"disconnected recipient cannot advance an undelivered moving revision")
	_server._send_moving_interior_packet(live_peer, moving_packet)
	# Role presenters share the same native disconnect window as both streams.
	for role: String in ["engineer", "gunner", "passenger"]:
		var revision := int(_server.get("_" + role + "_snapshot_revision"))
		var refused: Dictionary = _server.call("publish_" + role + "_snapshot", lost_peer, {})
		_check(not refused.accepted and refused.status == &"peer_not_connected"
			and int(_server.get("_" + role + "_snapshot_revision")) == revision,
			"closed native link refuses " + role + " publication without consuming a revision")
		var delivered: Dictionary = _server.call("publish_" + role + "_snapshot", live_peer, {"ship_id": &"live_role"})
		_check(delivered.accepted, "connected recipient still accepts " + role + " publication")
	await _pump(func() -> bool:
		return int(another_client.get_authoritative_snapshot().revision) == 28 \
			and int((another_client._moving_replica_samples.get(&"crew", {}) as Dictionary).get("server_tick", -1)) == 1)
	_check(another_client.get_authoritative_snapshot().revision == 28,
		"connected peer receives next canonical snapshot while the other native link is gone")
	_check(int((another_client._moving_replica_samples.get(&"crew", {}) as Dictionary).get("server_tick", -1)) == 1,
		"connected peer receives moving snapshot while the other native link is gone")
	await _pump(func() -> bool: return another_client.get_engineer_replica_snapshot().get("ship_id") == &"live_role" \
		and another_client.get_gunner_replica_snapshot().get("ship_id") == &"live_role" \
		and another_client.get_passenger_replica_snapshot().get("ship_id") == &"live_role")
	_check(another_client.get_engineer_replica_snapshot().get("ship_id") == &"live_role"
		and another_client.get_gunner_replica_snapshot().get("ship_id") == &"live_role"
		and another_client.get_passenger_replica_snapshot().get("ship_id") == &"live_role",
		"all three role views reach the connected client after the other native link closes")
	await _pump(func() -> bool: return projectile_packets.size() == 19)
	_check(projectile_packets.size() == 19, "survivor receives deferred update, fresh flight and terminal")
	if projectile_packets.size() == 19:
		var deferred := projectile_packets[16]
		var flying := projectile_packets[17]
		var terminal := projectile_packets[18]
		_check(deferred.result.accepted and deferred.packet.projectile.projectile_id == &"disconnect_16"
			and flying.result.accepted and flying.packet.projectile.projectile_id == &"disconnect_fresh"
			and flying.packet.projectile.state == &"flying"
			and terminal.result.accepted and terminal.packet.projectile.projectile_id == &"disconnect_fresh"
			and terminal.packet.terminal and terminal.packet.projectile.state == &"expired",
			"surviving real client accepts the exact deferred, flying and terminal sequence")
	_check(not another_client._projectile_replica_samples.has(&"disconnect_fresh")
		and int(another_client._projectile_replica_terminal_generations.get(&"disconnect_fresh", 0)) == 1,
		"terminal retires surviving replica and retains its generation fence")
	_check(not _server._peer_generations.has(lost_peer)
		and not _server._projectile_recipient_pending.has(lost_peer)
		and not _server._projectile_recipient_budgets.has(lost_peer),
		"normal queued disconnect cleanup retires old admission and projectile work")
	another_client.shutdown()
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


func _projectile(id: StringName, tick: int, state: StringName = &"flying") -> Dictionary:
	return {
		"projectile_id": id, "projectile_generation": 1,
		"source_entity_id": &"disconnect_source", "source_generation": 1,
		"owner_peer_id": 1, "position": Vector3.ONE, "direction": Vector3.FORWARD,
		"last_update_tick": tick, "state": state,
	}


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
