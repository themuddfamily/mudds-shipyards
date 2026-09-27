extends "res://tests/in_flight_cabin_integration_test.gd"

## A remote pilot flies the host's craft, over a real loopback ENet session.
##
## Before this, a peer the boarding ledger seated in a pilot seat flew a
## private copy of the craft on its own machine while the host's copy -- the
## one every other crew member stands in -- stayed parked: movement for piloted
## craft was client-authoritative. Here the host is the whole production `Main`
## subtree, and one bare client adapter claims the Halyard's pilot seat through
## the ledger and streams its helm on the one movement RPC.
##
## What is asserted:
##   A. a ledger pilot grant binds the host's craft to the peer's validated
##      helm through `HeroShip.set_command_source()`, without taking the host's
##      own camera;
##   B. the peer's throttle reaches the host's ship simulation and the host's
##      craft moves;
##   C. a peer that does not hold the seat cannot steer it (refused by name);
##   D. a helm that goes silent falls to neutral;
##   D2. a helm stream the pilot restarts at sequence zero (it left the seat
##      locally and sat back down, with no ledger event) is accepted as a new,
##      higher stream, while a restart on the old stream id is still refused;
##   E. the ledger disembark, a peer disconnect and a session stop each hand the
##      craft back to its own local input, unpiloted.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")
const RemotePilotSource := preload("res://scripts/network/network_remote_pilot_command_source.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const FRAME_ID: StringName = &"frame_halyard_new_design"
const PILOT_SEAT: StringName = &"halyard_new_design_pilot"
const PILOT_AVATAR: StringName = &"remote_pilot"
## Metres the host's craft must cover under the remote throttle before the
## suite believes the helm flew it rather than the berth settling it.
const MIN_REMOTE_FLIGHT := 1.0

var _host: GameFlow = null
var _craft: HalyardCrewTransport = null
var _server = null
var _pilot: Adapter = null
var _stranger: Adapter = null
var _boarding_sequence := -1
var _helm_sequence := 0
var _helm_stamp := -1
var _movement_results: Array = []
var _boarding_results: Array = []


func _run() -> void:
	if await _build():
		await _assert_a_pilot_grant_binds_the_helm()
		await _assert_the_remote_throttle_flies_the_host_craft()
		await _assert_a_stranger_cannot_steer()
		await _assert_a_silent_helm_falls_neutral()
		await _assert_a_restarted_helm_stream_is_accepted()
		await _assert_every_release_hands_the_craft_back()
	await _finish_remote_helm()


func _build() -> bool:
	Engine.max_physics_steps_per_frame = 1
	_host = MAIN_SCENE.instantiate() as GameFlow
	if _host == null:
		_check(false, "the production scene instantiates as the session host")
		return false
	_host.name = "HelmHostMain"
	root.add_child(_host)
	await process_frame
	await physics_frame
	_host.start_shift()
	await process_frame
	await physics_frame
	_craft = _host.get_node_or_null("HalyardCrewTransport") as HalyardCrewTransport
	_check(_craft != null and _craft.get_ship_id() == SHIP_ID,
		"the host's subtree supplies the Halyard a remote pilot will fly")
	if _craft == null:
		return false
	set_multiplayer(SceneMultiplayer.new(), _host.get_path())
	var adapters: Array = []
	for index in 2:
		var branch := SubViewport.new()
		branch.name = "HelmPeer%d" % index
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		var adapter := Adapter.new()
		adapter.name = GameFlow.NETWORK_SESSION_NODE_NAME
		branch.add_child(adapter)
		adapters.append(adapter)
	_pilot = adapters[0]
	_stranger = adapters[1]
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback port")
		return false
	var port := probe.get_local_port()
	probe.stop()
	_check(bool(_host.host_network_session(port, 4).get("accepted", false)),
		"the host GameFlow opens the authoritative session")
	_server = _host.get_network_session()
	if _server == null:
		return false
	_server.movement_intent_result.connect(func(result: Dictionary) -> void:
		_movement_results.append(result.duplicate(true)))
	_server.boarding_intent_result.connect(func(result: Dictionary) -> void:
		_boarding_results.append(result.duplicate(true)))
	_pilot.join("127.0.0.1", port)
	_stranger.join("127.0.0.1", port)
	var offered := await _wait_until(
		func() -> bool: return not _pilot.get_server_offer().is_empty() and not _stranger.get_server_offer().is_empty(), 10.0
	)
	_check(offered, "both peers are admitted and hold the host's offer")
	return offered


# --- A ------------------------------------------------------------------------


func _assert_a_pilot_grant_binds_the_helm() -> void:
	_assert_the_host_keeps_its_seat_while_climbing_out()
	var host_camera := _host.get_viewport().get_camera_3d()
	var granted := await _board(BoardingIntent.ACTION_BOARD)
	_check(granted.get("status") == &"boarded",
		"the ledger seats the remote peer in the Halyard's pilot seat (%s)"
			% String(granted.get("status", &"none")))
	await _drive(2)
	_check(_craft.get_command_source() is RemotePilotSource and _craft.is_piloted(),
		"the host's craft now flies from the peer's helm, through its own command-source seam")
	_check(int(_host.get_network_remote_body_audit().get("remote_pilot_binds", 0)) == 1,
		"exactly one helm binding was made")
	_check(_host.get_viewport().get_camera_3d() == host_camera,
		"binding the helm did not take the host's own camera")


## The host's ledger seat lasts exactly as long as the window in which
## `_bind_network_remote_pilot()` refuses its craft (`_piloting`): mid-disembark
## (seat already `set_piloted(false)`) it is still the host's, so a peer is
## refused `seat_occupied` rather than granted a helm that is never bound.
## A synchronous probe of the reconciler's input; nothing is awaited.
func _assert_the_host_keeps_its_seat_while_climbing_out() -> void:
	var ship: HeroShip = _host.active_ship
	if not is_instance_valid(ship):
		_check(false, "the host has an active craft to probe its seat with")
		return
	var saved_phase = _host.phase
	var saved_piloting: bool = _host._piloting
	_host._piloting = true
	_host.phase = GameFlow.Phase.DISEMBARKING
	var held_mid_exit: bool = _host._network_host_desired_pilot_ship() == ship
	_host._piloting = false
	var released_on_foot: bool = _host._network_host_desired_pilot_ship() == null
	_host._piloting = saved_piloting
	_host.phase = saved_phase
	_check(held_mid_exit, "the host holds its seat while it is still climbing out of it")
	_check(released_on_foot, "the host's seat is released once it is on foot")


# --- B ------------------------------------------------------------------------


func _assert_the_remote_throttle_flies_the_host_craft() -> void:
	var origin := _craft.global_position
	var full := ShipCommand.from_dictionary({
		"schema_version": ShipCommand.SCHEMA_VERSION, "sequence": 0, "timestamp_usec": 0,
		"stream_id": 0, "throttle": 1.0,
	})
	var saw_throttle := false
	for frame in 180:
		if frame % RemotePilotSource.SEND_INTERVAL_TICKS == 0:
			_send_helm(_pilot, full)
		await physics_frame
		await process_frame
		var consumed := _craft.get_last_ship_command()
		if consumed != null and consumed.throttle > 0.5:
			saw_throttle = true
	var audit: Dictionary = _host.get_network_remote_pilot_audit()
	var pilots: Array = audit.get("pilots", [])
	_check(not pilots.is_empty() and int((pilots[0] as Dictionary).get("delivered", 0)) > 10,
		"the host delivered the peer's validated helm commands (%s)" % str(pilots))
	_check(saw_throttle, "the peer's throttle is the command the host's ship simulation consumed")
	var flown := _craft.global_position.distance_to(origin)
	_check(flown >= MIN_REMOTE_FLIGHT,
		"the host's own Halyard moved under the remote helm (%.2f m)" % flown)


# --- C ------------------------------------------------------------------------


func _assert_a_stranger_cannot_steer() -> void:
	_movement_results.clear()
	var hijack := RemotePilotSource.build_helm_intent(
		_stranger.multiplayer.get_unique_id(), SHIP_ID, 1, 0,
		_stranger.get_boarding_server_tick_estimate(), null
	)
	_stranger.send_movement_intent(hijack)
	await _wait_until(func() -> bool: return not _movement_results.is_empty(), 4.0)
	_check(not _movement_results.is_empty()
		and _movement_results[0].get("status") == &"pilot_owner_mismatch",
		"a peer that does not hold the seat is refused by name (%s)"
			% String(_movement_results[0].get("status", &"none") if not _movement_results.is_empty() else &"none"))


# --- D ------------------------------------------------------------------------


func _assert_a_silent_helm_falls_neutral() -> void:
	await _drive(RemotePilotSource.HOLD_TICKS + 10)
	var consumed := _craft.get_last_ship_command()
	var pilots: Array = _host.get_network_remote_pilot_audit().get("pilots", [])
	_check(consumed != null and is_zero_approx(consumed.throttle)
		and not pilots.is_empty() and not bool((pilots[0] as Dictionary).get("holding", true)),
		"a helm silent for longer than the hold falls to neutral, not full throttle")


# --- D2 -----------------------------------------------------------------------


func _assert_a_restarted_helm_stream_is_accepted() -> void:
	var peer_id := _pilot.multiplayer.get_unique_id()
	_movement_results.clear()
	_helm_stamp = maxi(_pilot.get_boarding_server_tick_estimate(), _helm_stamp + 1)
	_pilot.send_movement_intent(RemotePilotSource.build_helm_intent(
		peer_id, SHIP_ID, 1, 0, _helm_stamp, null, 0
	))
	await _wait_until(func() -> bool: return not _movement_results.is_empty(), 4.0)
	_check(not _movement_results.is_empty()
		and _movement_results[0].get("status") == &"stale_sequence",
		"a restart at sequence zero on the old stream id is still refused as stale")
	_movement_results.clear()
	_helm_stamp += 1
	_pilot.send_movement_intent(RemotePilotSource.build_helm_intent(
		peer_id, SHIP_ID, 1, 0, _helm_stamp, null, 1
	))
	await _wait_until(func() -> bool: return not _movement_results.is_empty(), 4.0)
	_check(not _movement_results.is_empty() and bool(_movement_results[0].get("accepted", false)),
		"a restarted helm stream on a higher stream id is accepted from sequence zero (%s)"
			% String(_movement_results[0].get("status", &"none") if not _movement_results.is_empty() else &"none"))


# --- E ------------------------------------------------------------------------


func _assert_every_release_hands_the_craft_back() -> void:
	var left := await _board(BoardingIntent.ACTION_DISEMBARK)
	_check(left.get("status") == &"disembarked", "the remote pilot leaves the seat through the ledger")
	await _drive(2)
	_check(_craft.get_command_source() == _craft.get_local_input_source() and not _craft.is_piloted(),
		"the ledger disembark hands the craft back to its own input, unpiloted")
	_check(int(_server.get_remote_ship_command_snapshot().get("pilot_count", -1)) == 0,
		"the helm registration went with the seat")
	var again := await _board(BoardingIntent.ACTION_BOARD)
	await _drive(2)
	_check(again.get("status") == &"boarded" and _craft.get_command_source() is RemotePilotSource,
		"the seat can be taken again and binds a fresh helm")
	_pilot.shutdown(&"pilot_dropped")
	var dropped := await _wait_until(
		func() -> bool: return not (_craft.get_command_source() is RemotePilotSource), 12.0
	)
	_check(dropped and not _craft.is_piloted(),
		"a pilot's disconnect hands the craft back to its own input, unpiloted")
	_check(_host.get_network_host_boarding_seat().is_empty()
		and (_server.get_boarding_snapshot().get("occupancies", []) as Array).is_empty(),
		"the ledger holds nothing for the dropped pilot")


# --- helpers ------------------------------------------------------------------


func _board(action: StringName) -> Dictionary:
	_boarding_results.clear()
	_boarding_sequence += 1
	var intent = BoardingIntent.create(
		_pilot.multiplayer.get_unique_id(), PILOT_AVATAR, SHIP_ID, 1, FRAME_ID, 1,
		PILOT_SEAT, 1, &"pilot", _boarding_sequence,
		_pilot.get_boarding_server_tick_estimate(), action
	)
	_pilot.send_boarding_intent(intent.to_dictionary())
	await _wait_until(func() -> bool: return not _boarding_results.is_empty(), 4.0)
	return {} if _boarding_results.is_empty() else _boarding_results[0] as Dictionary


func _send_helm(adapter: Adapter, command: ShipCommand) -> void:
	_helm_stamp = maxi(adapter.get_boarding_server_tick_estimate(), _helm_stamp + 1)
	adapter.send_movement_intent(RemotePilotSource.build_helm_intent(
		adapter.multiplayer.get_unique_id(), SHIP_ID, 1, _helm_sequence, _helm_stamp, command
	))
	_helm_sequence += 1


func _drive(rounds: int) -> void:
	for _round in maxi(1, rounds):
		await physics_frame
		await process_frame


func _finish_remote_helm() -> void:
	if is_instance_valid(_host):
		_host.shutdown_network_session(&"suite_complete")
		await process_frame
		_check(not (_craft.get_command_source() is RemotePilotSource),
			"a session stop leaves no remote helm bound")
	for adapter in [_pilot, _stranger]:
		if is_instance_valid(adapter):
			adapter.shutdown(&"suite_complete")
	await process_frame
	if _failures.is_empty():
		print("NETWORK_REMOTE_PILOT_HELM_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_REMOTE_PILOT_HELM_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, ", ".join(_failures)])
	quit(1)
