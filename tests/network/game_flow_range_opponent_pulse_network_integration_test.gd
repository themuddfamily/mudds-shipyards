extends SceneTree

const GameFlow := preload("res://scripts/game/game_flow.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")
const Authority := preload("res://scripts/combat/live_combat_authority.gd")
const Resolver := preload("res://scripts/combat/combat_resolver.gd")
const ShotRequest := preload("res://scripts/combat/shot_request.gd")
const OpponentScene := preload("res://scenes/ships/range_opponent.tscn")
const PulseScene := preload("res://scenes/effects/pulse_weapon_presentation.tscn")
const AudioScene := preload("res://scenes/audio/combat_audio_presentation.tscn")

class StationContentStub extends StationDefenseEncounterContent:
	func get_generation() -> int:
		return 4


class StationWorldStub extends Node3D:
	var content: StationDefenseEncounterContent

	func get_station_defense_content() -> StationDefenseEncounterContent:
		return content


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

	var opponent := OpponentScene.instantiate() as RangeOpponent
	var pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var audio := AudioScene.instantiate() as CombatAudioPresentation
	var authority := Authority.new()
	var resolver := Resolver.new()
	resolver.name = &"Resolver"
	authority.add_child(resolver)
	root.add_child(opponent)
	root.add_child(pulse)
	root.add_child(audio)
	root.add_child(authority)
	await process_frame
	pulse.set_auto_advance_enabled(false)
	var flow := GameFlow.new()
	_configure_flow(flow, server, opponent, pulse, audio, &"server")
	flow.combat_authority = authority
	_connect_pulse_lifecycle(flow, pulse)
	authority.authoritative_shot_submitted.connect(flow._on_authoritative_shot_submitted)
	_check(authority.register_source(opponent, 2101, &"range_defence", {
		&"defence_pulse_cannon": {
			"range": 420.0,
			"damage": 11.0,
			"origin_tolerance": 18.0,
		},
	}), "production opponent source registers with the existing CombatResolver")

	flow._on_opponent_projectile_fired(Vector3.ZERO, Vector3.FORWARD)
	var launch_result := flow._last_player_pulse_network_result
	var launch_packet := launch_result.get("packet", {}) as Dictionary
	var launch_projectile := launch_packet.get("projectile", {}) as Dictionary
	var first_id := StringName(launch_projectile.get("projectile_id", &""))
	var canonical_launch := flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(bool(flow._last_opponent_shot_result.get("accepted", false))
		and bool(flow._last_opponent_shot_result.get("resolved", false))
		and first_id.begins_with("range_defence_interceptor_pulse_g000001_s")
		and int(launch_projectile.get("source_generation", 0)) == 1,
		"the real opponent fire caller resolves once and publishes its fenced pulse")
	_check(_canonical_projectile(canonical_launch, first_id).get("state") == &"spawned"
		and (canonical_launch.sections.movement as Array).size() == 1,
		"enemy spawn enters the canonical envelope without erasing movement")

	flow._on_opponent_projectile_fired(Vector3(0.5, 0.0, 0.0), Vector3.FORWARD)
	var burst_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var burst_projectile := burst_packet.get("projectile", {}) as Dictionary
	var second_id := StringName(burst_projectile.get("projectile_id", &""))
	_check(second_id != first_id
		and int(burst_projectile.get("projectile_generation", 0)) == 1
		and flow._player_pulse_network_active_shots.size() == 2,
		"successive authored pattern emissions retain one generation and distinct pulse identities")

	server._peer_generations[3] = 1
	var late_join := flow._republish_player_pulses_for_peer(3)
	var late_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	_check(late_join.get("status") == &"player_pulse_resync_published"
		and int(late_join.get("projectile_count", 0)) == 2
		and int(flow._last_player_pulse_network_result.get("recipients", 0)) == 1
		and not (late_packet.get("projectile", {}) as Dictionary).is_empty(),
		"late join republishes every live enemy pulse through the existing ENet seam")
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(late_replica.apply_replica_snapshot(
		1, flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	).accepted,
		"late-join canonical enemy records pass the production lifecycle fence")

	var client := Adapter.new()
	var client_flow := GameFlow.new()
	var client_opponent := OpponentScene.instantiate() as RangeOpponent
	var client_pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var client_audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(client_opponent)
	root.add_child(client_pulse)
	root.add_child(client_audio)
	await process_frame
	client_pulse.set_auto_advance_enabled(false)
	_configure_flow(client_flow, client, client_opponent, client_pulse, client_audio, &"client")
	var launch_applied := client._apply_projectile_replica_snapshot(launch_packet)
	var presented := client_flow._on_projectile_replica_packet(launch_packet, launch_applied)
	_check(presented.get("status") == &"opponent_pulse_presented"
		and client_pulse.get_active_effect_count() == 1
		and client_flow._player_pulse_network_active_shots.is_empty(),
		"client consumes a receipted enemy launch into amber presentation only")
	var burst_applied := client._apply_projectile_replica_snapshot(burst_packet)
	var burst_presented := client_flow._on_projectile_replica_packet(burst_packet, burst_applied)
	_check(burst_presented.get("status") == &"opponent_pulse_presented"
		and client_pulse.get_active_effect_count() == 2,
		"client presents successive server burst members without simulating their cadence")
	client_flow._on_opponent_projectile_fired(Vector3.ZERO, Vector3.FORWARD)
	_check(client_flow._last_opponent_shot_result.get("reason")
			== &"client_projectile_authority_forbidden"
		and client_flow.combat_authority == null,
		"client opponent cadence is fenced before CombatResolver and damage authority")
	var presentation_only_content := StationContentStub.new()
	var presentation_world := StationWorldStub.new()
	presentation_world.content = presentation_only_content
	client_flow.world = presentation_world
	var presentation_mode := client_flow._set_station_defense_network_presentation_only(true)
	presentation_only_content._on_hostile_projectile_fired(
		Vector3.ZERO, Vector3.FORWARD, client_opponent
	)
	_check(bool(presentation_mode.get("accepted", false))
		and (presentation_only_content.get_snapshot().get("last_hostile_shot", {}) as Dictionary).get(
		"status", &""
	) == &"client_projectile_authority_forbidden",
		"GameFlow client mode fences station-defense patterns before combat mutation")

	var forged_client := Adapter.new()
	forged_client._apply_projectile_replica_snapshot(launch_packet)
	var forged := launch_packet.duplicate(true)
	forged["revision"] = int(launch_packet.get("revision", 0)) + 1
	forged["server_tick"] = int(launch_packet.get("server_tick", 0)) + 1
	var forged_projectile := forged.get("projectile", {}) as Dictionary
	forged_projectile["last_update_tick"] = int(launch_projectile.get("last_update_tick", 0)) + 1
	var forged_record := forged_projectile.get("opponent_pulse_record", {}) as Dictionary
	forged_record["source_generation"] = 2
	forged_projectile["opponent_pulse_record"] = forged_record
	forged["projectile"] = forged_projectile
	var forged_applied := forged_client._apply_projectile_replica_snapshot(forged)
	client_flow.network_session = forged_client
	var forged_result := client_flow._on_projectile_replica_packet(forged, forged_applied)
	client_flow.network_session = client
	_check(bool(forged_applied.get("accepted", false))
		and forged_result.get("status") == &"invalid_opponent_pulse_record"
		and client_pulse.get_active_effect_count() == 2,
		"nested source-generation forgery cannot replace accepted enemy presentation")

	pulse.advance_shot_simulation(1.0)
	var expiry_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var expiry_canonical := flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary
	_check(bool(expiry_packet.get("terminal", false))
		and _canonical_projectile(expiry_canonical, first_id).get("state") == &"expired"
		and _canonical_projectile(expiry_canonical, second_id).get("state") == &"expired",
		"every completed burst member retires as its own expiry tombstone")
	var terminal_applied := client._apply_projectile_replica_snapshot(expiry_packet)
	var terminal_presented := client_flow._on_projectile_replica_packet(expiry_packet, terminal_applied)
	var reordered := client._apply_projectile_replica_snapshot(burst_packet)
	_check(terminal_presented.get("status") == &"opponent_pulse_terminal_presented"
		and not bool(reordered.get("accepted", false)),
		"terminal receipt prevents reordered enemy launch resurrection")

	var impact_request := ShotRequest.new(
		opponent, 2101, &"range_defence", &"defence_pulse_cannon", 3,
		Vector3.ZERO, Vector3.FORWARD, 40.0, 11.0, 3
	)
	flow._on_authoritative_shot_submitted(impact_request, {
		"accepted": true, "resolved": true, "hit": true, "damaged": false,
		"position": Vector3(0.0, 0.0, -40.0),
	})
	var impact_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var impact_id := StringName((impact_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
	pulse.advance_shot_simulation(0.3)
	_check(_canonical_projectile(
		flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary,
		impact_id
	).get("state") == &"impacted",
		"server visual arrival publishes impact after CombatResolver result is already final")

	flow._on_authoritative_shot_submitted(impact_request, {
		"accepted": true, "resolved": true, "hit": false, "damaged": false,
	})
	var abort_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var abort_id := StringName((abort_packet.get("projectile", {}) as Dictionary).get("projectile_id", &""))
	pulse.clear_effects()
	_check(_canonical_projectile(
		flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary,
		abort_id
	).get("state") == &"aborted",
		"pool retirement publishes an enemy abort tombstone")

	var station_content := StationContentStub.new()
	var station_source := OpponentScene.instantiate() as RangeOpponent
	station_source.set_meta(&"hostile_id", &"perimeter_raider_alpha")
	station_source.set_meta(&"handle_generation", 1)
	station_content.add_child(station_source)
	var station_world := StationWorldStub.new()
	station_world.content = station_content
	flow.world = station_world
	var station_request := ShotRequest.new(
		station_source, 2121, &"station_defense_hostile", &"perimeter_defense_pulse", 1,
		Vector3(1.0, 0.0, 0.0), Vector3.FORWARD, 170.0, 11.0, -1
	)
	flow._on_authoritative_shot_submitted(station_request, {
		"accepted": true, "resolved": true, "hit": false, "damaged": false,
	})
	var station_packet := flow._last_player_pulse_network_result.get("packet", {}) as Dictionary
	var station_projectile := station_packet.get("projectile", {}) as Dictionary
	var station_id := StringName(station_projectile.get("projectile_id", &""))
	var station_nested := station_projectile.get("opponent_pulse_record", {}) as Dictionary
	_check(station_id.begins_with("station_defense_perimeter_raider_alpha_pulse_g000004_s")
		and int(station_projectile.get("source_generation", 0)) == 4
		and int(station_nested.get("handle_generation", 0)) == 1
		and int(station_nested.get("source_id", 0)) == 2121,
		"station-defense pulse derives strict source fences from existing activity and hostile handles")
	var station_applied := client._apply_projectile_replica_snapshot(station_packet)
	client_flow.network_session = client
	var station_presented := client_flow._on_projectile_replica_packet(
		station_packet, station_applied
	)
	_check(station_presented.get("status") == &"opponent_pulse_presented",
		"client presents a receipted station-defense hostile without owning its pattern")
	flow._on_station_defense_network_snapshot_changed({
		"host": {"activity": {"state_id": &"aborted", "generation": 4}},
	})
	_check(_canonical_projectile(
		flow._last_player_pulse_canonical_result.get("packet", {}) as Dictionary,
		station_id
	).get("state") == &"aborted",
		"station-defense authority withdrawal aborts every in-flight hostile pulse")
	pulse.clear_effects()

	var retry_record := launch_projectile.duplicate(true)
	retry_record["projectile_id"] = &"range_opponent_retry_probe"
	var retry_nested := retry_record.get("opponent_pulse_record", {}) as Dictionary
	retry_nested["projectile_id"] = &"range_opponent_retry_probe"
	retry_record["opponent_pulse_record"] = retry_nested
	retry_record["last_update_tick"] = flow._player_pulse_network_server_tick + 1
	server._is_server = false
	flow._queue_player_pulse_network_publication(retry_record, false)
	_check(flow._player_pulse_network_pending.size() == 1,
		"failed enemy publication remains retryable without repeating damage")
	server._is_server = true
	var retried := flow._retry_player_pulse_network_publications()
	_check(bool(retried.get("accepted", false))
		and flow._player_pulse_network_pending.is_empty()
		and server._projectile_authoritative_records.size()
			<= Adapter.PROJECTILE_CANONICAL_MAX_RECORDS,
		"retry reaches the existing bounded canonical cache")

	var solo_flow := GameFlow.new()
	var solo_pulse := PulseScene.instantiate() as PulseWeaponPresentation
	var solo_audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(solo_pulse)
	root.add_child(solo_audio)
	await process_frame
	solo_pulse.set_auto_advance_enabled(false)
	_configure_flow(solo_flow, null, opponent, solo_pulse, solo_audio, &"")
	_connect_pulse_lifecycle(solo_flow, solo_pulse)
	solo_flow._on_authoritative_shot_submitted(impact_request, {
		"accepted": true, "resolved": true, "hit": false, "damaged": false,
	})
	_check(solo_pulse.get_active_effect_count() == 1
		and solo_flow._last_player_pulse_network_result.is_empty(),
		"solo enemy fire keeps its existing local pulse without networking")

	server.free()
	client.free()
	forged_client.free()
	presentation_world.free()
	presentation_only_content.free()
	station_world.free()
	station_content.free()
	flow.free()
	client_flow.free()
	solo_flow.free()
	opponent.queue_free()
	client_opponent.queue_free()
	pulse.queue_free()
	client_pulse.queue_free()
	solo_pulse.queue_free()
	audio.queue_free()
	client_audio.queue_free()
	solo_audio.queue_free()
	authority.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK: GameFlow range-opponent pulse network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _configure_flow(
	flow: GameFlow,
	adapter: Adapter,
	opponent: RangeOpponent,
	pulse: PulseWeaponPresentation,
	audio: CombatAudioPresentation,
	mode: StringName,
) -> void:
	flow.network_session = adapter
	flow._network_session_mode = mode
	flow.opponent = opponent
	flow.pulse_presentation = pulse
	flow.combat_audio = audio
	flow._opponent_pulse_network_generation = 1


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
