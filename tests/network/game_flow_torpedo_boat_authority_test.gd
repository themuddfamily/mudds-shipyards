extends SceneTree

## Exercises the production boat through GameFlow's real client/solo lifecycle.
const MainScene := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Replicator := preload("res://scripts/network/network_remote_projectile_replicator.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MainScene.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(Store.new(
		"user://torpedo-client-%d/data.json" % OS.get_process_id()
	))
	root.add_child(game)
	await process_frame
	await physics_frame
	var boat := game.get_node(^"TorpedoBoat") as TorpedoBoatOpponent
	var target := game.get_node(^"ArrowReconShip") as HeroShip
	var director := game.get_node(^"EncounterScenarios") as EncounterScenarioDirector
	game.start_shift()
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set_physics_process(false)
	boat.set_physics_process(false)
	_check(director.begin_torpedo_run(target), "solo production Torpedo Run starts")
	boat.call(&"_fire_at_target", target.global_position)
	_check(boat.get_torpedo_pool().get_active_torpedo_count() == 1,
		"solo boat opens a real seeker flight")
	boat.apply_damage(11.0, boat.global_position)
	var health := boat.get_health()
	var generation := int(boat.get("_activation_generation"))
	var scenario_generation := director.get_scenario_generation()
	var transform_before_join := boat.global_transform
	var target_before_join: Node3D = boat.get("_target")
	var charge_before_join := 0.65
	boat.set("_telegraph_remaining", charge_before_join)
	var collision_before_join := boat.collision_layer
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "select ephemeral session port")
	var port := probe.get_local_port()
	probe.stop()
	_check(bool(game.join_network_session("127.0.0.1", port).get("accepted", false)),
		"production client join starts")
	_check(boat.get_torpedo_pool().get_active_torpedo_count() == 0
		and game.combat_authority.get_active_projectile_flight_count() == 0,
		"joining retires retained solo seeker flights")
	boat.call(&"_fire_at_target", target.global_position)
	_check(boat.get_torpedo_pool().get_active_torpedo_count() == 0
		and game.combat_authority.get_active_projectile_flight_count() == 0,
		"client boat cannot launch a local authority seeker")
	_check(boat.get_last_shot_result().get("status") == &"client_projectile_authority_forbidden"
		and not boat.is_combat_source_registered()
		and game.combat_authority.get_source_id(boat) == 0
		and boat.collision_layer == 0 and not boat.visible
		and not bool(boat.get_lock_cue_snapshot().get("active", true)),
		"client boat owns no combat source, collision or local lock presentation")
	boat.get_torpedo_pool().bind_authority(game.combat_authority)
	var direct_launch := boat.get_torpedo_pool().launch(
		boat, boat.get_weapon_id(), boat.global_transform * boat.TORPEDO_TUBE_OFFSET,
		-boat.global_basis.z, target
	)
	_check(direct_launch.get("status") == &"client_projectile_authority_forbidden"
		and game.combat_authority.get_active_projectile_flight_count() == 0,
		"direct access to the retained client pool cannot open a resolver flight")
	boat.call(&"_physics_process", 0.5)
	_check(boat.global_transform.is_equal_approx(transform_before_join)
		and is_equal_approx(float(boat.get("_telegraph_remaining")), charge_before_join),
		"client AI freezes position and charged fire rather than advancing its own hunt")
	var encounter_elapsed := float(director.get("_elapsed"))
	var target_position := target.global_position
	target.global_position += Vector3(10000.0, 0.0, 0.0)
	director.call(&"_physics_process", director.scenario_time_limit + 1.0)
	target.global_position = target_position
	_check(director.is_board_sortie_running()
		and is_equal_approx(float(director.get("_elapsed")), encounter_elapsed)
		and not director.is_fire_authorized(boat),
		"retained client Torpedo Run survives a full timeout and distance withdrawal without granting fire")
	_check(not bool(boat.activate(Transform3D.IDENTITY).get("accepted", true))
		and not bool(boat.activate_with_result(Transform3D.IDENTITY).get("accepted", true)),
		"both public client activation paths fail before resetting retained solo state")
	boat.set_network_presentation_only(true)
	game.remove_child(boat)
	game.add_child(boat)
	await process_frame
	_check(not boat.is_combat_source_registered()
		and boat.get_torpedo_pool().get_active_torpedo_count() == 0,
		"retained boat reentry cannot re-register a client authority source")
	game.shutdown_network_session(&"test_complete")
	_check(boat.is_active() and boat.is_combat_source_registered()
		and boat.collision_layer == collision_before_join
		and is_equal_approx(boat.get_health(), health)
		and int(boat.get("_activation_generation")) == generation
		and boat.get("_target") == target_before_join
		and director.get_scenario_generation() == scenario_generation
		and director.is_board_sortie_running()
		and boat.get_torpedo_pool().get_active_torpedo_count() == 0,
		"disconnect restores the same solo encounter, hull, target and source without replaying seekers")
	director.call(&"_physics_process", 0.25)
	_check(is_equal_approx(float(director.get("_elapsed")), encounter_elapsed + 0.25),
		"solo encounter time resumes after client disconnect")
	boat.call(&"_fire_at_target", target.global_position)
	_check(boat.get_torpedo_pool().get_active_torpedo_count() == 1,
		"retained solo Torpedo Run can fire after disconnect")
	_check(bool(game.host_network_session(port, 1).get("accepted", false)),
		"production host can begin with a retained solo seeker already airborne")
	game._advance_network_remote_projectiles()
	var host_replicator := game._network_remote_projectile_replicator
	_check(host_replicator.get_active_flight_count() == 1,
		"host adopts the existing real seeker into the production projectile stream")
	var packets: Array[Dictionary] = []
	var selectors: Array = []
	host_replicator.set_publisher(func(projectile: Dictionary, terminal: bool, peers: Array) -> Dictionary:
		# Check late-peer selection separately; packet validation uses the real
		# publisher without opening another transport for this focused lifecycle.
		selectors.append(peers.duplicate())
		var published := game._publish_network_remote_projectile(projectile, terminal, [])
		if bool(published.get("accepted", false)):
			packets.append((published.get("packet", {}) as Dictionary).duplicate(true))
		return published
	)
	boat.get_torpedo_pool().step(0.2)
	for tick in Replicator.TORPEDO_UPDATE_INTERVAL_TICKS:
		game._advance_network_remote_projectiles()
	_check(not packets.is_empty(), "host restates the actual steered seeker")
	if not packets.is_empty():
		var client := Adapter.new()
		var client_flow := GameFlow.new()
		var client_replicator := Replicator.new()
		root.add_child(client_replicator)
		client_flow._network_session_mode = &"client"
		client_flow.network_session = client
		client_flow._network_remote_projectile_replicator = client_replicator
		var packet := packets.back() as Dictionary
		var applied := client._apply_projectile_replica_snapshot(packet)
		var presented := client_flow._on_projectile_replica_packet(packet, applied)
		_check(bool(applied.get("accepted", false)) and bool(presented.get("accepted", false))
			and int(client_replicator.get_audit().get("drawn", 0)) == 1
			and not bool((packet.get("projectile", {}) as Dictionary).get(Replicator.RECORD_KEY, {}).get("launch", true))
			and client_flow.combat_authority == null,
			"adopted host seeker has one client visual and cannot replay launch audio")
		_check(host_replicator.republish_for_peer(2) == 1 and selectors.back() == [2],
			"late peer is sent the one adopted seeker through the existing resync selector")
		var late_client := Adapter.new()
		var late_flow := GameFlow.new()
		var late_replicator := Replicator.new()
		root.add_child(late_replicator)
		late_flow._network_session_mode = &"client"
		late_flow.network_session = late_client
		late_flow._network_remote_projectile_replicator = late_replicator
		var late_packet := packets.back() as Dictionary
		var late_applied := late_client._apply_projectile_replica_snapshot(late_packet)
		var late_presented := late_flow._on_projectile_replica_packet(late_packet, late_applied)
		_check(bool(late_presented.get("accepted", false))
			and int(late_replicator.get_audit().get("drawn", 0)) == 1
			and not bool((late_packet.get("projectile", {}) as Dictionary).get(Replicator.RECORD_KEY, {}).get("launch", true))
			and late_flow.combat_authority == null,
			"late client draws one adopted seeker without owning combat or replaying its launch")
		boat.deactivate()
		var terminal := packets.back() as Dictionary
		var ended := client_flow._on_projectile_replica_packet(
			terminal, client._apply_projectile_replica_snapshot(terminal))
		_check(bool(terminal.get("terminal", false)) and bool(ended.get("accepted", false))
			and host_replicator.get_active_flight_count() == 0
			and game.combat_authority.get_active_projectile_flight_count() == 0
			and not bool(client._apply_projectile_replica_snapshot(packet).get("accepted", true)),
			"host teardown publishes a terminal fence that cannot resurrect the retired seeker")
		client_flow.free()
		client.free()
		client_replicator.queue_free()
		late_flow.free()
		late_client.free()
		late_replicator.queue_free()
	game.shutdown_network_session(&"test_complete")
	director.abort()
	_check(not bool(game.join_network_session("127.0.0.1", -1).get("accepted", true))
		and game._network_session_mode == &"", "refused join settles back to solo")
	_check(director.begin_torpedo_run(target), "solo Torpedo Run restarts after host teardown")
	boat.call(&"_fire_at_target", target.global_position)
	_check(boat.get_torpedo_pool().get_active_torpedo_count() == 1,
		"refused client join leaves fresh solo authority usable")
	game._handle_server_browser_intent({"action": &"manual_join", "address": "127.0.0.1", "port": port})
	_check(game._network_session_mode == &"client"
		and boat.get_torpedo_pool().get_active_torpedo_count() == 0
		and not boat.is_combat_source_registered(),
		"manual server browser join uses the same client suspension")
	root.remove_child(game)
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game._network_session_mode == &"" and boat.is_combat_source_registered()
		and boat.get_torpedo_pool().get_active_torpedo_count() == 0,
		"whole Main reentry closes the client and resumes solo without old flights")
	var session := game._ensure_network_session()
	_check(bool(session.apply_server_directory_snapshot(1, 1, [{
		"session_id": &"torpedo_join", "host_peer_id": 1, "title": "Torpedo Run",
		"region_id": &"loopback", "ping_ms": 0, "player_count": 1, "max_players": 2,
	}]).get("accepted", false)), "production directory admits an advertised join entry")
	game._handle_server_browser_intent({"action": &"join", "session_id": &"torpedo_join"})
	_check(game._network_session_mode == &"client" and not boat.is_combat_source_registered(),
		"advertised server browser join also suspends local torpedo authority")
	game.shutdown_network_session(&"test_complete")
	game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_TORPEDO_BOAT_AUTHORITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
