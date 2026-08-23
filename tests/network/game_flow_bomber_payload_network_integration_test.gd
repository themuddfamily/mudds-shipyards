extends SceneTree

const GameFlow := preload("res://scripts/game/game_flow.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Projectile := preload("res://scripts/combat/bomber_payload_projectile.gd")
const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var server_flow := GameFlow.new()
	var server_bomber := Bomber.new()
	server_bomber.name = &"ServerCinderBomber"
	root.add_child(server_bomber)
	await process_frame
	server_flow.network_session = server
	server_flow._network_session_mode = &"server"
	server_flow.active_ship = server_bomber
	server_flow._piloting = true
	server_bomber.set_piloted(true)
	_check(server_flow._ensure_bomber_payload_session(server_bomber),
		"server starts the real bomber payload generation")
	var released: Dictionary = server_flow._consume_bomber_payload_release()
	var launch_packet := server._last_result.get("packet", {}) as Dictionary
	var launch_projectile := launch_packet.get("projectile", {}) as Dictionary
	_check(bool(released.get("accepted", false))
		and server_flow._bomber_payload_projectiles.size() == 1,
		"real bomber release creates one server-owned production projectile")
	_check(int(launch_projectile.get("last_update_tick", 0)) == 1
		and not (launch_projectile.get("release_record", {}) as Dictionary).is_empty()
		and (launch_projectile.get("terminal_intent", {}) as Dictionary).is_empty(),
		"launch publishes a strict tick and its exact release record")
	var projectile := server_flow._bomber_payload_projectiles[0]
	var launch_position: Vector3 = projectile.get_snapshot().get("position", Vector3.ZERO)
	server_flow._advance_bomber_payload_loop(0.05)
	var tick_packet := server._last_result.get("packet", {}) as Dictionary
	var tick_projectile := tick_packet.get("projectile", {}) as Dictionary
	_check(int(tick_projectile.get("last_update_tick", 0)) == 2
		and (tick_projectile.get("position", Vector3.ZERO) as Vector3).distance_to(launch_position) > 0.01,
		"server physics advances and publishes the next strict projectile tick")
	server._peer_generations[3] = 1
	server_flow._on_network_peer_admitted(3, {})
	var late_join_packet := server._last_result.get("packet", {}) as Dictionary
	_check(int(server._last_result.get("recipients", 0)) == 1
		and StringName((late_join_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
			== StringName(launch_projectile.get("projectile_id", &"")),
		"late join republishes the live GameFlow projectile to the admitted peer")

	var client := Adapter.new()
	var client_flow := GameFlow.new()
	var client_bomber := Bomber.new()
	client_bomber.name = &"ClientCinderBomber"
	root.add_child(client_bomber)
	await process_frame
	client_flow.network_session = client
	client_flow._network_session_mode = &"client"
	client_flow.active_ship = client_bomber
	client_flow._piloting = true
	client_flow.ships.append(client_bomber)
	client_bomber.set_piloted(true)
	var launch_applied: Dictionary = client._apply_projectile_replica_snapshot(launch_packet)
	client_flow._on_projectile_replica_packet(launch_packet, launch_applied)
	var client_visuals: Array = client_bomber.get_payload_presentation().get_active_snapshots()
	_check(bool(launch_applied.get("accepted", false)) and client_visuals.size() == 1
		and StringName((client_visuals[0] as Dictionary).get("phase", &"")) == &"flight",
		"client consumes the accepted launch into presentation only")
	var tick_applied: Dictionary = client._apply_projectile_replica_snapshot(tick_packet)
	client_flow._on_projectile_replica_packet(tick_packet, tick_applied)
	_check(bool(tick_applied.get("accepted", false))
		and client_flow._bomber_payload_projectiles.is_empty(),
		"client accepts server ticks without creating a local physics projectile")
	_check(client_flow._consume_bomber_payload_release().get("reason")
			== &"client_projectile_authority_forbidden",
		"client payload input cannot acquire release authority")
	client_flow._advance_bomber_payload_loop(0.25)
	_check(client_flow._bomber_payload_projectiles.is_empty()
		and not bool(client_bomber.get_payload_authority_snapshot().get("active", false)),
		"client loop never advances projectile physics, collision, or combat authority")

	var impact := projectile.submit_impact(
		1, projectile.get_snapshot().get("position", Vector3.ZERO), Vector3.UP
	)
	server_flow._bomber_payload_server_tick += 1
	var terminal_published := server_flow._publish_bomber_payload_network(projectile, true)
	var terminal_packet := terminal_published.get("packet", {}) as Dictionary
	var terminal_projectile := terminal_packet.get("projectile", {}) as Dictionary
	_check(bool(impact.get("accepted", false)) and bool(terminal_published.get("accepted", false))
		and int(terminal_projectile.get("last_update_tick", 0)) == 3
		and not (terminal_projectile.get("terminal_intent", {}) as Dictionary).is_empty(),
		"authoritative terminal publishes once on the next strict tick with its exact intent")
	var terminal_applied: Dictionary = client._apply_projectile_replica_snapshot(terminal_packet)
	client_flow._on_projectile_replica_packet(terminal_packet, terminal_applied)
	client_visuals = client_bomber.get_payload_presentation().get_active_snapshots()
	_check(terminal_applied.get("status") == &"projectile_terminal_applied"
		and client_visuals.size() == 1
		and StringName((client_visuals[0] as Dictionary).get("phase", &"")) == &"terminal",
		"client terminal retires flight and presents only the server terminal record")

	var migrated_packet := launch_packet.duplicate(true)
	migrated_packet["revision"] = 1
	migrated_packet["server_tick"] = 1
	migrated_packet["migration_generation"] = 2
	migrated_packet["projectile"] = launch_projectile.duplicate(true)
	migrated_packet.projectile.projectile_generation = 4
	migrated_packet.projectile.source_generation = 4
	migrated_packet.projectile.last_update_tick = 1
	migrated_packet.projectile.release_record = (
		launch_projectile.get("release_record", {}) as Dictionary
	).duplicate(true)
	migrated_packet.projectile.release_record.generation = 4
	var migrated_applied: Dictionary = client._apply_projectile_replica_snapshot(migrated_packet)
	client_flow._on_projectile_replica_packet(migrated_packet, migrated_applied)
	client_visuals = client_bomber.get_payload_presentation().get_active_snapshots()
	_check(bool(migrated_applied.get("accepted", false))
		and client_flow._bomber_payload_replica_migration_generation == 2
		and client_visuals.size() == 1
		and StringName((client_visuals[0] as Dictionary).get("phase", &"")) == &"flight",
		"new migration clears old terminal presentation before accepting its launch")
	client_flow._on_network_session_stopped(&"test_disconnect")
	_check(client_bomber.get_payload_presentation().get_active_snapshots().is_empty()
		and client_flow._bomber_payload_replica_generations.is_empty(),
		"session stop synchronously clears client projectile presentation state")

	server_flow._bomber_payload_projectiles.erase(projectile)
	projectile.detach(&"terminal_test_complete")
	var abort_projectile := Projectile.new(
		1, Vector3(0.0, -9.81, 0.0), 30.0, 500.0, 100_000.0,
	) as BomberPayloadProjectile
	var abort_record := (launch_projectile.get("release_record", {}) as Dictionary).duplicate(true)
	abort_record.record_id = &"bomber_payload_release_000002"
	abort_record.release_sequence = 2
	abort_record.request_sequence = 2
	_check(abort_projectile.begin_generation(server_flow._bomber_payload_generation).accepted
		and abort_projectile.consume_release_record(1, abort_record).accepted,
		"abort probe is a real admitted production projectile")
	server_flow._bomber_payload_projectiles.append(abort_projectile)
	server_flow._clear_bomber_payload_loop(&"network_abort_test")
	var abort_packet := server._last_result.get("packet", {}) as Dictionary
	_check(bool(abort_packet.get("terminal", false))
		and StringName((abort_packet.get("projectile", {}) as Dictionary).get("state", &"")) == &"terminal"
		and ((abort_packet.get("projectile", {}) as Dictionary).get("terminal_intent", {}) as Dictionary).is_empty()
		and int((abort_packet.get("projectile", {}) as Dictionary).get("last_update_tick", 0)) == 4,
		"authority detach publishes an ordered abort terminal before local cleanup")

	server.free()
	client.free()
	server_flow.free()
	client_flow.free()
	server_bomber.queue_free()
	client_bomber.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK: GameFlow bomber payload network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
