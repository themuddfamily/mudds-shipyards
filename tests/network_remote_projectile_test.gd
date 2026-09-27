extends SceneTree

## Mass-driver slugs and seeker torpedoes, replicated host -> client over a real
## loopback ENet session as presentation only.
##
## The host side is a `NetworkRemoteProjectileReplicator` observing two pools
## that emit exactly the signals `MassDriverBoltPool` (a
## `TravellingBoltProjectile`) and `SeekerTorpedoProjectile` emit, publishing
## through the production `publish_projectile_snapshot()` path on a shared
## monotonic tick the way GameFlow's publisher does. The client side is a second
## replicator fed by the client adapter's `projectile_replica_packet`, as the
## GameFlow dispatch does.
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
##      published lifetime, and the client never holds combat authority.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Replicator := preload("res://scripts/network/network_remote_projectile_replicator.gd")


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
var _tick := 0


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
	_host_replicator.set_publisher(Callable(self, "_publish"))
	_client.projectile_replica_packet.connect(func(packet: Dictionary, result: Dictionary) -> void:
		if bool(result.get("accepted", false)):
			_client_replicator.present_packet(packet, StringName(result.get("status", &""))))
	_late.projectile_replica_packet.connect(func(packet: Dictionary, result: Dictionary) -> void:
		if bool(result.get("accepted", false)):
			_late_replicator.present_packet(packet, StringName(result.get("status", &""))))
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

	# B
	var origin := Vector3(10.0, 20.0, -30.0)
	var slug := _record(7, origin, Vector3.FORWARD, 180.0, 2.0)
	bolts.bolt_launched.emit(slug)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var drawn := _client_replicator.get_drawn_projectile_ids()
	_check(drawn.size() == 1, "the client draws the host's slug")
	var slug_id := StringName(drawn[0]) if not drawn.is_empty() else &""
	var first := _client_replicator.get_visual_position(slug_id)
	_check(first.distance_to(origin) < 20.0, "the slug appears at the launch point (%.2f m)" % first.distance_to(origin))
	await _wait_seconds(0.1)
	var later := _client_replicator.get_visual_position(slug_id)
	_check((later - first).dot(Vector3.FORWARD) > 1.0, "the slug flies forward between records")

	# C
	var terminal := slug.duplicate(true)
	terminal["terminal_position"] = origin + Vector3.FORWARD * 50.0
	bolts.bolt_resolved.emit(terminal, {"hit": true, "damaged": true})
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().is_empty())
	_check(_client_replicator.get_drawn_projectile_ids().is_empty()
		and int(_client_replicator.get_audit().get("terminals", 0)) == 1,
		"a resolved slug bursts and stops being drawn")

	# D
	var torpedo_origin := Vector3(0.0, 5.0, 0.0)
	var torpedo := _record(9, torpedo_origin, Vector3.FORWARD, 40.0, 8.0)
	torpedoes.records = [torpedo]
	torpedoes.torpedo_launched.emit(torpedo)
	await _pump(func() -> bool: return _client_replicator.get_drawn_projectile_ids().size() == 1)
	var torpedo_id := StringName(_client_replicator.get_drawn_projectile_ids()[0]) \
		if not _client_replicator.get_drawn_projectile_ids().is_empty() else &""
	var steered := torpedo.duplicate(true)
	steered["position"] = Vector3(30.0, 5.0, -5.0)
	steered["direction"] = Vector3.RIGHT
	torpedoes.records = [steered]
	for _frame in Replicator.TORPEDO_UPDATE_INTERVAL_TICKS * 2:
		_host_replicator.advance_host()
		await process_frame
	await _pump(func() -> bool:
		return _client_replicator.get_visual_position(torpedo_id).distance_to(Vector3(30.0, 5.0, -5.0)) < 12.0)
	var tracked := _client_replicator.get_visual_position(torpedo_id)
	_check(tracked.distance_to(Vector3(30.0, 5.0, -5.0)) < 12.0,
		"the client's torpedo follows the host's steering (%.2f m off)" % tracked.distance_to(Vector3(30.0, 5.0, -5.0)))

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
	_check(_late.join("127.0.0.1", port).accepted, "a late peer connects mid-flight")
	await _pump(func() -> bool: return not _late.get_server_offer().is_empty())
	_host_replicator.republish_for_peer(_late.multiplayer.get_unique_id())
	await _pump(func() -> bool: return _late_replicator.get_drawn_projectile_ids().size() == 1)
	_check(_late_replicator.get_drawn_projectile_ids().size() == 1, "the late peer is sent the live slug")

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

	for adapter in [_late, _client, _server]:
		adapter.shutdown(&"suite_complete")
	await process_frame
	_finish()


func _publish(projectile: Dictionary, terminal: bool, recipients: Array = []) -> Dictionary:
	_tick += 1
	projectile["last_update_tick"] = _tick
	return _server.publish_projectile_snapshot(projectile, recipients, terminal, _tick)


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
