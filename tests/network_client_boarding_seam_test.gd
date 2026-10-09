extends "res://tests/in_flight_cabin_integration_test.gd"

## The client half of the production hatch, over a real ENet session.
##
## The server half is proved next door in `network_remote_body_simulation_test`:
## a boarding ledger that registers every walkable-interior craft with a pilot
## seat and four cabin berths, and a confirmed berth claim that stands a
## server-simulated body at the craft's cabin stand pose. Everything there is
## driven by hand-built `NetworkBoardingIntent` packets from bare client
## adapters. **Nothing there is a production client.**
##
## This suite closes that gap. Both ends are whole production `Main` subtrees:
##
##   * the host runs `GameFlow.host_network_session()`, owns the ledger, and
##     admits the bodies;
##   * each client runs `GameFlow.join_network_session()` and boards with the
##     ordinary `ShipBoardingArea` prompt — one real `interact` press by a
##     player who walked to the hatch, exactly as in solo play;
##   * three further bare adapters exist only to hold berths, so the crowded
##     case is a genuinely full ledger rather than a stubbed refusal.
##
## Each client `Main` lives in its own `SubViewport` with `own_world_3d` set,
## because two shipyards in one physics space would let one peer's interaction
## area discover the other peer's boarding hatch. The session between them is
## real loopback ENet either way: the worlds are separated, the wire is not.
##
## What is asserted:
##   A. a client's own boarding interaction sends the intent instead of
##      boarding locally, the host admits a body at the cabin stand, and the
##      client binds and drives it — it walks, and the server's pose follows;
##   B. the hatch disembark sends the matching intent and only releases the
##      local presentation on the confirmation, leaving the player on the deck;
##   C. a second client whose berths are all held is refused with the ledger's
##      own `craft_full` verdict in one round trip, and does not move;
##   D. a request the host never answers times out, leaves the client exactly
##      where it stood, and shows one refusal.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const FRAME_ID: StringName = &"frame_halyard_new_design"
## Berths the bare filler peers hold so the crowded case is a full ledger.
const FILLER_ENTITIES: Array = [&"fillera", &"fillerb", &"fillerc"]
## Frame-local metres the driven body must cover before the suite believes the
## client's own input walked it rather than the cabin settling it.
const MIN_WALK_PROGRESS := 0.75
## Secure packets one peer may spend in the authority's one-second window.
## Exceeding it is how a real host stops answering a flooding peer, and is
## what group D uses to produce a request nobody ever answers.
const SECURE_FLOOD_PACKETS := 64

var _host: GameFlow = null
var _host_craft: HalyardCrewTransport = null
var _host_frame: MovingInteriorFrame = null
var _server = null

var _client_games: Array[GameFlow] = []
var _client_crafts: Array = []
var _client_players: Array = []
var _fillers: Array = []
var _filler_peer_ids: Array[int] = []
var _boarding_results: Array = []


func _run() -> void:
	if not await _build_host():
		await _finish_client_boarding()
		return
	if not await _build_clients():
		await _finish_client_boarding()
		return
	if not await _open_session():
		await _finish_client_boarding()
		return
	await _assert_a_client_hatch_press_asks_the_ledger()
	await _assert_the_bound_client_drives_the_server_body()
	await _assert_the_hatch_disembark_waits_for_the_ledger()
	await _assert_a_full_ledger_refuses_the_next_client()
	await _assert_an_unanswered_request_times_out()
	await _assert_an_expiry_does_not_lock_the_peer_out()
	await _assert_the_host_ledger_clock_runs_every_physics_tick()
	await _assert_a_passenger_is_promoted_to_pilot_in_place()
	await _assert_the_host_is_refused_a_seat_a_crewmate_holds()
	await _finish_client_boarding()


# --- world and session ------------------------------------------------------


func _build_host() -> bool:
	# One physics step per rendered frame, however loaded the machine is: ENet
	# is polled once per frame, so several physics steps in one frame would
	# batch the 15 Hz intent cadence into bursts and starve the body between
	# them. A property of the harness, not of the production peer.
	Engine.max_physics_steps_per_frame = 1
	_host = MAIN_SCENE.instantiate() as GameFlow
	if _host == null:
		_check(false, "the production scene instantiates as the session host")
		return false
	_host.name = "HostMain"
	root.add_child(_host)
	await process_frame
	await physics_frame
	_host_craft = _host.get_node_or_null("HalyardCrewTransport") as HalyardCrewTransport
	_host.start_shift()
	await process_frame
	await physics_frame
	_check(_host_craft != null and _host_craft.get_ship_id() == SHIP_ID,
		"the host's own subtree supplies the Halyard the clients will board")
	if _host_craft == null:
		return false
	_host_frame = _host_craft.get_moving_interior_component()
	_check(_host_frame != null, "the host's Halyard publishes its moving-interior frame")
	# The host's pilot stays on the deck and well clear of every hatch. Input
	# is one process-global singleton, so a key a client presses is a key this
	# player sees too; standing clear is what keeps that harmless.
	var host_spawn: Transform3D = _host.world.get_player_spawn()
	(_host.get_node("Player") as PlayerController).teleport_to(
		Transform3D(Basis.IDENTITY, host_spawn.origin + Vector3(0.0, 0.0, 40.0))
	)
	return _host_frame != null


func _build_clients() -> bool:
	for index in 2:
		var branch := SubViewport.new()
		branch.name = "ClientWorld%d" % index
		branch.size = Vector2i(64, 64)
		# Its own physics space, so this client's interaction area can only
		# ever discover this client's own shipyard.
		branch.own_world_3d = true
		branch.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(branch)
		var game := MAIN_SCENE.instantiate() as GameFlow
		if game == null:
			_check(false, "the production scene instantiates as client %d" % index)
			return false
		game.name = "ClientMain%d" % index
		branch.add_child(game)
		await process_frame
		await physics_frame
		var craft := game.get_node_or_null("HalyardCrewTransport") as HalyardCrewTransport
		var client_player := game.get_node_or_null("Player") as PlayerController
		game.canopy_motion_time = 0.02
		game.boarding_motion_time = 0.08
		game.disembarking_motion_time = 0.08
		game.start_shift()
		await process_frame
		await physics_frame
		if craft == null or client_player == null:
			_check(false, "client %d has its own Halyard and player" % index)
			return false
		_client_games.append(game)
		_client_crafts.append(craft)
		_client_players.append(client_player)
	_check(_client_games.size() == 2,
		"two whole production clients stand in their own worlds beside the host")
	_check(_client_crafts[0] != _host_craft and _client_crafts[0] != _client_crafts[1],
		"each peer's Halyard is its own node, sharing only a ship id")
	return true


func _open_session() -> bool:
	set_multiplayer(SceneMultiplayer.new(), _host.get_path())
	for game in _client_games:
		set_multiplayer(SceneMultiplayer.new(), game.get_path())
	for index in FILLER_ENTITIES.size():
		var branch := SubViewport.new()
		branch.name = "FillerPeer%d" % index
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		var adapter := Adapter.new()
		adapter.name = GameFlow.NETWORK_SESSION_NODE_NAME
		branch.add_child(adapter)
		_fillers.append(adapter)
	var port := _reserve_client_boarding_port()
	if port <= 0:
		return false
	var hosted := _host.host_network_session(port, 8)
	_check(bool(hosted.get("accepted", false)), "the host GameFlow opens the authoritative session")
	_server = _host.get_network_session()
	if _server == null or not bool(hosted.get("accepted", false)):
		return false
	_server.boarding_intent_result.connect(_on_host_boarding_result)
	var joined := true
	for game in _client_games:
		joined = joined and bool(game.join_network_session("127.0.0.1", port).get("accepted", false))
	for adapter in _fillers:
		joined = joined and bool(adapter.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "every client and filler peer joins the host over loopback")
	var expected := _client_games.size() + _fillers.size()
	var admitted := await _wait_until(
		func() -> bool: return _server._peer_generations.size() >= expected, 12.0
	)
	_check(admitted, "the host admits all %d peers" % expected)
	if not admitted:
		return false
	# Both halves of admission: the credentials a client signs its intents with
	# arrive with the host's offer, one round trip after the host admitted it.
	var offered := await _wait_until(Callable(self, "_every_client_holds_the_offer"), 8.0)
	_check(offered, "each client holds the host's offer before it asks for a berth")
	_filler_peer_ids = []
	for adapter in _fillers:
		_filler_peer_ids.append(adapter.multiplayer.get_unique_id())
	_check(_host.get_network_session_rpc_path() == GameFlow.NETWORK_SESSION_NODE_NAME
		and _client_games[0].get_network_session_rpc_path() == GameFlow.NETWORK_SESSION_NODE_NAME,
		"host and client resolve their adapters to the one canonical RPC path")
	return offered


func _every_client_holds_the_offer() -> bool:
	for game in _client_games:
		var session = game.get_network_session()
		if session == null or session.get_server_offer().is_empty():
			return false
	return true


func _reserve_client_boarding_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port for the client boarding seam")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


# --- A. the press asks the ledger -------------------------------------------


func _assert_a_client_hatch_press_asks_the_ledger() -> void:
	var game := _client_games[0]
	var craft := _client_crafts[0] as HalyardCrewTransport
	var client_player := _client_players[0] as PlayerController
	_boarding_results.clear()
	var bodies_before := int(_host.get_network_remote_body_audit().get("bodies", 0))
	var occupants_before := _host_frame.get_occupant_count()
	_check(int(game.get_network_client_boarding_audit().get("requests", -1)) == 0,
		"the client has asked for nothing before its player reaches the hatch")
	await _press_the_hatch(game, client_player, craft)
	var answered := await _wait_until(
		func() -> bool: return _client_confirmations(game) >= 1, 8.0
	)
	var audit: Dictionary = game.get_network_client_boarding_audit()
	_check(answered and int(audit.get("requests", 0)) >= 1,
		"one ordinary E at the hatch sent a boarding intent and was answered (%s)"
			% String(audit.get("last_status", &"none")))
	_check(String(audit.get("claimed_seat_id", &"")).begins_with("%s_cabin_" % String(SHIP_ID)),
		"the client claimed a cabin berth, not the pilot seat (%s)"
			% String(audit.get("claimed_seat_id", &"?")))
	_check(not craft.is_piloted() and game.phase == GameFlow.Phase.IN_FLIGHT_CABIN,
		"the client did not board itself into the pilot seat")
	await _drive_session(6)
	var entity := GameFlow.network_client_boarding_avatar_id(
		game.get_network_session().multiplayer.get_unique_id()
	)
	var body := _host_body(entity)
	_check(body != null and body.is_inside_tree(),
		"the host stood a server-simulated body up for the confirmed claim")
	var host_audit: Dictionary = _host.get_network_remote_body_audit()
	_check(int(host_audit.get("hatch_admissions", 0)) == 1
		and int(host_audit.get("bodies", 0)) == bodies_before + 1,
		"the hatch seam records exactly one admission")
	if body == null:
		return
	_check(_host_frame.is_occupant_registered(body)
		and _host_frame.get_occupant_count() == occupants_before + 1,
		"the host's craft carries the admitted body")
	var stand_local := _host_craft.to_local(_host_craft.get_cabin_stand_transform().origin)
	var local := _host_frame.get_occupant_frame_local_transform(body).origin
	_check(local.distance_to(stand_local) < 0.6,
		"the body stands at the host craft's own cabin stand pose")
	var client_local := craft.get_moving_interior_component() \
		.get_occupant_frame_local_transform(client_player).origin
	_check(client_local.distance_to(stand_local) < 0.6,
		"the client presents its own player at the same stand pose")
	_check(bool(game.get_network_remote_body_audit().get("intent_source_bound", false)),
		"the client bound its intent stream to the body the host simulates for it")


# --- B. the client drives it ------------------------------------------------


func _assert_the_bound_client_drives_the_server_body() -> void:
	var game := _client_games[0]
	var client_player := _client_players[0] as PlayerController
	var entity := GameFlow.network_client_boarding_avatar_id(
		game.get_network_session().multiplayer.get_unique_id()
	)
	var body := _host_body(entity)
	if body == null:
		_check(false, "a driven body exists before the walk")
		return
	var start_server := _host_frame.get_occupant_frame_local_transform(body).origin
	var client_frame := (_client_crafts[0] as HalyardCrewTransport).get_moving_interior_component()
	var start_client := client_frame.get_occupant_frame_local_transform(client_player).origin
	# Real held input, the same key a player holds. The host's own pilot is
	# standing clear on the deck and walks too; that costs nothing here.
	Input.action_press(&"move_forward")
	await _drive_session(70)
	Input.action_release(&"move_forward")
	await _drive_session(30)
	var end_server := _host_frame.get_occupant_frame_local_transform(body).origin
	var end_client := client_frame.get_occupant_frame_local_transform(client_player).origin
	var server_walk := start_server.distance_to(end_server)
	var client_walk := start_client.distance_to(end_client)
	if end_server.distance_to(end_client) >= 1.5:
		print("BODY_PREDICTION_AUDIT: ", game.get_network_remote_body_intent_source().get_audit())
	_check(client_walk >= MIN_WALK_PROGRESS,
		"the client's own player walked the cabin on held input (%.2f m)" % client_walk)
	_check(server_walk >= MIN_WALK_PROGRESS,
		"the server-simulated body followed the client's intent (%.2f m)" % server_walk)
	_check(end_server.distance_to(end_client) < 1.5,
		"the authority's pose and the client's prediction agree within a stride (%.2f m)"
			% end_server.distance_to(end_client))
	_check(int(game.get_network_remote_body_intent_source().get_audit().get("sent", 0)) > 0,
		"the client streamed real movement intents while it walked")


# --- C. the disembark waits for the ledger ----------------------------------


func _assert_the_hatch_disembark_waits_for_the_ledger() -> void:
	var game := _client_games[0]
	var craft := _client_crafts[0] as HalyardCrewTransport
	var client_player := _client_players[0] as PlayerController
	var entity := GameFlow.network_client_boarding_avatar_id(
		game.get_network_session().multiplayer.get_unique_id()
	)
	var releases_before := int(_host.get_network_remote_body_audit().get("hatch_releases", 0))
	var deck: Vector3 = (game.world.get_player_spawn() as Transform3D).origin
	_check(client_player.global_position.distance_to(deck) > 2.0,
		"the client's player is aboard, not on the deck, before the hatch press")
	# The cabin stand faces aft, so group B's held forward walked the player
	# down the aisle, away from the cockpit where a berth holder's press asks
	# for the pilot seat instead of the hatch.
	_check(not game._network_client_near_pilot_seat(craft),
		"the passenger stands aft of the cockpit's reach before pressing the hatch")
	await _press_the_hatch(game, client_player, craft)
	var released := await _wait_until(
		func() -> bool: return _client_is_unberthed(game), 8.0
	)
	await _drive_session(8)
	_check(released, "the hatch disembark was confirmed by the ledger before anything moved")
	_check(_host_body(entity) == null
		and int(_host.get_network_remote_body_audit().get("hatch_releases", 0))
			== releases_before + 1,
		"the host released the body the ledger let go")
	_check(client_player.global_position.distance_to(deck) < 3.0,
		"the client's player is back on the yard deck (%.2f m from the spawn)"
			% client_player.global_position.distance_to(deck))
	_check(not bool(game.get_network_remote_body_audit().get("intent_source_bound", true)),
		"the client stopped driving a body it no longer has")
	_check(not craft.get_moving_interior_component().is_occupant_registered(client_player),
		"the client's own cabin occupancy went with the berth")


# --- D. a full ledger refuses the next client -------------------------------


func _assert_a_full_ledger_refuses_the_next_client() -> void:
	var game := _client_games[1]
	var craft := _client_crafts[1] as HalyardCrewTransport
	var client_player := _client_players[1] as PlayerController
	# Fill every berth the ledger offers from the bare filler peers, so the
	# refusal the production client meets is a genuinely full craft.
	var filled := 0
	for index in FILLER_ENTITIES.size():
		_boarding_results.clear()
		_send_filler_boarding(
			index, StringName(FILLER_ENTITIES[index]),
			GameFlow.network_cabin_berth_seat_id(SHIP_ID, index + 1), 0,
			BoardingIntent.ACTION_BOARD
		)
		await _wait_until(func() -> bool: return not _boarding_results.is_empty(), 4.0)
		if not _boarding_results.is_empty() and bool(_boarding_results[0].get("accepted", false)):
			filled += 1
	# The fourth berth is held by the first client's peer, boarding again.
	var first := _client_games[0]
	var first_craft := _client_crafts[0] as HalyardCrewTransport
	await _press_the_hatch(first, _client_players[0] as PlayerController, first_craft)
	await _wait_until(func() -> bool: return _client_holds_a_berth(first), 8.0)
	_check(filled == FILLER_ENTITIES.size()
		and not first.get_network_client_boarding_audit().get("claim", {}).is_empty(),
		"all %d cabin berths are held before the next client presses E"
			% GameFlow.NETWORK_CABIN_BERTH_COUNT)
	await _drive_session(6)
	await _walk_to_the_hatch(game, client_player, craft)
	var stood := client_player.global_transform
	var phase_before := game.phase
	var refusals_before := int(game.get_network_client_boarding_audit().get("refusals", 0))
	var requests_before := int(game.get_network_client_boarding_audit().get("requests", 0))
	await _press_interact()
	var refused := await _wait_until(
		func() -> bool: return _client_refusals(game) > refusals_before, 10.0
	)
	var audit: Dictionary = game.get_network_client_boarding_audit()
	_check(refused and audit.get("last_status") == &"craft_full",
		"the second client is refused with the ledger's own reason (%s)"
			% String(audit.get("last_status", &"none")))
	_check(int(audit.get("requests", 0)) == requests_before + 1,
		"a full craft costs one ask, not one per berth (%d asks)"
			% (int(audit.get("requests", 0)) - requests_before))
	_check(StringName(first.get_network_client_boarding_audit().get("claimed_seat_id", &""))
			== GameFlow.network_cabin_berth_seat_id(SHIP_ID, GameFlow.NETWORK_CABIN_BERTH_COUNT),
		"the first client was assigned the one free berth in a single answer (%s)"
			% String(first.get_network_client_boarding_audit().get("claimed_seat_id", &"?")))
	_check(audit.get("claim", {}).is_empty() and not bool(
			game.get_network_remote_body_audit().get("intent_source_bound", true)),
		"a refused client holds no berth and drives no body")
	_check(game.phase == phase_before
		and client_player.global_position.distance_to(stood.origin) < 0.5,
		"a refused client is left standing exactly where it pressed the key")
	var report: Dictionary = game.get_boarding_confirmation_presentation_report()
	var view: Dictionary = (report.get("adapter", {}) as Dictionary).get("view", {}) as Dictionary
	_check(StringName(view.get("state", &"")) == &"rejected"
		and String(view.get("message", "")).contains("CRAFT FULL"),
		"the existing refusal presentation carries the ledger's reason (%s)"
			% String(view.get("message", "")))


# --- E. the request nobody answers ------------------------------------------


func _assert_an_unanswered_request_times_out() -> void:
	var game := _client_games[1]
	var craft := _client_crafts[1] as HalyardCrewTransport
	var client_player := _client_players[1] as PlayerController
	var session = game.get_network_session()
	await _walk_to_the_hatch(game, client_player, craft)
	var stood := client_player.global_transform
	var phase_before := game.phase
	var refusals_before := int(game.get_network_client_boarding_audit().get("refusals", 0))
	var timeouts_before := int(game.get_network_client_boarding_audit().get("timeouts", 0))
	# Spend this peer's secure-packet budget for the authority's current
	# window, in the frame before the key press. A host that is being flooded
	# stops reading that peer's packets until the window rolls, which is the
	# production way a request can be sent and never answered at all.
	for _flood in SECURE_FLOOD_PACKETS:
		session.send_movement_intent({})
	await _press_interact()
	var timed_out := await _wait_until(
		func() -> bool: return _client_timeouts(game) > timeouts_before, 14.0
	)
	var audit: Dictionary = game.get_network_client_boarding_audit()
	_check(timed_out and audit.get("last_status") == &"host_did_not_answer",
		"a request the host never answered expires on the client (%s)"
			% String(audit.get("last_status", &"none")))
	_check(int(audit.get("refusals", 0)) == refusals_before + 1,
		"the expiry shows exactly one refusal, not one per unanswered berth (%d)"
			% (int(audit.get("refusals", 0)) - refusals_before))
	_check(not bool(audit.get("request_pending", true)) and audit.get("claim", {}).is_empty(),
		"nothing is left outstanding or half-claimed after the expiry")
	_check(game.phase == phase_before
		and client_player.global_position.distance_to(stood.origin) < 0.5,
		"the player stands exactly where the unanswered key press left them")
	_check(not bool(game.get_network_remote_body_audit().get("intent_source_bound", true))
		and _host_body(GameFlow.network_client_boarding_avatar_id(
			session.multiplayer.get_unique_id())) == null,
		"no body was stood up for a request the ledger never confirmed")
	var abandoned: Dictionary = audit.get("abandoned", {}) as Dictionary
	_check(String(abandoned.get("seat_id", &"")).begins_with("%s_cabin_" % String(SHIP_ID))
		and int(abandoned.get("sequence", -1)) >= 0,
		"the expired request is remembered, so a grant that arrives for it late "
			+ "can be handed back rather than held for ever (%s)"
			% String(abandoned.get("seat_id", &"none")))


# --- F. an expiry is not a life sentence ------------------------------------
#
# An expiry never reaches the ledger. Whatever the ledger decided, this peer
# must still be able to board the next free berth it finds -- the failure this
# guards against is a ledger holding an occupancy the peer has forgotten, which
# turns every later board into the final refusal `avatar_already_occupied`.


func _assert_an_expiry_does_not_lock_the_peer_out() -> void:
	var game := _client_games[1]
	var craft := _client_crafts[1] as HalyardCrewTransport
	var client_player := _client_players[1] as PlayerController
	var berth := GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1)
	_boarding_results.clear()
	_send_filler_boarding(0, StringName(FILLER_ENTITIES[0]), berth, 1,
		BoardingIntent.ACTION_DISEMBARK)
	await _wait_until(func() -> bool: return not _boarding_results.is_empty(), 4.0)
	_check(not _boarding_results.is_empty()
		and _boarding_results[0].get("status") == &"disembarked",
		"a berth is freed again for the peer whose request expired")
	var confirmations_before := _client_confirmations(game)
	await _press_the_hatch(game, client_player, craft)
	var boarded := await _wait_until(
		func() -> bool: return _client_confirmations(game) > confirmations_before, 10.0
	)
	var audit: Dictionary = game.get_network_client_boarding_audit()
	_check(boarded and audit.get("last_status") == &"boarded",
		"the peer whose request expired boards the freed berth (%s)"
			% String(audit.get("last_status", &"none")))
	_check(StringName(audit.get("claimed_seat_id", &"")) == berth
		and game.phase == GameFlow.Phase.IN_FLIGHT_CABIN,
		"it holds the berth it was granted and is presented aboard")
	await _drive_session(6)
	_check(_host_body(GameFlow.network_client_boarding_avatar_id(
			game.get_network_session().multiplayer.get_unique_id())) != null,
		"the host stands a body for the second client too")


# --- G. the ledger clock is live --------------------------------------------


func _assert_the_host_ledger_clock_runs_every_physics_tick() -> void:
	var before: int = _server.get_boarding_server_tick()
	await _drive_session(12)
	var after: int = _server.get_boarding_server_tick()
	_check(after >= before + 12,
		"the host's GameFlow advances the ledger clock every physics tick (%d -> %d)" % [before, after])
	var session = _client_games[1].get_network_session()
	_check(absi(session.get_boarding_server_tick_estimate() - after) <= 12,
		"the client's estimate of that clock tracks it from the frames it runs (%d vs %d)"
			% [session.get_boarding_server_tick_estimate(), after])
	_check(_host.get_network_host_boarding_seat().is_empty(),
		"the host standing on the deck holds no seat in the ledger")


# --- H. a passenger is promoted in place ------------------------------------


func _assert_a_passenger_is_promoted_to_pilot_in_place() -> void:
	var game := _client_games[1]
	var craft := _client_crafts[1] as HalyardCrewTransport
	var client_player := _client_players[1] as PlayerController
	var entity := GameFlow.network_client_boarding_avatar_id(
		game.get_network_session().multiplayer.get_unique_id()
	)
	_check(game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _host_body(entity) != null,
		"the second client stands in the cabin on a berth before walking forward")
	_check(not game._network_client_near_pilot_seat(craft),
		"the cabin stand pose is outside the cockpit's reach, so a fresh berth press is the hatch's")
	# Walk to the cockpit on held input, exactly as a player does. The cabin
	# stand faces aft down the aisle, so the cockpit is behind the player.
	_only_this_player_hears_the_key(client_player)
	client_player.set_control_enabled(true)
	Input.action_press(&"move_back")
	var reached := await _wait_until(
		func() -> bool: return game._network_client_near_pilot_seat(craft), 6.0
	)
	Input.action_release(&"move_back")
	await _drive_session(10)
	_check(reached and game._network_client_near_pilot_seat(craft),
		"the passenger reached the cockpit")
	game._refresh_interaction_targets()
	print("NETWORK_COCKPIT_INTERACTION: ", {
		"phase": game.phase, "busy": game._transition_busy,
		"station": game.station_interaction_candidate.name if is_instance_valid(game.station_interaction_candidate) else &"",
		"near_ship": game._near_ship, "near_pilot": game._network_client_near_pilot_seat(craft),
		"control": client_player.is_control_enabled(),
	})
	_check(not game.station_interaction_candidate is ShipCrewSeat,
		"network cockpit interaction excludes the unavailable solo passenger chair")
	var swaps_before := int(_host.get_network_remote_body_audit().get("hatch_seat_swaps", 0))
	var requests_before := int(game.get_network_client_boarding_audit().get("requests", 0))
	await _press_interact()
	var promoted := await _wait_until(
		func() -> bool: return _client_holds_role(game, &"pilot"), 8.0
	)
	var audit: Dictionary = game.get_network_client_boarding_audit()
	_check(promoted and audit.get("last_status") == &"seat_swapped",
		"one press at the cockpit promotes the passenger through the ledger (%s)"
			% String(audit.get("last_status", &"none")))
	_check(int(audit.get("requests", 0)) == requests_before + 1,
		"the promotion is one request, not a leave and a re-board")
	_check(StringName(audit.get("claimed_seat_id", &"")) == StringName("%s_pilot" % String(SHIP_ID))
		and StringName(audit.get("released_seat_id", &"")) \
			== GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1),
		"the answer named the pilot seat claimed and the berth released")
	await _drive_session(20)
	_check(craft.is_piloted() and game.phase != GameFlow.Phase.IN_FLIGHT_CABIN,
		"the client is presented in the pilot seat through the retake-the-seat seam")
	_check(not bool(game.get_network_remote_body_audit().get("intent_source_bound", true)),
		"the client stopped driving the berth's walking body")
	_check(_host_body(entity) == null
		and int(_host.get_network_remote_body_audit().get("hatch_seat_swaps", 0)) == swaps_before + 1,
		"the host retired the berth's walking body in the same verdict")
	_check(_ledger_holder(StringName("%s_pilot" % String(SHIP_ID))) == entity
		and _ledger_holder(GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1)) == &"",
		"the host's ledger holds the pilot seat for the promoted peer and the berth is free")


# --- I. the host's seat is judged by the same ledger ------------------------


func _assert_the_host_is_refused_a_seat_a_crewmate_holds() -> void:
	var host_player := _host.get_node("Player") as PlayerController
	var phase_before := _host.phase
	# The promotion bound the host's own Halyard to the crewmate's helm.
	_check(_host_craft.get_command_source() is NetworkRemotePilotCommandSource
		and _host_craft.is_piloted(),
		"the host's Halyard now flies from the promoted crewmate's helm")
	var claim: Dictionary = _host._claim_network_host_pilot_seat(_host_craft)
	_check(claim.get("status") == &"seat_occupied",
		"the host's own claim on the seat a crewmate holds is refused (%s)"
			% String(claim.get("status", &"?")))
	_host._board_ship(_host_craft)
	await _drive_session(4)
	_check(_host.phase == phase_before
		and _host_craft.get_command_source() is NetworkRemotePilotCommandSource,
		"the host's boarding press is refused and the crewmate keeps the helm")
	var report: Dictionary = _host.get_boarding_confirmation_presentation_report()
	var view: Dictionary = (report.get("adapter", {}) as Dictionary).get("view", {}) as Dictionary
	# A craft someone is flying is refused before the ledger is asked
	# (`craft_unavailable`); the ledger's `seat_occupied` is the line behind it.
	_check(StringName(view.get("state", &"")) == &"rejected"
		and (String(view.get("message", "")).contains("SEAT OCCUPIED")
			or String(view.get("message", "")).contains("CRAFT UNAVAILABLE")),
		"the host sees the refusal on the existing card (%s)" % String(view.get("message", "")))
	_check(_host.get_network_host_boarding_seat().is_empty() and not host_player.is_seated(),
		"the host holds no seat and is left on foot")


# --- helpers ----------------------------------------------------------------


func _client_holds_role(game: GameFlow, role: StringName) -> bool:
	var claim := game.get_network_client_boarding_audit().get("claim", {}) as Dictionary
	return StringName(claim.get("role", &"")) == role


func _ledger_holder(seat_id: StringName) -> StringName:
	for occupancy_variant in _server.get_boarding_snapshot().get("occupancies", []) as Array:
		var occupancy := occupancy_variant as Dictionary
		if StringName(occupancy.get("seat_id", &"")) == seat_id:
			return StringName(occupancy.get("avatar_id", &""))
	return &""


## The approach half of a real boarding interaction: stand clear first so any
## reboard suppression expires by its own rule, then walk to the hatch. A
## player already standing in a cabin is already at its hatch.
func _walk_to_the_hatch(
	game: GameFlow, client_player: PlayerController, craft: HeroShip
) -> void:
	_only_this_player_hears_the_key(client_player)
	if game.phase != GameFlow.Phase.IN_FLIGHT_CABIN:
		client_player.teleport_to(Transform3D(
			craft.global_basis.orthonormalized(),
			craft.get_boarding_position()
				+ craft.global_basis.y.normalized() * 0.05
				+ craft.global_basis.x.normalized() * 20.0
		))
		await _drive_session(4)
		client_player.teleport_to(Transform3D(
			craft.global_basis.orthonormalized(),
			craft.get_boarding_position() + craft.global_basis.y.normalized() * 0.05
		))
	client_player.set_control_enabled(true)
	await _drive_session(6)


## One ordinary E, held for a single physics tick, exactly as a player's is.
func _press_interact() -> void:
	await _press_live_action(&"interact", 1)
	await _drive_session(2)


func _press_the_hatch(
	game: GameFlow, client_player: PlayerController, craft: HeroShip
) -> void:
	await _walk_to_the_hatch(game, client_player, craft)
	await _press_interact()


## Input is one process-global singleton: a key pressed for one peer is a key
## every other peer's player polls in the same frame. Control is taken off
## everybody else for the press, which is exactly what the production game
## does to a player who may not act right now.
func _only_this_player_hears_the_key(active: PlayerController) -> void:
	var listeners: Array = [_host.get_node_or_null("Player")]
	listeners.append_array(_client_players)
	for listener_variant in listeners:
		var listener := listener_variant as PlayerController
		if is_instance_valid(listener) and listener != active:
			listener.set_control_enabled(false)


## Small named predicates, because a `_wait_until` argument has to stay a
## one-line lambda for the parser to see where the argument list ends.
func _client_confirmations(game: GameFlow) -> int:
	return int(game.get_network_client_boarding_audit().get("confirmations", 0))


func _client_refusals(game: GameFlow) -> int:
	return int(game.get_network_client_boarding_audit().get("refusals", 0))


func _client_timeouts(game: GameFlow) -> int:
	return int(game.get_network_client_boarding_audit().get("timeouts", 0))


func _client_holds_a_berth(game: GameFlow) -> bool:
	return not (game.get_network_client_boarding_audit().get("claim", {}) as Dictionary).is_empty()


func _client_is_unberthed(game: GameFlow) -> bool:
	return not _client_holds_a_berth(game) and game.phase != GameFlow.Phase.IN_FLIGHT_CABIN


func _drive_session(rounds: int) -> void:
	for _round in maxi(1, rounds):
		await physics_frame
		await process_frame


func _host_body(entity_id: StringName) -> PlayerController:
	var simulation = _host.get_network_remote_body_simulation()
	if simulation == null or not is_instance_valid(simulation):
		return null
	return simulation.get_body(entity_id) as PlayerController


func _send_filler_boarding(
	index: int, avatar_id: StringName, seat_id: StringName, sequence: int, action: StringName
) -> void:
	var intent = BoardingIntent.create(
		_filler_peer_ids[index], avatar_id, SHIP_ID, 1, FRAME_ID, 1,
		seat_id, 1, GameFlow.NETWORK_CABIN_BERTH_ROLE, sequence,
		_fillers[index].get_boarding_server_tick_estimate(), action
	)
	_fillers[index].send_boarding_intent(intent.to_dictionary())


func _on_host_boarding_result(result: Dictionary) -> void:
	_boarding_results.append(result.duplicate(true))


func _finish_client_boarding() -> void:
	for action in FLIGHT_CONTROL_ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	if is_instance_valid(_host):
		_host.shutdown_network_session(&"suite_complete")
	for game in _client_games:
		if is_instance_valid(game):
			game.shutdown_network_session(&"suite_complete")
	for adapter in _fillers:
		if is_instance_valid(adapter):
			adapter.shutdown(&"suite_complete")
	await process_frame
	if _failures.is_empty():
		print("NETWORK_CLIENT_BOARDING_SEAM_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_CLIENT_BOARDING_SEAM_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, ", ".join(_failures)])
	quit(1)
