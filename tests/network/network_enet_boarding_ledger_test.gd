extends SceneTree

## The boarding ledger's four closing gaps, over a real loopback ENet session
## between bare production adapters (one host, two clients):
##
##   1. the tick handshake is live: the authority advances its clock, a
##      regressed tick is refused by name, a client hears the clock in the
##      admission offer, stale and future stamps are refused by name, and a
##      regressed answer tick is refused on the client;
##   2. `board_any` answers with the concrete assigned berth, or one
##      `craft_full`, in a single round trip;
##   3. an atomic seat swap releases the berth and claims the pilot seat in one
##      ledger transaction, answered over the existing boarding answer RPC with
##      the one added `released_seat_id` field, and a refused swap leaves the
##      berth held;
##   4. the host's own seat is an occupancy in the same ledger: remote claims on
##      it are refused, it releases cleanly, and a session stop empties it.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")

const SHIP_ID: StringName = &"ship-1"
const FRAME_ID: StringName = &"frame-1"
const PILOT_SEAT: StringName = &"ship-1-pilot"
const BERTH_ONE: StringName = &"ship-1-berth-1"
const BERTH_TWO: StringName = &"ship-1-berth-2"
const HOST_AVATAR: StringName = &"peer_1_crew"
const OFFER_TICK := 500

var _failures: Array[String] = []
var _assertions := 0
var _server: Adapter
var _clients: Array = []
var _admissions := 0
var _server_results: Array[Dictionary] = []
var _client_answers: Array = [[], []]
var _sequences := {}
var _authority_tick := 0


func _initialize() -> void:
	await _build()
	if _failures.is_empty():
		await _assert_tick_handshake()
		await _assert_board_any_is_one_round_trip()
		await _assert_atomic_seat_swap()
		await _assert_host_seat_is_a_ledger_occupancy()
		_assert_session_stop_empties_the_ledger()
	for client in _clients:
		client.shutdown(&"suite_complete")
	if is_instance_valid(_server):
		_server.shutdown(&"suite_complete")
	await process_frame
	if _failures.is_empty():
		print("NETWORK_ENET_BOARDING_LEDGER_TEST_OK: %d assertions" % _assertions)
	else:
		printerr("NETWORK_ENET_BOARDING_LEDGER_TEST_FAILED: %d/%d: %s"
			% [_failures.size(), _assertions, ", ".join(_failures)])
	quit(0 if _failures.is_empty() else 1)


func _build() -> void:
	var branches: Array = []
	for index in 3:
		var branch := SubViewport.new()
		branch.name = "BoardingLedgerBranch%d" % index
		root.add_child(branch)
		branches.append(branch)
	await process_frame
	for index in 3:
		set_multiplayer(SceneMultiplayer.new(), (branches[index] as Node).get_path())
		var adapter := Adapter.new()
		adapter.name = "NetworkSession"
		(branches[index] as Node).add_child(adapter)
		if index == 0:
			_server = adapter
		else:
			_clients.append(adapter)
	await process_frame
	_server.peer_admitted.connect(func(_peer_id: int, _receipt: Dictionary) -> void:
		_admissions += 1)
	_server.boarding_intent_result.connect(func(result: Dictionary) -> void:
		_server_results.append(result.duplicate(true)))
	for index in _clients.size():
		var bucket: Array = _client_answers[index]
		(_clients[index] as Adapter).boarding_intent_result.connect(
			func(result: Dictionary) -> void: bucket.append(result.duplicate(true)))
	var port := _reserve_udp_port()
	_check(bool(_server.host(port, 4).get("accepted", false)), "the host binds a loopback port")
	# Ledger layout and clock before anyone joins, so the offer carries a
	# non-zero tick.
	_check(bool(_server.register_boarding_ship(SHIP_ID, 1, FRAME_ID, 1).get("accepted", false))
		and bool(_server.register_boarding_seat(PILOT_SEAT, SHIP_ID, 1, &"pilot").get("accepted", false))
		and bool(_server.register_boarding_seat(BERTH_ONE, SHIP_ID, 1, &"passenger").get("accepted", false))
		and bool(_server.register_boarding_seat(BERTH_TWO, SHIP_ID, 1, &"passenger").get("accepted", false)),
		"the host registers one craft with a pilot seat and two berths")
	_check(bool(_server.advance_boarding_server_tick(OFFER_TICK).get("accepted", false)),
		"the authority advances its ledger clock")
	# From here the clock runs the way GameFlow runs it on a host: one tick per
	# physics tick.
	_authority_tick = OFFER_TICK
	physics_frame.connect(_advance_authority_clock)
	for client in _clients:
		(client as Adapter).join("127.0.0.1", port)
	await _pump_until(func() -> bool: return _admissions >= 2 and _clients_hold_offer(), 6.0)
	_check(_admissions >= 2 and _clients_hold_offer(), "both clients are admitted and hold the offer")


# --- 1. the tick handshake ----------------------------------------------------


func _assert_tick_handshake() -> void:
	var clock_before := _server.get_boarding_server_tick()
	var regressed: Dictionary = _server.advance_boarding_server_tick(clock_before - 1)
	_check(not bool(regressed.get("accepted", true))
		and regressed.get("status") == &"stale_server_tick",
		"a regressed authority tick is refused by name (%s)" % String(regressed.get("status", &"?")))
	_check(_server.get_boarding_server_tick() == clock_before,
		"a refused regression leaves the ledger clock where it was")
	var client := _clients[0] as Adapter
	_check(client.get_boarding_server_tick_estimate() >= OFFER_TICK,
		"the client heard the ledger clock in the admission offer (%d)"
			% client.get_boarding_server_tick_estimate())
	# A stale stamp: the request was made long before a gap the requester
	# never saw.
	var too_old := await _ask(0, &"stale-probe", BERTH_ONE, &"passenger",
		BoardingIntent.ACTION_BOARD,
		_server.get_boarding_server_tick() - Adapter.BOARDING_MAX_TICK_BEHIND - 50)
	_check(too_old.get("status") == &"client_tick_too_old",
		"a stamp older than the window is refused by name (%s)" % String(too_old.get("status", &"?")))
	_check(int(too_old.get("server_tick", -1)) >= OFFER_TICK,
		"the refusal carries the authority's current tick back to the requester")
	var too_new := await _ask(0, &"stale-probe", BERTH_ONE, &"passenger",
		BoardingIntent.ACTION_BOARD,
		_server.get_boarding_server_tick() + Adapter.BOARDING_MAX_TICK_AHEAD + 50)
	_check(too_new.get("status") == &"client_tick_too_far_ahead",
		"a stamp from a future the host never reached is refused by name (%s)"
			% String(too_new.get("status", &"?")))
	# Let the clock run for half a second: the client's estimate has to keep
	# up with it from the physics frames it runs, not from new answers.
	for _frame in 30:
		await physics_frame
	var in_window := await _ask(0, &"stale-probe", BERTH_ONE, &"passenger",
		BoardingIntent.ACTION_BOARD, client.get_boarding_server_tick_estimate())
	_check(bool(in_window.get("accepted", false)),
		"a request stamped with the client's estimate lands inside the window (%s)"
			% String(in_window.get("status", &"?")))
	await _ask(0, &"stale-probe", BERTH_ONE, &"passenger",
		BoardingIntent.ACTION_DISEMBARK, client.get_boarding_server_tick_estimate())
	# A regressed answer tick is refused on the client too, whatever its revision.
	var replica: Dictionary = client.get_boarding_intent_result_replica()
	var forged := client.consume_boarding_intent_result({
		"revision": int(replica.get("revision", 0)) + 1,
		"migration_generation": int(replica.get("migration_generation", 1)),
		"server_tick": int(replica.get("server_tick", 0)) - 10,
		"result": {"accepted": true, "status": &"boarded", "sequence": 999},
	})
	_check(forged.get("status") == &"stale_server_tick",
		"an answer stamped behind the tick already heard is refused by name (%s)"
			% String(forged.get("status", &"?")))


# --- 2. one round trip --------------------------------------------------------


func _assert_board_any_is_one_round_trip() -> void:
	var first := await _ask(0, &"crew-a", BERTH_ONE, &"passenger", BoardingIntent.ACTION_BOARD_ANY)
	_check(bool(first.get("accepted", false)) and StringName(first.get("seat_id", &"")) == BERTH_ONE,
		"a free preferred berth is granted as asked (%s)" % String(first.get("seat_id", &"?")))
	var answers_before := (_client_answers[1] as Array).size()
	var second := await _ask(1, &"crew-b", BERTH_ONE, &"passenger", BoardingIntent.ACTION_BOARD_ANY)
	_check(bool(second.get("accepted", false)) and StringName(second.get("seat_id", &"")) == BERTH_TWO,
		"a held preferred berth is answered with the concrete berth assigned (%s)"
			% String(second.get("seat_id", &"?")))
	var full := await _ask(1, &"crew-b2", BERTH_ONE, &"passenger", BoardingIntent.ACTION_BOARD_ANY)
	_check(not bool(full.get("accepted", true)) and full.get("status") == &"craft_full",
		"a full craft is one craft_full verdict (%s)" % String(full.get("status", &"?")))
	_check((_client_answers[1] as Array).size() == answers_before + 2,
		"each board_any cost exactly one answer -- two asks, two answers")
	var exact := await _ask(1, &"crew-b3", BERTH_ONE, &"passenger", BoardingIntent.ACTION_BOARD)
	_check(exact.get("status") == &"seat_occupied",
		"the exact board keeps its seat_occupied contract (%s)" % String(exact.get("status", &"?")))


# --- 3. the atomic swap -------------------------------------------------------


func _assert_atomic_seat_swap() -> void:
	var events_before := int(_server.get_boarding_snapshot().get("event_sequence", 0))
	var swapped := await _ask(0, &"crew-a", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_SWAP)
	_check(bool(swapped.get("accepted", false)) and swapped.get("status") == &"seat_swapped",
		"a berth holder is promoted to the pilot seat (%s)" % String(swapped.get("status", &"?")))
	_check(StringName(swapped.get("seat_id", &"")) == PILOT_SEAT
		and StringName(swapped.get("released_seat_id", &"")) == BERTH_ONE
		and StringName(swapped.get("role", &"")) == &"pilot",
		"the answer names the claimed seat, the released berth and the new role")
	var snapshot: Dictionary = _server.get_boarding_snapshot()
	_check(int(snapshot.get("event_sequence", 0)) == events_before + 1,
		"release and claim were one ledger transaction")
	_check(_seat_holder(PILOT_SEAT) == &"crew-a" and _seat_holder(BERTH_ONE) == &"",
		"the ledger holds the pilot seat for the promoted avatar and the berth is free")
	_check(not _server_results.is_empty()
		and _server_results[-1].get("released_occupancy") is Dictionary,
		"the authority's own verdict carries the released occupancy for the host seam")
	var refused := await _ask(1, &"crew-b", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_SWAP)
	_check(refused.get("status") == &"seat_occupied" and _seat_holder(BERTH_TWO) == &"crew-b",
		"a refused swap leaves the passenger holding its berth (%s)" % String(refused.get("status", &"?")))
	var stranger := await _ask(1, &"crew-b9", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_SWAP)
	_check(stranger.get("status") == &"occupancy_not_found",
		"an avatar holding nothing has nothing to swap from")
	await _ask(0, &"crew-a", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_DISEMBARK)
	_check(_seat_holder(PILOT_SEAT) == &"", "the promoted pilot leaves the seat through the ledger")


# --- 4. the host's own seat ---------------------------------------------------


func _assert_host_seat_is_a_ledger_occupancy() -> void:
	var seated: Dictionary = _server.claim_host_boarding_seat(HOST_AVATAR, PILOT_SEAT)
	_check(bool(seated.get("accepted", false)) and seated.get("status") == &"authority_seated",
		"the host's own pilot seat is written into the ledger (%s)" % String(seated.get("status", &"?")))
	_check(_seat_holder(PILOT_SEAT) == HOST_AVATAR, "the ledger shows the host seated")
	var remote_swap := await _ask(1, &"crew-b", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_SWAP)
	_check(remote_swap.get("status") == &"seat_occupied",
		"a remote swap into the host's seat is refused (%s)" % String(remote_swap.get("status", &"?")))
	var remote_board := await _ask(0, &"crew-a", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_BOARD)
	_check(remote_board.get("status") == &"seat_occupied",
		"a remote claim on the host's seat is refused (%s)" % String(remote_board.get("status", &"?")))
	_check(bool(_server.claim_host_boarding_seat(HOST_AVATAR, PILOT_SEAT).get("accepted", false)),
		"re-asserting the seat the host already holds is idempotent")
	var berth_holder: Dictionary = _server.claim_host_boarding_seat(HOST_AVATAR, BERTH_TWO)
	_check(berth_holder.get("status") == &"seat_occupied" and _seat_holder(PILOT_SEAT) == HOST_AVATAR,
		"the host is refused a seat a peer holds and keeps the one it had")
	_check(_clients[0].claim_host_boarding_seat(HOST_AVATAR, BERTH_ONE).get("status")
			== &"authority_required",
		"a client adapter cannot write a host seat")
	var released: Dictionary = _server.release_host_boarding_seat(HOST_AVATAR)
	_check(released.get("status") == &"authority_released" and _seat_holder(PILOT_SEAT) == &"",
		"the host's disembark releases its ledger seat")
	var promoted := await _ask(1, &"crew-b", PILOT_SEAT, &"pilot", BoardingIntent.ACTION_SWAP)
	_check(promoted.get("status") == &"seat_swapped",
		"the released seat is free for a passenger's promotion (%s)" % String(promoted.get("status", &"?")))
	_check(_server.claim_host_boarding_seat(HOST_AVATAR, PILOT_SEAT).get("status") == &"seat_occupied",
		"and the host cannot then take it back from under the crewmate flying it")


func _assert_session_stop_empties_the_ledger() -> void:
	_server.claim_host_boarding_seat(HOST_AVATAR, BERTH_ONE)
	_server.shutdown(&"suite_stop")
	var snapshot: Dictionary = _server.get_boarding_snapshot()
	_check((snapshot.get("occupancies", []) as Array).is_empty(),
		"a session stop releases every occupancy, the host's own included")
	_check(int(snapshot.get("server_tick", -1)) == 0,
		"a session stop rewinds the ledger clock for the next host")


# --- helpers ------------------------------------------------------------------


func _advance_authority_clock() -> void:
	if not is_instance_valid(_server) or not _server.is_server():
		return
	_authority_tick += 1
	_server.advance_boarding_server_tick(_authority_tick)


## One request from client `index`, answered over the production boarding
## answer RPC. Returns the client's applied answer, or {} on timeout.
func _ask(
	index: int, avatar_id: StringName, seat_id: StringName, role: StringName,
	action: StringName, client_tick: int = -1
) -> Dictionary:
	var client := _clients[index] as Adapter
	var peer_id := client.multiplayer.get_unique_id()
	var key := "%d:%s" % [peer_id, avatar_id]
	var sequence := int(_sequences.get(key, -1)) + 1
	_sequences[key] = sequence
	var stamp := client_tick if client_tick >= 0 else client.get_boarding_server_tick_estimate()
	var intent = BoardingIntent.create(
		peer_id, avatar_id, SHIP_ID, 1, FRAME_ID, 1, seat_id, 1, role, sequence, stamp, action
	)
	_check(intent.is_valid(), "the %s intent is a valid wire packet" % String(action))
	var bucket: Array = _client_answers[index]
	var before := bucket.size()
	client.send_boarding_intent(intent.to_dictionary())
	await _pump_until(func() -> bool: return bucket.size() > before, 3.0)
	if bucket.size() <= before:
		_check(false, "the host answered the %s request" % String(action))
		return {}
	return bucket[-1] as Dictionary


func _seat_holder(seat_id: StringName) -> StringName:
	for occupancy_variant in _server.get_boarding_snapshot().get("occupancies", []) as Array:
		var occupancy := occupancy_variant as Dictionary
		if StringName(occupancy.get("seat_id", &"")) == seat_id:
			return StringName(occupancy.get("avatar_id", &""))
	return &""


func _clients_hold_offer() -> bool:
	for client in _clients:
		if (client as Adapter).get_server_offer().is_empty():
			return false
	return true


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
	_check(status == OK, "the suite reserves a local UDP port")
	var port := probe.get_local_port()
	probe.stop()
	return port
