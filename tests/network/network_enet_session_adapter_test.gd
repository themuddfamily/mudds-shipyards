extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const MovementIntent := preload("res://scripts/network/network_movement_intent.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")
const ProjectileIntent := preload("res://scripts/network/network_projectile_intent.gd")
const LandingIntent := preload("res://scripts/network/network_landing_intent.gd")
const MovingInteriorRelationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _failures: Array[String] = []
var _server: Adapter
var _client: Adapter
var _server_admissions: Array[Dictionary] = []
var _client_applies: Array[Dictionary] = []
var _movement_results: Array[Dictionary] = []
var _boarding_results: Array[Dictionary] = []
var _projectile_results: Array[Dictionary] = []
var _landing_results: Array[Dictionary] = []
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
	_server.boarding_intent_result.connect(func(result: Dictionary) -> void:
		_boarding_results.append(result)
	)
	_server.projectile_intent_result.connect(func(result: Dictionary) -> void:
		_projectile_results.append(result)
	)
	_server.landing_intent_result.connect(func(result: Dictionary) -> void:
		_landing_results.append(result)
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
	_check(
		bool(_server.register_boarding_ship(&"ship-1", 1, &"frame-1", 1).get("accepted", false)),
		"server registers the boarding ship and moving frame generations"
	)
	_check(
		bool(_server.register_boarding_seat(&"seat-1", &"ship-1", 1, &"pilot").get("accepted", false)),
		"server registers the authoritative pilot seat"
	)
	_check(bool(_server.set_boarding_server_tick(1).get("accepted", false)), "server opens the boarding tick window")
	var boarding = BoardingIntent.create(
		client_peer_id, &"avatar-1", &"ship-1", 1, &"frame-1", 1,
		&"seat-1", 1, &"pilot", 0, 1, BoardingIntent.ACTION_BOARD
	)
	_check(bool(_client.send_boarding_intent(boarding.to_dictionary()).get("accepted", false)), "client queues boarding intent over RPC")
	await _pump_until(func() -> bool: return _boarding_results.size() == 1, 3.0)
	_check(
		_boarding_results.size() == 1 and bool(_boarding_results[0].get("accepted", false)),
		"server accepts the admitted peer's boarding request"
	)
	_client.send_boarding_intent(boarding.to_dictionary())
	await _pump_until(func() -> bool: return _boarding_results.size() == 2, 3.0)
	_check(
		_boarding_results.size() == 2 and _boarding_results[1].get("status") == &"stale_sequence",
		"server rejects a replayed boarding sequence"
	)
	_check(
		bool(_server.register_projectile_source(
			client_peer_id, &"ship-1", 1, &"crew",
			{"pulse": {"speed": 20.0, "damage": 8.0, "lifetime": 2.0}}
		).get("accepted", false)),
		"server registers the admitted projectile source and weapon profile"
	)
	_check(bool(_server.set_projectile_server_tick(1).get("accepted", false)), "server opens the projectile tick window")
	var projectile = ProjectileIntent.create(
		client_peer_id, &"ship-1", 1, 1, 0, 1, &"pulse",
		Vector3.ZERO, Vector3.FORWARD
	)
	_check(bool(_client.send_projectile_intent(projectile.to_dictionary()).get("accepted", false)), "client queues fire intent over RPC")
	await _pump_until(func() -> bool: return _projectile_results.size() == 1, 3.0)
	_check(
		_projectile_results.size() == 1 and bool(_projectile_results[0].get("accepted", false)),
		"server spawns a projectile from the registered source profile"
	)
	_client.send_projectile_intent(projectile.to_dictionary())
	await _pump_until(func() -> bool: return _projectile_results.size() == 2, 3.0)
	_check(
		_projectile_results.size() == 2 and _projectile_results[1].get("status") == &"stale_sequence",
		"server rejects a replayed fire sequence"
	)
	_check(
		bool(_server.register_landing_entity(client_peer_id, &"ship-1", 1).get("accepted", false)),
		"server registers the admitted landing entity generation"
	)
	_check(
		bool(_server.register_landing_target(&"berth-1", &"shipyard", 1).get("accepted", false)),
		"server registers the authoritative landing target"
	)
	_check(bool(_server.set_landing_server_tick(1).get("accepted", false)), "server opens the landing tick window")
	var landing = LandingIntent.create(
		client_peer_id, &"ship-1", 1, 1, 0, 1,
		LandingIntent.ACTION_LANDING, &"shipyard", &"berth-1"
	)
	_check(bool(_client.send_landing_intent(landing.to_dictionary()).get("accepted", false)), "client queues landing intent over RPC")
	await _pump_until(func() -> bool: return _landing_results.size() == 1, 3.0)
	_check(
		_landing_results.size() == 1 and bool(_landing_results[0].get("accepted", false)),
		"server reserves a landing lease for the admitted ship"
	)
	_client.send_landing_intent(landing.to_dictionary())
	await _pump_until(func() -> bool: return _landing_results.size() == 2, 3.0)
	_check(
		_landing_results.size() == 2 and _landing_results[1].get("status") == &"stale_sequence",
		"server rejects a replayed landing sequence"
	)
	_check(
		bool(_server.register_damage_entity(client_peer_id, &"target-1", 1, 1, 1.0, 0.0).get("accepted", false)),
		"server registers the admitted damage lifecycle owner"
	)
	var damage_event := {
		"event_sequence": 1,
		"projectile_id": &"projectile-1",
		"target_entity_id": &"target-1",
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
	var damage_result := _server.record_damage(&"target-1", 1, damage_event, component_receipt, true)
	_check(
		bool(damage_result.get("accepted", false)) and damage_result.get("status") == &"damage_destroyed",
		"server records authoritative damage without trusting a client amount"
	)
	var recovery_result := _server.tick_damage_recovery(&"target-1", 1, 1.0)
	_check(
		bool(recovery_result.get("accepted", false)) and recovery_result.get("status") == &"recovery_ready",
		"server advances the generation-fenced recovery gate"
	)
	_check(
		_client.record_damage(&"target-1", 1, damage_event, component_receipt, false).get("status") == &"authority_required",
		"client cannot mutate the damage/respawn ledger"
	)
	_check(
		bool(_server.register_moving_interior_frame(&"frame-1", 1).get("accepted", false)),
		"server registers the authoritative moving-interior frame generation"
	)
	_check(
		bool(_server.register_moving_interior_occupancy(client_peer_id, &"avatar-1", 1, &"frame-1", 1).get("accepted", false)),
		"server binds admitted ownership to the frame generation"
	)
	_check(
		bool(_server.set_moving_interior_server_tick(10).get("accepted", false)),
		"server opens the moving-interior tick window"
	)
	var relationship := MovingInteriorRelationship.create(
		10, &"avatar-1", 1, &"frame-1", 1,
		Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0)), Vector3.ZERO, Vector3.ZERO, 1
	)
	var handoff := _server.handoff_moving_interior_sample({
		"snapshot": relationship.get_snapshot(),
		"arrival_time_seconds": 1.5,
	})
	_check(
		bool(handoff.get("accepted", false)) and handoff.get("status") == &"sample_handed_off",
		"server hands off an ordered frame-local relationship sample"
	)
	_check(
		_client.handoff_moving_interior_sample({}).get("status") == &"authority_required",
		"client cannot mutate moving-interior occupancy or relationship state"
	)
	_check(
		bool(_server.register_owned_ship(&"ownership-1", 1).get("accepted", false)),
		"server registers an unowned ship generation"
	)
	_check(
		bool(_server.claim_ship_for_peer(client_peer_id, &"ownership-1", 1, 0).get("accepted", false)),
		"server claims the ship for the admitted peer"
	)
	_check(
		_server.claim_ship_for_peer(client_peer_id, &"ownership-1", 1, 0).get("status") == &"stale_request_sequence",
		"replayed ship ownership requests are rejected"
	)
	_check(
		_client.claim_ship_for_peer(client_peer_id, &"ownership-1", 1, 1).get("status") == &"authority_required",
		"client cannot mutate ship ownership"
	)
	_check(
		bool(_server.register_crew_seat(&"ownership-seat", &"ownership-1", &"pilot", &"frame-1", 1).get("accepted", false)),
		"server registers a seat on the owned ship generation"
	)
	_check(
		bool(_server.claim_crew_seat(client_peer_id, &"avatar-1", &"ownership-seat", &"pilot", 0).get("accepted", false)),
		"server claims a crew seat for the admitted ship owner"
	)
	_check(
		_server.claim_crew_seat(client_peer_id, &"avatar-1", &"ownership-seat", &"pilot", 0).get("status") == &"stale_request_sequence",
		"replayed crew-seat claims are rejected"
	)
	_check(
		_server.transfer_crew_seat(client_peer_id, 99, &"avatar-1", &"ownership-seat", 1, 1).get("status") == &"peer_not_admitted",
		"crew-seat transfer requires an admitted destination peer"
	)
	_check(
		_client.claim_crew_seat(client_peer_id, &"avatar-1", &"ownership-seat", &"pilot", 1).get("status") == &"authority_required",
		"client cannot mutate crew-seat occupancy"
	)
	_check(
		bool(_server.bind_migration_attachment(
			client_peer_id, 1, &"ownership-seat", 1, &"ownership-1", 1,
			Vector3.ZERO, 25.0, 8
		).get("accepted", false)),
		"server binds the admitted peer's generation-bearing migration attachment"
	)
	_check(
		_client.rotate_session_migration(2).get("status") == &"authority_required",
		"client cannot rotate the authoritative migration epoch"
	)
	var prediction_register := _server.register_prediction_entity(client_peer_id, &"prediction_1", 1)
	_check(
		bool(prediction_register.get("accepted", false)),
		"server registers the admitted prediction owner generation"
	)
	var prediction_publish := _server.publish_prediction_snapshot(
		&"prediction_1", 1, 1, 1, Vector3(0.5, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)
	)
	_check(bool(prediction_publish.get("accepted", false)), "server publishes a bounded correction snapshot")
	var prediction_packet: Dictionary = prediction_publish.get("packet", {})
	var prediction_state := {
		"entity_id": &"prediction_1",
		"entity_generation": 1,
		"position": [0.0, 0.0, 0.0],
		"velocity": [0.0, 0.0, 0.0],
	}
	var correction := _client.apply_prediction_correction(1, prediction_state, prediction_packet)
	_check(
		bool(correction.get("accepted", false)) and correction.get("status") == &"correction_required",
		"client applies the server-owned bounded prediction correction"
	)
	var stale_prediction := prediction_packet.duplicate(true)
	stale_prediction["migration_generation"] = 0
	_check(
		_client.apply_prediction_correction(1, prediction_state, stale_prediction).get("status") == &"stale_migration_generation",
		"client rejects a correction from an old migration generation"
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
	var migration_before := _server.get_migration_snapshot()
	_check(
		(migration_before.get("peers", []) as Array).size() == 1
		and int(migration_before.get("latest_snapshot_revision", 0)) == 1,
		"migration state retains the admitted roster and latest snapshot revision"
	)
	var rotated_migration := _server.rotate_session_migration(2)
	_check(
		bool(rotated_migration.get("accepted", false))
		and int(_server.get_migration_snapshot().get("latest_snapshot_revision", 0)) == 1
		and not bool((_server.get_migration_snapshot().peers[0] as Dictionary).get("active", true)),
		"server rotation preserves snapshot generation while requiring peer rebind"
	)
	_server.shutdown()
	_client.shutdown()
	_check(
		(_server.get_boarding_snapshot().get("occupancies", []) as Array).is_empty(),
		"server disconnect cleanup releases boarding occupancy"
	)
	_check(
		_server.get_projectile(&"projectile_1").is_empty(),
		"server disconnect cleanup retires the peer-owned projectile source"
	)
	_check(
		_server.get_landing_entity(&"ship-1").is_empty(),
		"server disconnect cleanup retires the peer-owned landing entity"
	)
	_check(
		_server.get_damage_entity(&"target-1").is_empty(),
		"server disconnect cleanup retires the peer-owned damage lifecycle"
	)
	_check(
		_server.get_moving_interior_occupancy(&"avatar-1").is_empty(),
		"server disconnect cleanup releases peer-owned interior occupancy"
	)
	_check(
		int(_server.get_owned_ship(&"ownership-1").get("owner_peer_id", -1)) == 0,
		"server disconnect cleanup releases peer-owned ship ownership"
	)
	_check(
		_server.get_crew_assignment(client_peer_id, &"avatar-1").is_empty(),
		"server disconnect cleanup releases peer-owned crew seats"
	)
	_check(
		_server.get_prediction_entity(&"prediction_1").is_empty(),
		"server disconnect cleanup retires peer-owned prediction state"
	)
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
