extends "res://tests/in_flight_cabin_integration_test.gd"

## A whole-Main re-entry must leave a session this game can still host or join.
##
## Godot routes an RPC by a node path the receiver resolves against its own
## multiplayer root, so every peer's session adapter has to answer at the same
## relative path. `GameFlow` gives its adapter one: `NetworkSession`, directly
## under Main. Until this suite existed, `_exit_tree()` closed the session and
## dropped the reference but left that node parented, so the next
## `host_network_session()` added a *second* adapter beside the corpse, which
## Godot silently renamed to `@NetworkSession@N`. Every production RPC then went
## out addressed to a path no client had: a player who saved and reloaded, or
## came back through safe-start recovery, got a session that looked connected
## and moved nothing.
##
## The rule this measures is `GameFlow._retire_network_session()`: **the adapter
## does not outlive the session it runs, and Main's tree membership owns its
## lifetime.** Leaving the tree closes the transport and takes the node out of
## the RPC path in the same frame; coming back and hosting (or joining) builds
## exactly one adapter at the canonical name again, and the bindings that speak
## through it — the moving-interior publisher and presenter, seat and crew-role
## authority, projectile authority — bind to that new adapter.
##
## What is real here:
##   * the server is the whole production Main subtree on `res://scenes/main.tscn`,
##     hosting through `GameFlow.host_network_session()`, with its own
##     `PlayerController` boarding the production `HalyardCrewTransport` on real
##     `E` interactions and flying a real climb-out;
##   * one client on real loopback ENet, on its own `SceneMultiplayer` branch
##     with its own `NetworkEnetSessionAdapter`, which stays the same object
##     across every re-entry — the peer really does come back to the same host;
##   * a second bare adapter that *hosts*, for the mirror case, so the re-entered
##     Main is measured joining as well as hosting.
##
## Every leg asserts the same three things over the wire — a seat claim, the
## authority's own moving-interior publication, and one projectile round trip out
## and back — because those are the three production bindings that would be left
## pointing at a dead adapter by a lifecycle that only nulled a reference.
##
## Named `network_*` for the same reason its neighbours are: only suites under
## `tests/network/*` or `tests/network_*` take `run_test_matrix.sh`'s per-run
## flock lane, and this one opens real `ENetMultiplayerPeer` sockets.
##
## The bounded-wait helpers, the real-input helpers and `_check` come from
## `in_flight_cabin_integration_test.gd`; this suite adds no second test driver.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const ProjectileIntent := preload("res://scripts/network/network_projectile_intent.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const PILOT_ENTITY: StringName = &"pilot_halyard_new_design"
const WEAPON_ID: StringName = &"rehost_pulse"
const MIRROR_FRAME_ID: StringName = &"rehost_mirror_frame"
const MIRROR_ENTITY_ID: StringName = &"rehost_mirror_crew"

var _game: GameFlow = null
var _craft: HalyardCrewTransport = null
var _player: PlayerController = null
var _frame: MovingInteriorFrame = null

var _branches: Array[SubViewport] = []
## The peer that never goes away. It is torn down and reconnected around each
## re-entry, but it is the same adapter object throughout, so "the same client
## joins" is literally true rather than a fresh object that cannot notice a
## changed path.
var _client: Adapter = null
## The mirror case's authority: a bare adapter that hosts so the re-entered Main
## can be measured on the join side of the same rule.
var _mirror_host: Adapter = null

var _claim_sequence := 0
var _intent_sequence := 0
var _projectile_clock := 16
var _mirror_tick := 0


func _run() -> void:
	if not await _build_world():
		await _finish_rehost()
		return
	if not await _open_the_first_session():
		await _finish_rehost()
		return
	await _assert_the_first_session_carries_all_three(&"first host")
	await _assert_a_reentered_host_hosts_again()
	await _assert_a_reentered_client_joins_again()
	await _finish_rehost()


# --- world and session ------------------------------------------------------


## The short leg: board the liveaboard craft on real interactions, climb out of
## the yard on real thrust, and idle offline in open space. That is the state a
## player is actually in when they save, and it is the state the re-entry below
## has to survive with its cabin occupancy intact.
func _build_world() -> bool:
	_game = MAIN_SCENE.instantiate() as GameFlow
	if _game == null:
		_check(false, "production scene instantiates for the re-host sweep")
		return false
	root.add_child(_game)
	await process_frame
	await physics_frame
	_player = _game.get_node("Player") as PlayerController
	_craft = _game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	_game.canopy_motion_time = 0.02
	_game.boarding_motion_time = 0.08
	_game.disembarking_motion_time = 0.08
	_game.start_shift()
	await process_frame
	_check(_craft != null and _player != null and _craft.get_ship_id() == SHIP_ID,
		"the production Main subtree supplies the Halyard and the host's own player")
	if _craft == null or _player == null:
		return false
	_check(_game.get_network_session() == null
		and _game.get_network_session_adapter_nodes().is_empty(),
		"solo startup builds no session adapter at all")
	await _board_with_real_interaction(_game, _player, _craft)
	_check(_craft.is_piloted(), "ordinary E boards the liveaboard craft")
	await _wake_engine_with_flight_demand(_craft, "flight demand starts the Halyard")
	var launch_origin := _craft.global_position
	Input.action_press(&"move_forward")
	Input.action_press(&"pitch_up")
	var pitched := await _wait_until(
		func() -> bool: return -_craft.global_basis.z.y >= 0.5, 4.0
	)
	Input.action_release(&"pitch_up")
	var cleared := await _wait_until(
		func() -> bool: return _craft.global_position.distance_to(launch_origin) > 120.0, 12.0
	)
	Input.action_release(&"move_forward")
	_check(pitched and cleared and not bool(_craft.get_telemetry().get("landed", false)),
		"a normal climb-out puts the Halyard in open space before anyone connects")
	await _idle_engine_offline(_craft, "idle propulsion allows cabin access")
	_frame = _craft.get_moving_interior_component()
	_check(_frame != null, "the Halyard publishes its production moving-interior frame")
	return _frame != null


## The host's session lives on the Main subtree's own `SceneMultiplayer`, so the
## adapter's path relative to its multiplayer root is `NetworkSession` — the same
## relative path each peer branch gives its own adapter, which is what lets the
## production RPCs route between them in one process. That equality is the
## invariant this suite exists to protect.
func _open_the_first_session() -> bool:
	set_multiplayer(SceneMultiplayer.new(), _game.get_path())
	_client = _make_branch_adapter("RehostClient")
	_mirror_host = _make_branch_adapter("RehostMirrorHost")
	var port := _reserve_loopback_port("the first hosted session")
	if port <= 0:
		return false
	_check(bool(_game.host_network_session(port, 4).get("accepted", false)),
		"GameFlow hosts the authoritative session")
	if _game.get_network_session() == null:
		return false
	return await _join_the_standing_client(port, "the first hosted session")


func _make_branch_adapter(branch_name: String) -> Adapter:
	var branch := SubViewport.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	_branches.append(branch)
	var adapter := Adapter.new()
	adapter.name = GameFlow.NETWORK_SESSION_NODE_NAME
	branch.add_child(adapter)
	return adapter


func _reserve_loopback_port(label: String) -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port for %s" % label)
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


## Reconnects the one standing client to whatever host is listening on `port`.
## The adapter object is never replaced, so every assertion after this is about
## the same peer resolving the host's paths again.
func _join_the_standing_client(port: int, label: String) -> bool:
	# Always a clean reconnect: the same adapter object, a new transport.
	_client.shutdown(&"rehost_sweep_reconnect")
	var server = _game.get_network_session()
	_check(bool(_client.join("127.0.0.1", port).get("accepted", false)),
		"the standing client opens a connection to %s" % label)
	var peer := _client
	var both_sides_admitted := func() -> bool:
		return server._peer_generations.size() >= 1 and not peer.get_server_offer().is_empty()
	var admitted := await _wait_until(both_sides_admitted, 6.0)
	_check(admitted, "%s admits the standing client, and it has the host's offer" % label)
	return admitted


# --- the rule ---------------------------------------------------------------


## Exactly one adapter, under the canonical name, and it is the one GameFlow is
## actually running. An auto-renamed second adapter is the whole defect, so this
## refuses to accept a session that has more than one.
func _assert_one_canonical_adapter(label: String) -> void:
	var adapters: Array[Node] = _game.get_network_session_adapter_nodes()
	_check(adapters.size() == 1,
		"%s: Main carries exactly one session adapter (%d)" % [label, adapters.size()])
	if adapters.size() != 1:
		return
	_check(String(adapters[0].name) == GameFlow.NETWORK_SESSION_NODE_NAME,
		"%s: it still holds the canonical name rather than a Godot rename (%s)"
			% [label, String(adapters[0].name)])
	_check(adapters[0] == _game.get_network_session(),
		"%s: the node in the RPC path is the adapter GameFlow is running" % label)


## The string each peer has to resolve for the other's RPC to land: the adapter's
## path relative to the multiplayer root that routes it.
func _relative_rpc_path(node: Node) -> String:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return ""
	var api := node.multiplayer
	if api == null:
		return String(node.get_path())
	var multiplayer_root := node.get_node_or_null(api.get_root_path())
	if multiplayer_root == null:
		return String(node.get_path())
	return String(multiplayer_root.get_path_to(node))


func _assert_matching_rpc_paths(label: String, peer: Adapter) -> void:
	var host_path := _game.get_network_session_rpc_path()
	var peer_path := _relative_rpc_path(peer)
	_check(host_path == GameFlow.NETWORK_SESSION_NODE_NAME,
		"%s: Main's adapter answers at the canonical RPC path (%s)" % [label, host_path])
	_check(host_path == peer_path,
		"%s: both peers address the same RPC path (%s against %s)"
			% [label, host_path, peer_path])


# --- the three bindings, over the wire --------------------------------------


## A seat claim that really crosses the wire. The authority seats the peer on its
## own ledger, and the peer's role intent is the client-to-server RPC that has to
## reach it: a seat authority bound to a retired adapter never sees this.
func _round_trip_seat_claim(server, client, label: String) -> void:
	var peer_id: int = client.multiplayer.get_unique_id()
	_claim_sequence += 1
	var ship_id := StringName("rehost_ship_%d" % _claim_sequence)
	var seat_id := StringName("rehost_seat_%d" % _claim_sequence)
	var avatar_id := StringName("rehost_avatar_%d" % _claim_sequence)
	_check(bool(server.register_owned_ship(ship_id, _claim_sequence, peer_id).get("accepted", false)),
		"%s: the authority registers the joined peer's ship" % label)
	_check(bool(server.register_crew_seat(
			seat_id, ship_id, &"gunner", &"", _claim_sequence).get("accepted", false)),
		"%s: the authority registers a crew seat aboard it" % label)
	var claim: Dictionary = server.claim_crew_seat(
		peer_id, avatar_id, seat_id, &"gunner", _claim_sequence
	)
	_check(bool(claim.get("accepted", false)),
		"%s: the seat is claimed for the joined peer (%s)"
			% [label, String(claim.get("status", &""))])
	if not bool(claim.get("accepted", false)):
		return
	var results: Array[Dictionary] = []
	var sink := func(result: Dictionary) -> void: results.append(result)
	server.crew_role_result.connect(sink)
	var sent: Dictionary = client.send_crew_role_intent(avatar_id, &"gunner", _claim_sequence)
	var arrived := await _wait_until(func() -> bool: return not results.is_empty(), 5.0)
	server.crew_role_result.disconnect(sink)
	_check(arrived and bool(sent.get("accepted", false)),
		"%s: the peer's seat role intent reaches the authority" % label)
	if not arrived:
		return
	var role: Dictionary = results[0].get("role", {}) as Dictionary
	_check(bool(results[0].get("accepted", false))
		and StringName(role.get("avatar_id", &"")) == avatar_id
		and StringName(role.get("seat_id", &"")) == seat_id,
		"%s: the authority confirms the claimed seat for that avatar (%s)"
			% [label, String(results[0].get("status", &""))])


## One shot out and its replica back, on the same pair of paths. The intent is a
## client-to-server RPC and the replica an authority-to-client one, so a single
## broken path fails one half and not the other.
func _round_trip_projectile(server, client, label: String) -> void:
	var peer_id: int = client.multiplayer.get_unique_id()
	_intent_sequence += 1
	var source_id := StringName("rehost_turret_%d" % _intent_sequence)
	_check(bool(server.register_projectile_source(peer_id, source_id, 1, &"mudds", {
			WEAPON_ID: {"speed": 120.0, "damage": 8.0, "lifetime": 2.0},
		}).get("accepted", false)),
		"%s: the authority registers the peer's weapon source" % label)
	_projectile_clock += 4
	_check(bool(server.set_projectile_server_tick(_projectile_clock).get("accepted", false)),
		"%s: the authority advances its own projectile clock" % label)
	var spawned: Array[Dictionary] = []
	var sink := func(result: Dictionary) -> void: spawned.append(result)
	server.projectile_intent_result.connect(sink)
	client.send_projectile_intent(ProjectileIntent.create(
		peer_id, source_id, 1, 1, _intent_sequence, _projectile_clock, WEAPON_ID,
		Vector3(4.0, 1.0, 0.0), Vector3.FORWARD
	).to_dictionary())
	var fired := await _wait_until(func() -> bool: return not spawned.is_empty(), 5.0)
	server.projectile_intent_result.disconnect(sink)
	var spawn_accepted := fired and bool(spawned[0].get("accepted", false))
	_check(spawn_accepted,
		"%s: the peer's shot reaches the authority and spawns there (%s)"
			% [label, String(spawned[0].get("status", &"")) if fired else "no intent arrived"])
	if not spawn_accepted:
		return
	var projectile: Dictionary = spawned[0].get("projectile", {}) as Dictionary
	var before := int(client.get_presentation_cursor_audit().get("projectile_count", 0))
	_check(bool(server.publish_projectile_snapshot(projectile, [peer_id]).get("accepted", false)),
		"%s: the authority publishes that shot back to the peer" % label)
	var presented := await _wait_until(
		func() -> bool:
			return int(client.get_presentation_cursor_audit().get("projectile_count", 0)) > before,
		5.0
	)
	_check(presented,
		"%s: the peer presents the authority's replica of its own shot" % label)


## The production publisher, not a hand-fed stream. `GameFlow` publishes the
## crewmate aboard its own flying cabin from its own `_physics_process`; a
## publisher still holding a retired adapter sends nothing anyone receives.
func _round_trip_moving_interior_publication(label: String) -> void:
	var before := int(_sample(_client, PILOT_ENTITY).get("server_tick", -1))
	await _drive(40)
	var audit: Dictionary = _game.get_network_moving_interior_publication_audit()
	_check(int(audit.get("published", 0)) > 0,
		"%s: the host publishes its cabin occupancy without anyone asking it to" % label)
	var sample := _sample(_client, PILOT_ENTITY)
	_check(not sample.is_empty(),
		"%s: the client receives the seated pilot's relationship" % label)
	_check(int(sample.get("server_tick", -1)) > before,
		"%s: the poses arriving are new ones, not the pre-re-entry ones (%d after %d)"
			% [label, int(sample.get("server_tick", -1)), before])
	_check(int(sample.get("occupancy_state", -1)) == Relationship.STATE_SEATED,
		"%s: the client is told the pilot is in a seat, not standing in the cabin" % label)


func _assert_the_first_session_carries_all_three(label: String) -> void:
	_assert_one_canonical_adapter(label)
	_assert_matching_rpc_paths(label, _client)
	await _round_trip_seat_claim(_game.get_network_session(), _client, label)
	await _round_trip_moving_interior_publication(label)
	await _round_trip_projectile(_game.get_network_session(), _client, label)


# --- the two re-entries -----------------------------------------------------


## Streams the whole Main subtree out and back, the way a save reload and
## safe-start recovery both do, and reports the adapter that was retired on the
## way out so the caller can prove it was freed rather than merely unparented.
func _stream_main_out_and_back(label: String) -> Node:
	var retiring: Node = _game.get_network_session()
	var parent := _game.get_parent()
	_craft.velocity = Vector3.ZERO
	await physics_frame
	parent.remove_child(_game)
	await process_frame
	await process_frame
	_check(_game.get_network_session() == null,
		"%s: a detached Main is running no session" % label)
	_check(_game.get_network_session_adapter_nodes().is_empty(),
		"%s: it takes its adapter out of the RPC path rather than leaving a corpse (%d left)"
			% [label, _game.get_network_session_adapter_nodes().size()])
	_check(not is_instance_valid(retiring),
		"%s: the retired adapter is freed, not orphaned" % label)
	parent.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	_check(_craft.is_piloted() and _craft.get_moving_interior_component() == _frame,
		"%s: re-entry leaves the host's own pilot flying the same cabin" % label)
	_check(_game.get_network_moving_interior_published_entities().is_empty(),
		"%s: it speaks for nobody until it has a session to speak through" % label)
	return retiring


## The defect itself: a Main that has been streamed out and back hosts again, the
## same client rejoins, and all three bindings work on the new adapter.
func _assert_a_reentered_host_hosts_again() -> void:
	var label := "re-entered host"
	var orphans_before := int(
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	)
	await _stream_main_out_and_back(label)
	var port := _reserve_loopback_port("the re-entered host")
	if port <= 0:
		return
	_check(bool(_game.host_network_session(port, 4).get("accepted", false)),
		"%s: it starts hosting again" % label)
	if _game.get_network_session() == null:
		return
	_assert_one_canonical_adapter(label)
	if not await _join_the_standing_client(port, "the re-entered host"):
		return
	_assert_matching_rpc_paths(label, _client)
	await _round_trip_seat_claim(_game.get_network_session(), _client, label)
	await _round_trip_moving_interior_publication(label)
	await _round_trip_projectile(_game.get_network_session(), _client, label)
	var orphans_after := int(
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	)
	_check(orphans_after <= orphans_before,
		"%s: the whole cycle leaves no node orphaned behind it (%d after %d)"
			% [label, orphans_after, orphans_before])


## The mirror: the same rule on the join side. A re-entered Main joins a host
## that was already listening, so the paths have to line up in the direction the
## other peer chose rather than one this subtree just built.
func _assert_a_reentered_client_joins_again() -> void:
	var label := "re-entered client"
	_client.shutdown(&"rehost_sweep_client_reentry")
	var port := _reserve_loopback_port("the mirror host")
	if port <= 0:
		return
	_check(bool(_mirror_host.host(port, 4).get("accepted", false)),
		"%s: a separate peer is already hosting when Main comes back" % label)
	await _stream_main_out_and_back(label)
	_check(bool(_game.join_network_session("127.0.0.1", port).get("accepted", false)),
		"%s: the re-entered Main joins that host" % label)
	var session = _game.get_network_session()
	if session == null:
		return
	_assert_one_canonical_adapter(label)
	# Both halves of admission, not just the server's: the credentials a client
	# signs its intents with arrive with the host's offer, one round trip after
	# the host has admitted it.
	var host := _mirror_host
	var both_sides_admitted := func() -> bool:
		return host._peer_generations.size() >= 1 and not session.get_server_offer().is_empty()
	var admitted := await _wait_until(both_sides_admitted, 6.0)
	_check(admitted, "%s: the host admits the re-entered Main, which has its offer" % label)
	if not admitted:
		return
	_assert_matching_rpc_paths(label, _mirror_host)
	await _round_trip_seat_claim(_mirror_host, session, label)
	await _round_trip_projectile(_mirror_host, session, label)
	# The publication direction reverses with the roles: here the authority is
	# the other peer, and what has to arrive is a relationship this subtree's own
	# adapter resolves and stores.
	var main_peer_id: int = session.multiplayer.get_unique_id()
	_check(bool(_mirror_host.register_moving_interior_frame(
			MIRROR_FRAME_ID, 1).get("accepted", false)),
		"%s: the host owns a moving-interior frame to speak about" % label)
	_mirror_tick += 7
	_check(bool(_mirror_host.publish_moving_interior_snapshot(
			Relationship.create(
				_mirror_tick, MIRROR_ENTITY_ID, 1, MIRROR_FRAME_ID, 1,
				Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 1.5))
			).get_snapshot(),
			[main_peer_id]
		).get("accepted", false)),
		"%s: the host publishes a cabin pose to it" % label)
	var received := await _wait_until(
		func() -> bool: return not _sample(session, MIRROR_ENTITY_ID).is_empty(), 5.0
	)
	_check(received,
		"%s: the re-entered Main's own adapter receives the host's cabin pose" % label)


# --- driving and teardown ---------------------------------------------------


## One authoritative tick, plus the render frames the client's replica needs. The
## host publishes from its own `_physics_process`; nothing here publishes for it.
func _drive(rounds: int) -> void:
	for _round in maxi(1, rounds):
		await physics_frame
		await process_frame


func _sample(peer, entity_id: StringName) -> Dictionary:
	if not is_instance_valid(peer):
		return {}
	return (peer._moving_replica_samples.get(entity_id, {}) as Dictionary).duplicate(true)


func _finish_rehost() -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"sprint_boost", &"hover",
	]:
		Input.action_release(action)
	for peer in [_client, _mirror_host]:
		if peer != null and is_instance_valid(peer):
			peer.shutdown(&"rehost_sweep_close")
	_client = null
	_mirror_host = null
	if _game != null and is_instance_valid(_game):
		if _game.get_parent() != null:
			_game.get_parent().remove_child(_game)
		_game.free()
		_game = null
	await process_frame
	await process_frame
	for branch in _branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	_branches.clear()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_REHOST_AFTER_REENTRY_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_REHOST_AFTER_REENTRY_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, "; ".join(_failures)])
	quit(1)
