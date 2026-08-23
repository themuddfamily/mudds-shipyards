extends SceneTree

const GameFlow := preload("res://scripts/game/game_flow.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")
const ShotRequest := preload("res://scripts/combat/shot_request.gd")
const TorrentScene := preload("res://scenes/ships/torrent_interceptor.tscn")
const PulseScene := preload("res://scenes/effects/pulse_weapon_presentation.tscn")
const AudioScene := preload("res://scenes/audio/combat_audio_presentation.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	_check(server.publish_snapshot(0, [_movement_record()], [], []).accepted,
		"server seeds the canonical movement envelope")

	var server_flow := GameFlow.new()
	var server_ship := TorrentScene.instantiate() as HeroShip
	var server_pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var server_audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(server_ship)
	root.add_child(server_pulse)
	root.add_child(server_audio)
	await process_frame
	_configure_flow(server_flow, server, server_ship, server_pulse, server_audio, &"server")
	_connect_pulse_lifecycle(server_flow, server_pulse)

	var miss_request := ShotRequest.new(
		server_ship, 1101, &"shipyard_flight_test", &"torrent_compact_pulse_cannon",
		1, Vector3.ZERO, Vector3.FORWARD, 100.0, 18.0, 1
	)
	server_flow._on_authoritative_shot_submitted(miss_request, {
		"accepted": true,
		"resolved": true,
		"hit": false,
		"damaged": false,
	})
	var launch_result := server_flow._last_player_pulse_network_result
	var launch_packet := launch_result.get("packet", {}) as Dictionary
	var launch_projectile := launch_packet.get("projectile", {}) as Dictionary
	var projectile_id := StringName(launch_projectile.get("projectile_id", &""))
	var canonical_launch := server_flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(bool(launch_result.get("accepted", false))
		and projectile_id.begins_with("torrent_pulse_g000001_s")
		and int(launch_projectile.get("projectile_generation", 0)) == 1
		and int(launch_projectile.get("source_generation", 0)) == 1,
		"the real authoritative Torrent pulse caller publishes fenced projectile identity")
	_check(_canonical_projectile(canonical_launch, projectile_id).get("state") == &"spawned"
		and (canonical_launch.sections.movement as Array).size() == 1,
		"spawn enters the canonical late-join envelope without erasing movement")

	server._peer_generations[3] = 1
	var late_join := server_flow._republish_player_pulses_for_peer(3)
	var late_packet := server_flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	_check(late_join.get("status") == &"player_pulse_resync_published"
		and int(server_flow._last_player_pulse_network_result.get("recipients", 0)) == 1
		and StringName((late_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
			== projectile_id,
		"an admitted late joiner receives the still-live production pulse")
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(late_replica.apply_replica_snapshot(
		1, server_flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	).accepted,
		"the late-join canonical packet is accepted by the production lifecycle fence")

	var client := Adapter.new()
	var client_flow := GameFlow.new()
	var client_ship := TorrentScene.instantiate() as HeroShip
	var client_pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var client_audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(client_ship)
	root.add_child(client_pulse)
	root.add_child(client_audio)
	await process_frame
	_configure_flow(client_flow, client, client_ship, client_pulse, client_audio, &"client")
	var launch_applied := client._apply_projectile_replica_snapshot(launch_packet)
	var launch_presented := client_flow._on_projectile_replica_packet(launch_packet, launch_applied)
	_check(launch_presented.get("status") == &"player_pulse_presented"
		and client_pulse.get_active_effect_count() == 1
		and client_flow._player_pulse_network_active_shots.is_empty(),
		"client consumes the receipted packet into presentation without a local authority record")
	client_flow._on_projectile_fired(Vector3.ZERO, Vector3.FORWARD, client_ship)
	_check(client_flow._last_player_shot_result.get("reason")
			== &"client_projectile_authority_forbidden"
		and client_flow.combat_authority == null,
		"client fire input is fenced before CombatResolver or damage authority")
	var forged := launch_packet.duplicate(true)
	forged.revision = int(launch_packet.get("revision", 0)) + 1
	forged.server_tick = int(launch_packet.get("server_tick", 0)) + 1
	var forged_projectile := forged.get("projectile", {}) as Dictionary
	forged_projectile["last_update_tick"] = int(launch_projectile.get("last_update_tick", 0)) + 1
	var forged_pulse := forged_projectile.get("pulse_record", {}) as Dictionary
	forged_pulse["source_generation"] = 2
	forged_projectile["pulse_record"] = forged_pulse
	forged["projectile"] = forged_projectile
	var forged_client := Adapter.new()
	forged_client._apply_projectile_replica_snapshot(launch_packet)
	var forged_applied := forged_client._apply_projectile_replica_snapshot(forged)
	client_flow.network_session = forged_client
	var forged_result := client_flow._on_projectile_replica_packet(forged, forged_applied)
	client_flow.network_session = client
	_check(bool(forged_applied.get("accepted", false))
		and forged_result.get("status") == &"invalid_player_pulse_record"
		and client_pulse.get_active_effect_count() == 1,
		"nested future authority cannot replace an already-receipted client visual")

	server_pulse.advance_shot_simulation(1.0)
	var expiry_packet := server_flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var expiry_canonical := server_flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(bool(expiry_packet.get("terminal", false))
		and StringName((expiry_packet.get("projectile", {}) as Dictionary).get("state", &"")) == &"expired"
		and _canonical_projectile(expiry_canonical, projectile_id).get("state") == &"expired",
		"a resolved miss retires as an immutable expiry tombstone")
	var terminal_applied := client._apply_projectile_replica_snapshot(expiry_packet)
	var terminal_presented := client_flow._on_projectile_replica_packet(expiry_packet, terminal_applied)
	var reordered := client._apply_projectile_replica_snapshot(launch_packet)
	_check(terminal_presented.get("status") == &"player_pulse_terminal_presented"
		and not bool(reordered.get("accepted", false)),
		"client terminal admission prevents a reordered launch from resurrecting the pulse")

	var hit_request := ShotRequest.new(
		server_ship, 1101, &"shipyard_flight_test", &"torrent_compact_pulse_cannon",
		2, Vector3.ZERO, Vector3.FORWARD, 40.0, 18.0, 2
	)
	server_flow._on_authoritative_shot_submitted(hit_request, {
		"accepted": true,
		"resolved": true,
		"hit": true,
		"damaged": false,
		"position": Vector3(0.0, 0.0, -40.0),
	})
	var hit_packet := server_flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var hit_id := StringName((hit_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
	server_pulse.advance_shot_simulation(0.3)
	var impact_canonical := server_flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(_canonical_projectile(impact_canonical, hit_id).get("state") == &"impacted",
		"the existing visual arrival event publishes an impact tombstone after damage is already resolved")

	var abort_request := ShotRequest.new(
		server_ship, 1101, &"shipyard_flight_test", &"torrent_compact_pulse_cannon",
		3, Vector3.ZERO, Vector3.FORWARD, 60.0, 18.0, 3
	)
	server_flow._on_authoritative_shot_submitted(abort_request, {
		"accepted": true, "resolved": true, "hit": false, "damaged": false,
	})
	var abort_packet := server_flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var abort_id := StringName((abort_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
	server_pulse.clear_effects()
	var abort_canonical := server_flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(_canonical_projectile(abort_canonical, abort_id).get("state") == &"aborted"
		and server_flow._player_pulse_network_active_shots.is_empty(),
		"pool clear publishes an abort tombstone before dropping the active visual record")

	var retry_record := launch_projectile.duplicate(true)
	retry_record["projectile_id"] = &"torrent_pulse_retry_probe"
	var retry_pulse := retry_record.get("pulse_record", {}) as Dictionary
	retry_pulse["projectile_id"] = &"torrent_pulse_retry_probe"
	retry_record["pulse_record"] = retry_pulse
	retry_record["last_update_tick"] = server_flow._player_pulse_network_server_tick + 1
	server._is_server = false
	server_flow._queue_player_pulse_network_publication(retry_record, false)
	_check(server_flow._player_pulse_network_pending.size() == 1,
		"failed transport publication retains a retryable coherent record")
	server._is_server = true
	var retried := server_flow._retry_player_pulse_network_publications()
	_check(bool(retried.get("accepted", false))
		and server_flow._player_pulse_network_pending.is_empty()
		and not server_flow._player_pulse_canonical_publish_pending,
		"retry publishes the mutation once and then the canonical envelope")

	server._is_server = false
	for index in GameFlow.PLAYER_PULSE_NETWORK_MAX_PENDING + 8:
		var bounded := retry_record.duplicate(true)
		bounded["projectile_id"] = StringName("torrent_pulse_bounded_%03d" % index)
		var bounded_pulse := bounded.get("pulse_record", {}) as Dictionary
		bounded_pulse["projectile_id"] = bounded.get("projectile_id", &"")
		bounded["pulse_record"] = bounded_pulse
		bounded["last_update_tick"] = 100 + index
		server_flow._queue_player_pulse_network_publication(bounded, false)
	_check(server_flow._player_pulse_network_pending.size()
			== GameFlow.PLAYER_PULSE_NETWORK_MAX_PENDING,
		"retry backlog stays within the explicit production cache bound")
	server_flow._player_pulse_network_pending.clear()
	server._is_server = true
	_check(server._projectile_authoritative_records.size() <= Adapter.PROJECTILE_CANONICAL_MAX_RECORDS,
		"canonical projectile retirement remains bounded by the existing adapter policy")

	var solo_flow := GameFlow.new()
	var solo_pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var solo_audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(solo_pulse)
	root.add_child(solo_audio)
	await process_frame
	_configure_flow(solo_flow, null, server_ship, solo_pulse, solo_audio, &"")
	_connect_pulse_lifecycle(solo_flow, solo_pulse)
	solo_flow._on_authoritative_shot_submitted(miss_request, {
		"accepted": true, "resolved": true, "hit": false, "damaged": false,
	})
	_check(solo_pulse.get_active_effect_count() == 1
		and solo_flow._player_pulse_network_pending.is_empty()
		and solo_flow._last_player_pulse_network_result.is_empty(),
		"single-player keeps the existing local pulse without requiring networking")

	server.free()
	client.free()
	forged_client.free()
	server_flow.free()
	client_flow.free()
	solo_flow.free()
	server_ship.queue_free()
	client_ship.queue_free()
	server_pulse.queue_free()
	client_pulse.queue_free()
	solo_pulse.queue_free()
	server_audio.queue_free()
	client_audio.queue_free()
	solo_audio.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK: GameFlow player pulse network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _configure_flow(
	flow: GameFlow,
	adapter: Adapter,
	ship: HeroShip,
	pulse: PulseWeaponPresentation,
	audio: CombatAudioPresentation,
	mode: StringName,
) -> void:
	flow.network_session = adapter
	flow._network_session_mode = mode
	flow._network_ship_generation = 1
	ship.ship_id = &"torrent_provisional"
	flow.active_ship = ship
	flow.ship = ship
	flow._piloting = true
	flow.pulse_presentation = pulse
	pulse.set_auto_advance_enabled(false)
	flow.combat_audio = audio


func _connect_pulse_lifecycle(flow: GameFlow, pulse: PulseWeaponPresentation) -> void:
	pulse.shot_presented.connect(flow._on_pulse_shot_presented)
	pulse.impact_started.connect(flow._on_pulse_impact_started)
	pulse.shot_finished.connect(flow._on_pulse_shot_finished)
	pulse.shot_recycled.connect(flow._on_pulse_shot_recycled)
	pulse.effects_cleared.connect(flow._on_pulse_effects_cleared)


func _movement_record() -> Dictionary:
	return {
		"entity_id": &"torrent_provisional",
		"entity_generation": 1,
		"owner_peer_id": 1,
		"mode": &"ship",
		"position": Vector3.ZERO,
		"velocity_world": Vector3.ZERO,
	}


func _canonical_projectile(packet: Dictionary, projectile_id: StringName) -> Dictionary:
	var sections := packet.get("sections", {}) as Dictionary
	for record_variant: Variant in sections.get(&"projectiles", []) as Array:
		var record := record_variant as Dictionary
		if StringName(record.get("projectile_id", &"")) == projectile_id:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
