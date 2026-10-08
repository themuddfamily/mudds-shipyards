extends SceneTree

## Mass-driver slugs and seeker torpedoes, replicated host -> client over a real
## loopback ENet session as presentation only.
##
## The host side is a `NetworkRemoteProjectileReplicator` observing two pools
## that emit exactly the signals `MassDriverBoltPool` (a
## `TravellingBoltProjectile`) and `SeekerTorpedoProjectile` emit, publishing
## through GameFlow's production publisher and the existing projectile snapshot
## path on its shared monotonic tick. The client side uses production GameFlow
## dispatch with real CombatAudioPresentation nodes. All three peers have
## different station origins, as after independent planetary world rebases.
## Dummy audio verifies cue admission and dispatch; it does not prove audibility.
##
## What is asserted:
##   A. only a pool with the right signals is observed, and only once;
##   B. a slug launch is drawn on the client at the launch point and flies
##      forward at the published speed;
##   C. a resolved slug bursts and stops being drawn;
##   D. a torpedo's steering is restated on its cadence and the client's copy
##      follows the new heading and position;
##   E. an intercepted torpedo stops being drawn; an abandoned slug is removed
##      without a burst;
##   F. a peer that joins mid-flight is sent every live flight;
##   G. a flight whose terminal never arrives is retired on the client after its
##      published lifetime, and the client never holds combat authority;
##   H. launch audio plays once for current clients, without local echo, late
##      join replay, or replay after a visual expires; retirement stays bounded.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Replicator := preload("res://scripts/network/network_remote_projectile_replicator.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const AudioScene := preload("res://scenes/audio/combat_audio_presentation.tscn")
const HOST_STATION_ORIGIN := Vector3(-31.0, -4.0, -48.0)
const CLIENT_STATION_ORIGIN := Vector3(22.0, 3.0, 17.0)
const LATE_STATION_ORIGIN := Vector3(-5.0, 2.0, 91.0)
const STORM_SLUGS := 200
## Live flights plus the retired-id tombstones the fencing needs.
const STORM_BOUND := 160


class FakeBoltPool extends Node:
	signal bolt_launched(record: Dictionary)
	signal bolt_resolved(record: Dictionary, result: Dictionary)
	signal bolt_abandoned(record: Dictionary, reason: StringName)


class FakeTorpedoPool extends Node:
	signal torpedo_launched(record: Dictionary)
	signal torpedo_resolved(record: Dictionary, result: Dictionary)
	signal torpedo_abandoned(record: Dictionary, reason: StringName)
	signal torpedo_intercepted(record: Dictionary)
	var records: Array[Dictionary] = []

	func get_active_torpedo_records() -> Array[Dictionary]:
		return records


var _failures: Array[String] = []
var _assertions := 0
var _server: Adapter
var _client: Adapter
var _late: Adapter
var _host_replicator: Replicator
var _client_replicator: Replicator
var _late_replicator: Replicator
var _host_flow: GameFlow
var _client_flow: GameFlow
var _late_flow: GameFlow
var _client_audio: CombatAudioPresentation
var _late_audio: CombatAudioPresentation
var _last_launch_packet := {}


func _initialize() -> void:
	await process_frame
	var branches: Array[SubViewport] = []
	for branch_name in ["Server", "Client", "LateClient"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		branches.append(branch)
	_server = Adapter.new()
	_client = Adapter.new()
	_late = Adapter.new()
	for index in 3:
		var adapter: Adapter = [_server, _client, _late][index]
		adapter.name = "Session"
		branches[index].add_child(adapter)
	_host_replicator = Replicator.new()
	_client_replicator = Replicator.new()
	_late_replicator = Replicator.new()
	root.add_child(_host_replicator)
	root.add_child(_client_replicator)
	root.add_child(_late_replicator)
	_host_flow = GameFlow.new()
	_host_flow.network_session = _server
	_host_flow._network_session_mode = &"server"
	_host_flow.world = _make_station_origin(HOST_STATION_ORIGIN)
	_host_replicator.set_publisher(_host_flow._publish_network_remote_projectile)
	_client_audio = AudioScene.instantiate() as CombatAudioPresentation
	_late_audio = AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(_client_audio)
	root.add_child(_late_audio)
	_client_flow = _configure_client_flow(_client, _client_replicator, _client_audio, CLIENT_STATION_ORIGIN)
	_late_flow = _configure_client_flow(_late, _late_replicator, _late_audio, LATE_STATION_ORIGIN)
	_client.projectile_replica_packet.connect(func(packet: Dictionary, result: Dictionary) -> void:
		if not bool(packet.get("terminal", false)):
			_last_launch_packet = packet.duplicate(true)
		_client_flow._on_projectile_replica_packet(packet, result))
	_late.projectile_replica_packet.connect(_late_flow._on_projectile_replica_packet)
	var probe := UDPServer.new()
	_check(probe.listen(0, "127.0.0.1") == OK, "reserve ENet port")
	var port := probe.get_local_port()
	probe.stop()
	_check(_server.host(port, 3).accepted, "host real ENet session")
	_check(_client.join("127.0.0.1", port).accepted, "connect real ENet client")
	await _pump(func() -> bool: return not _client.get_server_offer().is_empty())
	_check(not _client.get_server_offer().is_empty(), "client admitted")

	var bolts := FakeBoltPool.new()
	var torpedoes := FakeTorpedoPool.new()
	root.add_child(bolts)
	root.add_child(torpedoes)

	# A
	_check(_host_replicator.observe_pool(bolts, Replicator.KIND_SLUG, &"player-mass-driver").accepted,
		"a travelling-bolt pool is observed")
	_check(_host_replicator.observe_pool(bolts, Replicator.KIND_SLUG, &"player-mass-driver").status
		== &"already_observed", "observing the same pool twice is a no-op")
	_check(_host_replicator.observe_pool(torpedoes, Replicator.KIND_TORPEDO, &"torpedo-boat").accepted,
		"a seeker-torpedo pool is observed")
	var plain := Node.new()
	root.add_child(plain)
	_check(_host_replicator.observe_pool(plain, Replicator.KIND_SLUG, &"nothing").status
		== &"pool_signals_missing", "a node without the pool's signals is refused")

	# Local client fire must wait for the host's accepted projectile: no echo.
	var cargo := Cargo.new() as HeroShip
	root.add_child(cargo)
	_client_flow.active_ship = cargo
	_client_flow._on_projectile_fired(Vector3.ZERO, Vector3.FORWARD, cargo)
	_check(int(_client_audio.get_state_snapshot().cue_count) == 0
		and _client_flow.get_last_player_shot_result().get("reason") == &"client_projectile_authority_forbidden",
		"local client fire is fenced without a speculative audio echo")

	# B
	var origin := HOST_STATION_ORIGIN + Vector3(10.0, 20.0, -30.0)
	var client_origin := origin - HOST_STATION_ORIGIN + CLIENT_STATION_ORIGIN
	var slug := _record(7, origin, Vector3.FORWARD, 180.0, 2.0)
	bolts.bolt_launched.emit(slug)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var drawn := _client_replicator.get_drawn_projectile_ids()
	_check(drawn.size() == 1, "the client draws the host's slug")
	_check(int(_client_audio.get_state_snapshot().cue_count) == 1
		and (_client_audio.get_state_snapshot().last_world_position as Vector3).is_equal_approx(client_origin),
		"the accepted host slug dispatches one spatial fire cue through GameFlow")
	_check((_last_launch_packet.projectile.position as Vector3).is_equal_approx(origin - HOST_STATION_ORIGIN)
		and (_last_launch_packet.projectile.direction as Vector3).is_equal_approx(Vector3.FORWARD)
		and is_equal_approx(float((_last_launch_packet.projectile as Dictionary)[Replicator.RECORD_KEY].speed), 180.0),
		"launch wire uses station position while preserving direction and speed")
	var duplicate_result := _client._apply_projectile_replica_snapshot(_last_launch_packet)
	_client_flow._on_projectile_replica_packet(_last_launch_packet, duplicate_result)
	_check(not bool(duplicate_result.get("accepted", true))
		and int(_client_audio.get_state_snapshot().cue_count) == 1,
		"a duplicate launch is rejected without repeating fire audio")
	var slug_id := StringName(drawn[0]) if not drawn.is_empty() else &""
	var first := _client_replicator.get_visual_position(slug_id)
	_check(first.distance_to(client_origin) < 20.0, "the slug appears at the launch point (%.2f m)" % first.distance_to(client_origin))
	await _wait_seconds(0.1)
	var later := _client_replicator.get_visual_position(slug_id)
	_check((later - first).dot(Vector3.FORWARD) > 1.0, "the slug flies forward between records")

	# A newer copy of the launch marker is an update, even after the visual
	# expires locally; audio follows first authority admission, not visual life.
	_client_replicator._process(4.0)
	var repeated_launch := _last_launch_packet.duplicate(true)
	repeated_launch.revision = int(repeated_launch.revision) + 1
	repeated_launch.server_tick = int(repeated_launch.server_tick) + 1
	(repeated_launch.projectile as Dictionary)["last_update_tick"] = int(repeated_launch.server_tick)
	var repeated_result := _client._apply_projectile_replica_snapshot(repeated_launch)
	_client_flow._on_projectile_replica_packet(repeated_launch, repeated_result)
	_check(bool(repeated_result.get("accepted", false))
		and int(_client_audio.get_state_snapshot().cue_count) == 1,
		"a newer launch restatement after visual retirement cannot replay fire audio")
	# Avoid overtaking the next host packet with this deliberate restatement.
	_host_flow._player_pulse_network_server_tick = int(repeated_launch.server_tick)
	_server._projectile_snapshot_revision = int(repeated_launch.revision)

	# C
	var terminal := slug.duplicate(true)
	terminal["terminal_position"] = origin + Vector3.FORWARD * 50.0
	bolts.bolt_resolved.emit(terminal, {"hit": true, "damaged": true})
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().is_empty())
	_check(_client_replicator.get_drawn_projectile_ids().is_empty()
		and int(_client_replicator.get_audit().get("terminals", 0)) == 1,
		"a resolved slug bursts and stops being drawn")
	_check(int(_client_replicator.get_audit().get("bursts", 0)) == 1, "a slug that hit something bursts")
	_check(_client_replicator.get_visual_position(slug_id).is_equal_approx(client_origin + Vector3.FORWARD * 50.0),
		"a terminal burst uses the client's world frame")
	var canonical_terminal := _server._projectile_authoritative_records.get(slug_id, {}) as Dictionary
	_check((canonical_terminal.get("position", Vector3.INF) as Vector3).is_equal_approx(origin - HOST_STATION_ORIGIN + Vector3.FORWARD * 50.0),
		"canonical terminal retains station-frame position")
	# A slug that runs out of range without touching anything ends quietly on the
	# host (no impact cue, no burst); the client must not detonate it in empty sky.
	var missed := _record(8, origin, Vector3.FORWARD, 180.0, 2.0)
	bolts.bolt_launched.emit(missed)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var missed_terminal := missed.duplicate(true)
	missed_terminal["terminal_position"] = origin + Vector3.FORWARD * 360.0
	missed_terminal["terminal_reason"] = &"range"
	var bursts_before_miss := int(_client_replicator.get_audit().get("bursts", 0))
	var terminals_before_miss := int(_client_replicator.get_audit().get("terminals", 0))
	bolts.bolt_resolved.emit(missed_terminal, {"hit": false, "damaged": false})
	await _pump(func() -> bool:
		return int(_client_replicator.get_audit().get("terminals", 0)) == terminals_before_miss + 1)
	_check(_client_replicator.get_drawn_projectile_ids().is_empty()
		and int(_client_replicator.get_audit().get("bursts", 0)) == bursts_before_miss,
		"a slug that missed is retired without a burst (bursts %d -> %d)"
		% [bursts_before_miss, int(_client_replicator.get_audit().get("bursts", 0))])

	# D
	var torpedo_origin := HOST_STATION_ORIGIN + Vector3(0.0, 5.0, 0.0)
	var torpedo := _record(9, torpedo_origin, Vector3.FORWARD, 40.0, 8.0)
	torpedoes.records = [torpedo]
	torpedoes.torpedo_launched.emit(torpedo)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var torpedo_id := StringName(_client_replicator.get_drawn_projectile_ids()[0]) \
		if not _client_replicator.get_drawn_projectile_ids().is_empty() else &""
	var steered := torpedo.duplicate(true)
	steered["position"] = HOST_STATION_ORIGIN + Vector3(30.0, 5.0, -5.0)
	steered["direction"] = Vector3.RIGHT
	torpedoes.records = [steered]
	for _frame in Replicator.TORPEDO_UPDATE_INTERVAL_TICKS * 2:
		_host_replicator.advance_host()
		await process_frame
	await _pump(func() -> bool:
		return _client_replicator.get_visual_position(torpedo_id).distance_to(CLIENT_STATION_ORIGIN + Vector3(30.0, 5.0, -5.0)) < 12.0)
	var tracked := _client_replicator.get_visual_position(torpedo_id)
	_check(tracked.distance_to(CLIENT_STATION_ORIGIN + Vector3(30.0, 5.0, -5.0)) < 12.0,
		"the client's torpedo follows the host's steering (%.2f m off)" % tracked.distance_to(CLIENT_STATION_ORIGIN + Vector3(30.0, 5.0, -5.0)))

	# A proximity fuse whose arrival sweep damaged nothing is a near miss: the
	# host shows no detonation burst, so neither does the client.
	var fused := _record(10, torpedo_origin, Vector3.FORWARD, 40.0, 8.0)
	torpedoes.records = [steered, fused]
	torpedoes.torpedo_launched.emit(fused)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 2)
	var fused_terminal := fused.duplicate(true)
	fused_terminal["terminal_reason"] = &"proximity_fuse"
	fused_terminal["terminal_position"] = torpedo_origin + Vector3.FORWARD * 12.0
	var bursts_before_fuse := int(_client_replicator.get_audit().get("bursts", 0))
	var terminals_before_fuse := int(_client_replicator.get_audit().get("terminals", 0))
	torpedoes.records = [steered]
	torpedoes.torpedo_resolved.emit(fused_terminal, {"hit": true, "damaged": false})
	await _pump(func() -> bool:
		return int(_client_replicator.get_audit().get("terminals", 0)) == terminals_before_fuse + 1)
	_check(_client_replicator.get_drawn_projectile_ids().size() == 1
		and int(_client_replicator.get_audit().get("bursts", 0)) == bursts_before_fuse,
		"a torpedo fuse that damaged nothing is retired without a burst (bursts %d -> %d)"
		% [bursts_before_fuse, int(_client_replicator.get_audit().get("bursts", 0))])

	# E
	torpedoes.records = []
	torpedoes.torpedo_intercepted.emit(steered)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().is_empty())
	_check(_client_replicator.get_drawn_projectile_ids().is_empty(), "an intercepted torpedo stops being drawn")
	var abandoned := _record(11, origin, Vector3.BACK, 120.0, 2.0)
	bolts.bolt_launched.emit(abandoned)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var terminals_before := int(_client_replicator.get_audit().get("terminals", 0))
	bolts.bolt_abandoned.emit(abandoned, &"source_retired")
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().is_empty())
	_check(_client_replicator.get_drawn_projectile_ids().is_empty()
		and int(_client_replicator.get_audit().get("terminals", 0)) == terminals_before + 1,
		"an abandoned slug is removed")

	# F
	var live := _record(13, origin, Vector3.LEFT, 10.0, 20.0)
	bolts.bolt_launched.emit(live)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	# A torpedo that has already steered far from its launch point.
	var live_torpedo := _record(17, torpedo_origin, Vector3.FORWARD, 40.0, 20.0)
	torpedoes.records = [live_torpedo]
	torpedoes.torpedo_launched.emit(live_torpedo)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 2)
	var flown := live_torpedo.duplicate(true)
	flown["position"] = HOST_STATION_ORIGIN + Vector3(-60.0, 5.0, -80.0)
	flown["direction"] = Vector3.RIGHT
	flown["elapsed"] = 2.0
	torpedoes.records = [flown]
	for _frame in Replicator.TORPEDO_UPDATE_INTERVAL_TICKS:
		_host_replicator.advance_host()
	_check(_late.join("127.0.0.1", port).accepted, "a late peer connects mid-flight")
	await _pump(func() -> bool: return not _late.get_server_offer().is_empty())
	_host_replicator.republish_for_peer(_late.multiplayer.get_unique_id())
	await _pump(func() -> bool: return _late_replicator.get_drawn_projectile_ids().size() == 2)
	_check(_late_replicator.get_drawn_projectile_ids().size() == 2, "the late peer is sent the live slug and torpedo")
	var late_slug_id := &""
	for drawn_id in _late_replicator.get_drawn_projectile_ids():
		if String(drawn_id).begins_with("slug"):
			late_slug_id = StringName(drawn_id)
	_check(_late_replicator.get_visual_position(late_slug_id).distance_to(origin - HOST_STATION_ORIGIN + LATE_STATION_ORIGIN) < 20.0,
		"late-join slug resync uses the late peer's station frame")
	_check(int(_late_audio.get_state_snapshot().cue_count) == 0,
		"late-join mid-flight presentation never replays old launch audio")
	var late_torpedo_id := &""
	for drawn_id in _late_replicator.get_drawn_projectile_ids():
		if String(drawn_id).begins_with("torpedo"):
			late_torpedo_id = StringName(drawn_id)
	var late_torpedo_error := _late_replicator.get_visual_position(late_torpedo_id).distance_to(
		(flown.position as Vector3) - HOST_STATION_ORIGIN + LATE_STATION_ORIGIN)
	_check(late_torpedo_error < 12.0,
		"the late peer sees the torpedo where it has steered to, not at its launch (%.2f m off)"
		% late_torpedo_error)
	torpedoes.records = []
	torpedoes.torpedo_intercepted.emit(flown)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)

	# H. A long fight: every retired flight's per-id bookkeeping is pruned to a
	# bounded tombstone ring on the client, and forgotten per peer on the host,
	# so the lifecycle receipt does not grow with session length.
	var storm_terminals_before := int(_client_replicator.get_audit().get("terminals", 0))
	var captured := {}
	var capture := func(packet: Dictionary, _result: Dictionary) -> void:
		captured["packet"] = packet.duplicate(true)
	for batch in STORM_SLUGS / 10:
		var fired: Array = []
		for index in 10:
			var storm_slug := _record(1000 + batch * 10 + index, origin, Vector3.DOWN, 50.0, 2.0)
			bolts.bolt_launched.emit(storm_slug)
			fired.append(storm_slug)
		if batch == STORM_SLUGS / 10 - 1:
			_client.projectile_replica_packet.connect(capture)
		for storm_slug: Dictionary in fired:
			bolts.bolt_resolved.emit(storm_slug, {"hit": false, "damaged": false})
		var expected := storm_terminals_before + (batch + 1) * 10
		await _pump(func() -> bool: return int(_client_replicator.get_audit().get("terminals", 0)) >= expected)
	_client.projectile_replica_packet.disconnect(capture)
	_check(int(_client_replicator.get_audit().get("terminals", 0)) == storm_terminals_before + STORM_SLUGS,
		"every one of %d slugs reaches the client's terminal" % STORM_SLUGS)
	var lifecycle := _client.get_projectile_replica_lifecycle_snapshot()
	var client_sizes := [
		(lifecycle.generations as Dictionary).size(),
		(lifecycle.terminal_generations as Dictionary).size(),
		(_client.get("_projectile_replica_ticks") as Dictionary).size(),
		(_client.get("_projectile_replica_packet_revisions") as Dictionary).size(),
		(_client.get("_projectile_replica_samples") as Dictionary).size(),
	]
	_check(client_sizes.all(func(size: int) -> bool: return size <= STORM_BOUND),
		"the client's per-projectile state stays bounded after %d slugs (%s)" % [STORM_SLUGS, str(client_sizes)])
	var host_published := _server.get("_projectile_published_generations") as Dictionary
	var host_sizes: Array = host_published.values().map(func(ids: Variant) -> int: return (ids as Dictionary).size())
	_check(host_sizes.all(func(size: int) -> bool: return size <= STORM_BOUND),
		"the host forgets retired projectiles per peer (%s)" % str(host_sizes))
	# The newest terminal is still fenced: a late copy of a flying packet for it
	# is refused and cannot resurrect the replica.
	var resurrect := (captured.get("packet", {}) as Dictionary).duplicate(true)
	var resurrect_projectile := resurrect.get("projectile", {}) as Dictionary
	resurrect_projectile["state"] = &"flying"
	resurrect_projectile.erase("terminal_intent")
	resurrect["terminal"] = false
	var cues_before_reorder := int(_client_audio.get_state_snapshot().cue_count)
	var resurrect_result: Dictionary = _client.call("_apply_projectile_replica_snapshot", resurrect)
	_client_flow._on_projectile_replica_packet(resurrect, resurrect_result)
	_check(not resurrect_projectile.is_empty()
		and not bool(resurrect_result.get("accepted", true))
		and int(_client_audio.get_state_snapshot().cue_count) == cues_before_reorder,
		"a late duplicate of a retired projectile is refused without audio replay")
	# Each batch spent more than the ordering window's tick gap on terminals; a
	# slug fired afterwards is still drawn (the window re-baselines instead of
	# waiting forever for the ticks the terminals used).
	var after_storm := _record(2000, origin, Vector3.RIGHT, 5.0, 20.0)
	bolts.bolt_launched.emit(after_storm)
	var drawn_after_storm := await _pump(
		func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 2)
	_check(drawn_after_storm, "a slug fired after a burst of retired slugs is still drawn (presented %d)"
		% int(_client_replicator.get_audit().get("presented", 0)))
	bolts.bolt_abandoned.emit(after_storm, &"test_cleanup")
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)

	# G
	var orphan := _record(15, origin, Vector3.UP, 5.0, 0.3)
	bolts.bolt_launched.emit(orphan)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 2)
	_host_replicator.clear_host(false)
	var expired := await _pump(
		func() -> bool: return int(_client_replicator.get_audit().get("expired", 0)) >= 1, 6.0
	)
	_check(expired, "a flight whose terminal never arrives is retired after its lifetime")
	_check(not bool(_client_replicator.get_audit().get("owns_combat_authority", true)),
		"the client replicator holds no combat authority")
	_check(int(_client_replicator.get_audit().get("published", 0)) == 0,
		"the client never publishes a projectile")

	_check_launch_descriptor_compatibility(_last_launch_packet)

	for adapter in [_late, _client, _server]:
		adapter.shutdown(&"suite_complete")
	_host_flow.world.queue_free()
	_client_flow.world.queue_free()
	_late_flow.world.queue_free()
	_host_flow.free()
	_client_flow.free()
	_late_flow.free()
	await process_frame
	_finish()


func _check_launch_descriptor_compatibility(launch_packet: Dictionary) -> void:
	var adapter := Adapter.new()
	var replicator := Replicator.new()
	var audio := AudioScene.instantiate() as CombatAudioPresentation
	root.add_child(replicator)
	root.add_child(audio)
	var flow := _configure_client_flow(adapter, replicator, audio)
	for generation in 4:
		var packet := launch_packet.duplicate(true)
		packet.revision = int(packet.revision) + generation
		packet.server_tick = int(packet.server_tick) + generation
		var projectile := packet.projectile as Dictionary
		projectile.projectile_generation = generation + 1
		projectile.source_generation = generation + 1
		projectile.last_update_tick = packet.server_tick
		var descriptor := projectile.get(Replicator.RECORD_KEY, {}) as Dictionary
		if generation == 2:
			descriptor["launch"] = 1
		elif generation == 3:
			descriptor.erase("launch")
		var admission := adapter._apply_projectile_replica_snapshot(packet)
		var presented := flow._on_projectile_replica_packet(packet, admission)
		if generation < 2:
			_check(bool(admission.get("first_admission", false))
				and bool(presented.get("accepted", false))
				and int(audio.get_state_snapshot().cue_count) == generation + 1,
				"a legitimate launch in generation %d dispatches its own cue" % (generation + 1))
		elif generation == 2:
			_check(presented.get("status") == &"invalid_remote_projectile_record"
				and int(audio.get_state_snapshot().cue_count) == 2,
				"a nonboolean launch marker is rejected without audio")
		else:
			_check(bool(presented.get("accepted", false))
				and int(audio.get_state_snapshot().cue_count) == 2,
				"legacy records without a launch marker remain visual-only")
	flow.world.queue_free()
	flow.free()
	adapter.free()
	replicator.queue_free()
	audio.queue_free()


func _configure_client_flow(adapter: Adapter, replicator: Replicator, audio: CombatAudioPresentation, station_origin: Vector3 = Vector3.ZERO) -> GameFlow:
	# Keep unrelated world boot detached; inject the same already-attached
	# presentation and adapter that production GameFlow dispatch uses.
	var flow := GameFlow.new()
	flow.network_session = adapter
	flow._network_session_mode = &"client"
	flow._network_remote_projectile_replicator = replicator
	flow.combat_audio = audio
	flow.world = _make_station_origin(station_origin)
	return flow


func _make_station_origin(origin: Vector3) -> Node3D:
	var station := Node3D.new()
	root.add_child(station)
	station.global_position = origin
	return station


func _record(flight_id: int, origin: Vector3, direction: Vector3, speed: float, lifetime: float) -> Dictionary:
	return {
		"flight_id": flight_id, "generation": 1, "weapon_id": &"test_weapon",
		"origin": origin, "direction": direction, "position": origin,
		"speed": speed, "lifetime": lifetime, "radius": 0.2, "range": speed * lifetime,
		"elapsed": 0.0, "travelled": 0.0,
	}


## Waits on the real clock, not a frame count: a headless run can spin idle
## frames far faster than 60 Hz, and the client's visuals age by real delta.
func _pump(predicate: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _wait_seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("NETWORK_REMOTE_PROJECTILE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("NETWORK_REMOTE_PROJECTILE_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertions, "; ".join(_failures)])
	quit(1)
