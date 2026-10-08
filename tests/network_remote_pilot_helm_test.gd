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

## Records attempted device delivery even though production remote sources
## deliberately do not implement these local-input hooks.
class InputProbeSource extends NetworkRemotePilotCommandSource:
	var look_motion := Vector2.ZERO
	var camera_steps := 0.0

	func queue_look_motion(relative: Vector2) -> void:
		look_motion += relative

	func queue_camera_distance_delta(steps: float) -> void:
		camera_steps += steps


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
var _roll_directory := ""
var _roll_port := 0
var _roll_child_pid := -1
var _package_under_test := ""
var _roll_edges := 0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var package_index := args.find("--package-under-test")
	if package_index >= 0 and package_index + 1 < args.size():
		_package_under_test = args[package_index + 1]
		args.remove_at(package_index + 1)
		args.remove_at(package_index)
	if not _package_under_test.is_empty():
		_check(FileAccess.file_exists("res://project.binary"), "helm process loads the requested package")
	if args.size() == 3 and args[0] == "roll-peer":
		_roll_port = int(args[1])
		_roll_directory = args[2]
		await _run_roll_peer()
		return
	_roll_directory = OS.get_user_data_dir().path_join("helm-roll-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_roll_directory)
	if await _build():
		await _assert_a_pilot_grant_binds_the_helm()
		await _assert_the_remote_throttle_flies_the_host_craft()
		await _assert_a_stranger_cannot_steer()
		await _assert_a_silent_helm_falls_neutral()
		await _assert_a_restarted_helm_stream_is_accepted()
		await _assert_every_release_hands_the_craft_back()
		await _assert_independent_roll_press()
	await _finish_remote_helm()


func _build() -> bool:
	Engine.max_physics_steps_per_frame = 1
	_host = MAIN_SCENE.instantiate() as GameFlow
	if _host == null:
		_check(false, "the production scene instantiates as the session host")
		return false
	_host.name = "HelmHostMain"
	_check(_host.configure_runtime_settings_persistence(UserDataStore.new(_roll_directory + "/host-save.json"),
		_roll_directory + "/host-legacy.cfg"), "host uses private saves")
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
	# Reproduce the retained active_ship pointer after the host disembarks.
	_host.active_ship = _craft
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
	_roll_port = port
	_host._ensure_lan_discovery().discovery_port = 0
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
	_assert_a_remote_helm_cannot_replace_a_local_pilot()
	var host_camera := _host.get_viewport().get_camera_3d()
	var host_mouse_mode := Input.mouse_mode
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
	_check(_craft.is_remote_piloted(),
		"the helm binding is the remote flight mode, which leaves the host's mouse and input alone")
	_check(Input.mouse_mode == host_mouse_mode, "binding the helm preserves the host's mouse mode")
	_assert_remote_mode_ignores_host_input()


func _assert_a_remote_helm_cannot_replace_a_local_pilot() -> void:
	var host_camera := _host.get_viewport().get_camera_3d()
	var host_mouse_mode := Input.mouse_mode
	_craft.set_piloted(true)
	var source := _craft.get_command_source()
	var local_sample := _host._capture_cinder_actor_sample()
	var local_streaming := _host.cinder_streaming_binding._sample_production_actor_position()
	_check(not _host._piloting and _host._get_debug_actor() == _craft
		and local_sample.get("actor_instance_id") == _craft.get_instance_id()
		and local_streaming.get("actor_instance_id") == _craft.get_instance_id(),
		"local set_piloted still selects the craft without GameFlow's sortie latch")
	_craft.set_remote_piloted(true)
	_check(_craft.is_piloted() and not _craft.is_remote_piloted()
		and _craft.get_command_source() == source and _craft.get_camera().current,
		"a remote mode request cannot downgrade a local pilot or camera")
	_craft.set_remote_piloted(false)
	_check(_craft.is_piloted(), "releasing remote mode cannot unseat a local pilot")
	_craft.set_piloted(false)
	if is_instance_valid(host_camera):
		host_camera.make_current()
	Input.mouse_mode = host_mouse_mode


func _assert_remote_mode_ignores_host_input() -> void:
	var source := _craft.get_command_source()
	var probe := InputProbeSource.new()
	_craft.add_child(probe)
	_craft.set_command_source(probe)
	var host_mouse_mode := Input.mouse_mode
	var distance := _craft.get_chase_camera_distance()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_craft._unhandled_input(wheel)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_craft._unhandled_input(click)
	_check(Input.mouse_mode == host_mouse_mode, "a remote craft leaves the host's click alone")
	var pause := InputEventAction.new()
	pause.action = &"pause"
	pause.pressed = true
	_craft._unhandled_input(pause)
	_check(Input.mouse_mode == host_mouse_mode, "a remote craft leaves the host's pause alone")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40.0, -20.0)
	_craft._unhandled_input(motion)
	_craft.apply_look_motion(motion.relative)
	_check(is_equal_approx(distance, _craft.get_chase_camera_distance())
		and is_zero_approx(probe.camera_steps), "remote mode neither zooms nor queues the host's wheel")
	_check(probe.look_motion == Vector2.ZERO, "remote mode queues no host look motion")
	Input.mouse_mode = host_mouse_mode
	_craft.set_command_source(source)
	probe.free()


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
	_host.phase = GameFlow.Phase.IN_FLIGHT_CABIN
	var held_entering_cabin: bool = _host._network_host_desired_pilot_ship() == ship
	_host._piloting = false
	var released_on_foot: bool = _host._network_host_desired_pilot_ship() == null
	_host._piloting = saved_piloting
	_host.phase = saved_phase
	_check(held_mid_exit, "the host holds its seat while it is still climbing out of it")
	_check(held_entering_cabin, "the host holds its seat during the leave-into-cabin transition")
	_check(released_on_foot, "the host's seat is released once it is on foot")


# --- B ------------------------------------------------------------------------


func _assert_the_remote_throttle_flies_the_host_craft() -> void:
	_assert_the_host_observes_its_own_body("while the peer holds the helm")
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
	_assert_the_host_observes_its_own_body("after the peer flies away")


func _assert_the_host_observes_its_own_body(context: String) -> void:
	_check(_host.active_ship == _craft and not _host._piloting,
		"the actor probe uses the remotely flown active_ship with its host on foot")
	var sample := _host._capture_cinder_actor_sample()
	_check(sample.get("actor_kind") == &"player"
		and sample.get("actor_instance_id") == _host.player.get_instance_id(),
		"the common-origin actor is the host's body %s" % context)
	_check(_host._get_debug_actor() == _host.player,
		"the debug/minimap actor is the host's body %s" % context)
	var streaming := _host.cinder_streaming_binding._sample_production_actor_position()
	_check(streaming.get("actor_kind") == &"player"
		and streaming.get("actor_instance_id") == _host.player.get_instance_id(),
		"the streaming actor is the host's body %s" % context)


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

	await _assert_game_flow_restarts_the_helm_stream()


func _assert_game_flow_restarts_the_helm_stream() -> void:
	# Exercise the production client method with the already admitted adapter.
	# This coordinator is detached so it has no automatic simulation or scene.
	var client := GameFlow.new()
	client.network_session = _pilot
	client._network_session_mode = &"client"
	client.active_ship = _craft
	client._piloting = true
	client._network_client_boarding_claim = {"ship_id": SHIP_ID, "role": &"pilot"}
	client._network_remote_helm_stream_epoch = 1 # D2 already delivered stream 1.
	client._network_client_boarding_server_tick = _helm_stamp + 1
	_movement_results.clear()
	client._advance_network_remote_helm_stream()
	await _wait_until(func() -> bool: return not _movement_results.is_empty(), 4.0)
	_check(not _movement_results.is_empty() and bool(_movement_results[0].get("accepted", false)),
		"the production client starts an accepted helm stream")
	var first: Dictionary = client._network_remote_helm.duplicate(true)
	var claim: Dictionary = client._network_client_boarding_claim.duplicate(true)
	client._piloting = false
	client._advance_network_remote_helm_stream()
	_check(client._network_remote_helm.is_empty(), "leaving the seat locally retires its helm stream")
	client._piloting = true
	client._network_client_boarding_server_tick = int(first.get("last_stamp", _helm_stamp)) + 1
	_movement_results.clear()
	client._advance_network_remote_helm_stream()
	await _wait_until(func() -> bool: return not _movement_results.is_empty(), 4.0)
	_check(int(client._network_remote_helm.get("stream_id", -1)) > int(first.get("stream_id", -1))
		and int(client._network_remote_helm.get("sequence", -1)) == 1,
		"the production client recreated its helm with a higher epoch and sent sequence zero")
	_check(client._network_client_boarding_claim == claim
		and not _movement_results.is_empty() and bool(_movement_results[0].get("accepted", false)),
		"the host accepts the recreated client stream without changing its ledger seat")
	client.network_session = null
	client.free()


# --- E ------------------------------------------------------------------------


func _assert_every_release_hands_the_craft_back() -> void:
	var left := await _board(BoardingIntent.ACTION_DISEMBARK)
	_check(left.get("status") == &"disembarked", "the remote pilot leaves the seat through the ledger")
	await _drive(2)
	_check(_craft.get_command_source() == _craft.get_local_input_source() and not _craft.is_piloted()
		and not _craft.is_remote_piloted(),
		"the ledger disembark hands the craft back to its own input, unpiloted")
	_assert_the_host_observes_its_own_body("after ledger release")
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
	_assert_the_host_observes_its_own_body("after peer disconnect")
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
	if _roll_child_pid > 0 and OS.is_process_running(_roll_child_pid):
		OS.kill(_roll_child_pid)
	if _failures.is_empty():
		print("NETWORK_REMOTE_PILOT_HELM_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_REMOTE_PILOT_HELM_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, ", ".join(_failures)])
	quit(1)


# A real production client and host have independent Input/frame clocks.
# The press intentionally falls between the existing 15Hz helm sends.
func _assert_independent_roll_press() -> void:
	_craft.global_position += Vector3(0, 30, 0)
	_craft.velocity = Vector3.ZERO
	var camera := _host.get_viewport().get_camera_3d()
	var previous_xdg := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", _roll_directory + "/peer-xdg")
	var parent_args := OS.get_cmdline_args()
	var project_path := ProjectSettings.globalize_path("res://")
	var path_index := parent_args.find("--path")
	if path_index >= 0 and path_index + 1 < parent_args.size():
		project_path = parent_args[path_index + 1]
	elif project_path.is_empty():
		project_path = DirAccess.open(".").get_current_dir()
	var args := PackedStringArray(["--headless", "--audio-driver", "Dummy", "--path", project_path,
		"--log-file", _roll_directory + "/peer.log", "--script", "res://tests/network_remote_pilot_helm_test.gd"])
	if not _package_under_test.is_empty():
		args.append_array(PackedStringArray(["--main-pack", _package_under_test]))
	args.append_array(PackedStringArray(["--", "roll-peer", str(_roll_port), _roll_directory]))
	if not _package_under_test.is_empty():
		args.append_array(PackedStringArray(["--package-under-test", _package_under_test]))
	_roll_child_pid = OS.create_process(OS.get_executable_path(), args)
	OS.set_environment("XDG_DATA_HOME", previous_xdg)
	_check(_roll_child_pid > 0, "spawn independent production helm client")
	if not await _wait_roll_marker("peer", "ready"):
		return
	var source := _craft.get_command_source() as RemotePilotSource
	_check(source != null, "independent pilot claim binds the real host helm")
	if source == null:
		return
	source.command_produced.connect(func(command: ShipCommand, _authority: int) -> void:
		if command.barrel_roll: _roll_edges += 1)
	_check(_craft.get_telemetry().get("engine_state") == "ONLINE",
		"remote throttle already wakes the host engine through automatic demand")
	_roll_mark("host", "press")
	if not await _wait_roll_marker("peer", "pressed"):
		return
	var received := await _wait_until(func() -> bool: return _roll_edges > 0, 2.0)
	_check(received and _craft._roll_animation > 0.0,
		"one independent local barrel-roll press reaches the host flight owner")
	_roll_mark("host", "observed")
	if not await _wait_roll_marker("peer", "held"):
		return
	_check(_roll_edges == 1, "repeated held helm packets never replay the roll edge")
	_check(_host.get_viewport().get_camera_3d() == camera and not _host._piloting,
		"remote action preserves the host on-foot camera and pilot ownership")
	await _wait_until(func() -> bool: return _craft._roll_animation <= 0.0, 3.0)
	_roll_mark("host", "invalidate")
	if not await _wait_roll_marker("peer", "revoked"): return
	_check(_roll_edges == 1, "source invalidation revokes an unsent roll between cadence sends")
	_roll_mark("host", "fresh")
	if not await _wait_roll_marker("peer", "fresh"): return
	_check(await _wait_until(func() -> bool: return _roll_edges == 2, 2.0),
		"fresh physical press after source invalidation reaches host once")
	_roll_mark("host", "release")
	if not await _wait_roll_marker("peer", "rebound"): return
	for _step in 8:
		await physics_frame
		await process_frame
	source = _craft.get_command_source() as RemotePilotSource
	_check(source != null and source.get_audit().delivered == 2 and source.get_audit().roll_delivered == 0,
		"same-peer rebind admits helm but revokes consumed and queued prior-lease roll streams")
	_check(_roll_edges == 2, "old-wire first receipt after rebind never repeats the host roll")
	if source != null:
		source.command_produced.connect(func(command: ShipCommand, _authority: int) -> void:
			if command.barrel_roll: _roll_edges += 1)
	await _wait_until(func() -> bool: return _craft._roll_animation <= 0.0, 3.0)
	_roll_mark("host", "rebind_press")
	if not await _wait_roll_marker("peer", "rebind_pressed"): return
	_check(await _wait_until(func() -> bool: return _roll_edges == 3, 2.0),
		"new physical press in a higher helm epoch works after seat rebind")
	_roll_mark("host", "finish")
	await _wait_roll_marker("peer", "finished")
	await _wait_until(func() -> bool: return not OS.is_process_running(_roll_child_pid), 10.0)
	_check(not OS.is_process_running(_roll_child_pid) and not FileAccess.file_exists(_roll_directory + "/peer.failed"),
		"independent client completes without diagnostic failure")
	_check(not (_craft.get_command_source() is RemotePilotSource) and not _craft.is_remote_piloted(),
		"independent disconnect retires the action source and restores local control")
	_check(_host._network_remote_pilot_roll_receipts.is_empty(), "peer disconnect retires the bounded roll receipt cache")


func _run_roll_peer() -> void:
	Engine.max_fps = 60
	_host = MAIN_SCENE.instantiate() as GameFlow
	_host.name = "HelmHostMain"
	_check(_host.configure_runtime_settings_persistence(UserDataStore.new(_roll_directory + "/peer-save.json"),
		_roll_directory + "/peer-legacy.cfg"), "independent peer uses private saves")
	root.add_child(_host)
	await process_frame
	await physics_frame
	_host.start_shift()
	await process_frame
	await physics_frame
	set_multiplayer(SceneMultiplayer.new(), _host.get_path())
	_craft = _host.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var local_source := _craft.get_local_input_source()
	var original_authority := local_source.get_authority_peer_id()
	var original_enabled := local_source.enabled
	_check(_host.join_network_session("127.0.0.1", _roll_port).get("accepted", false), "independent Main joins host")
	_check(local_source.get_authority_peer_id() == original_authority and _host._network_client_helm_input_sources.is_empty(),
		"joining before a confirmed pilot grant preserves retained input authority")
	_check(await _wait_until(func() -> bool: return not _host.get_network_session().get_server_offer().is_empty(), 15.0),
		"independent client admitted")
	var seats: Array[StringName] = [PILOT_SEAT]
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_BOARD, BoardingIntent.ROLE_PILOT, seats)
	_check(await _wait_until(func() -> bool: return _host._piloting and _craft.is_piloted(), 15.0),
		"host ledger confirms the client pilot presentation")
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(local_source.get_authority_peer_id() == _host._network_client_peer_id() and local_source.is_enabled_owner(),
		"confirmed client pilot owns its actual local input producer")
	_host._bind_network_client_helm_input_source(_craft)
	_check((_host._network_client_helm_input_sources[_craft.get_instance_id()] as Dictionary).authority == original_authority,
		"repeated pilot binding retains the original input authority once")
	_host.set_physics_process(false)
	for ship: HeroShip in _host.ships: ship.set_physics_process(false)
	_roll_key_action(&"move_forward", true)
	for _step in 120: await _roll_peer_step()
	_roll_mark("peer", "ready")
	await _roll_peer_wait("host", "press")
	while int(_host._network_remote_helm.get("ticks", 0)) % RemotePilotSource.SEND_INTERVAL_TICKS != 1:
		await _roll_peer_step()
	_roll_key_action(&"barrel_roll", true)
	await _roll_peer_step()
	_roll_key_action(&"barrel_roll", false)
	_check(_craft.get_last_ship_command().barrel_roll, "supported local source produces the single roll press")
	_check(_craft._roll_animation > 0.0, "client prediction consumes its own roll press")
	_roll_key_action(&"move_forward", false)
	_roll_mark("peer", "pressed")
	await _roll_peer_wait("host", "observed")
	for _step in 40: await _roll_peer_step()
	_roll_mark("peer", "held")
	await _roll_peer_wait("host", "invalidate")
	while int(_host._network_remote_helm.get("ticks", 0)) % RemotePilotSource.SEND_INTERVAL_TICKS != 1:
		await _roll_peer_step()
	_roll_key_action(&"barrel_roll", true)
	await _roll_peer_step()
	_roll_key_action(&"barrel_roll", false)
	_check(int(_host._network_remote_helm.roll_request_id) == 2, "physical press is retained before its next cadence send")
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	for _step in 8: await _roll_peer_step()
	_check(int(_host._network_remote_helm.roll_request_id) == 0, "focus invalidation discards the pending old-source press")
	_roll_mark("peer", "revoked")
	await _roll_peer_wait("host", "fresh")
	# First packet in this new source epoch carries a real physical edge.
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_craft._physics_process(1.0 / 60.0)
	_roll_key_action(&"barrel_roll", true)
	_craft._physics_process(1.0 / 60.0)
	var edge := _craft.get_last_ship_command()
	_host._advance_network_remote_helm_stream()
	var old_wire := RemotePilotSource.build_helm_intent(_host._network_client_peer_id(), SHIP_ID, 1, 0,
		int(_host._network_remote_helm.last_stamp), edge, int(_host._network_remote_helm.stream_id), 1)
	_roll_key_action(&"barrel_roll", false)
	_check(edge.barrel_roll and int(_host._network_remote_helm.sequence) == 1,
		"new producer epoch sends the physical roll as its first packet")
	_roll_mark("peer", "fresh")
	await _roll_peer_wait("host", "release", false)
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_DISEMBARK, BoardingIntent.ROLE_PILOT, seats)
	_check(await _wait_until(func() -> bool: return _host._network_client_boarding_claim.is_empty(), 10.0),
		"typed disembark releases the independent pilot lease")
	_host._advance_network_remote_helm_stream()
	_check(local_source.get_authority_peer_id() == original_authority and _host._network_client_helm_input_sources.is_empty(),
		"seat release restores the exact retained local producer authority")
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_BOARD, BoardingIntent.ROLE_PILOT, seats)
	_check(await _wait_until(func() -> bool: return StringName(_host._network_client_boarding_claim.get("role", &"")) == BoardingIntent.ROLE_PILOT, 10.0),
		"same independent peer reclaims the craft pilot seat")
	_check(_host.get_network_session().send_movement_intent(old_wire).get("accepted", false), "send exact previous-lease roll packet first after rebind")
	var queued_old_wire := old_wire.duplicate(true)
	queued_old_wire.sequence = 1
	queued_old_wire.client_tick = int(old_wire.client_tick) + 1
	queued_old_wire.interaction_request_id = 2
	_check(_host.get_network_session().send_movement_intent(queued_old_wire).get("accepted", false), "send queued newer-sequence roll from the retired lease")
	_roll_mark("peer", "rebound")
	await _roll_peer_wait("host", "rebind_press", false)
	_check(_craft.get_local_input_source() == local_source and local_source.is_enabled_owner(),
		"regrant binds the same retained producer to the current client")
	_roll_key_action(&"barrel_roll", true)
	await _roll_peer_step()
	_roll_key_action(&"barrel_roll", false)
	_roll_mark("peer", "rebind_pressed")
	await _roll_peer_wait("host", "finish")
	_host.shutdown_network_session(&"roll_peer_complete")
	_check(local_source.get_authority_peer_id() == original_authority and local_source.enabled == original_enabled
		and _craft.get_local_input_source() == local_source and _host._network_client_helm_input_sources.is_empty(),
		"disconnect restores the exact retained solo input source and enable state")
	_check(not _host.join_network_session("", _roll_port).get("accepted", false)
		and local_source.get_authority_peer_id() == original_authority, "failed join preserves retained solo input authority")
	_check(_host.join_network_session("127.0.0.1", _roll_port).get("accepted", false), "reconnect opens a fresh client session")
	_check(await _wait_until(func() -> bool: return not _host.get_network_session().get_server_offer().is_empty(), 15.0), "reconnected peer is admitted")
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_BOARD, BoardingIntent.ROLE_PILOT, seats)
	_host.shutdown_network_session(&"cancel_pending")
	_check(local_source.get_authority_peer_id() == original_authority and _host._network_client_helm_input_sources.is_empty(),
		"cancel before pilot confirmation leaves retained authority unchanged")
	_check(_host.join_network_session("127.0.0.1", _roll_port).get("accepted", false), "reconnect after cancellation uses the same Main")
	_check(await _wait_until(func() -> bool: return not _host.get_network_session().get_server_offer().is_empty(), 15.0), "post-cancel peer is admitted")
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_BOARD, BoardingIntent.ROLE_PILOT, seats)
	_check(await _wait_until(func() -> bool: return _host._piloting and local_source.is_enabled_owner() \
		and local_source.get_authority_peer_id() == _host._network_client_peer_id(), 15.0), "reconnect confirms a fresh pilot input binding")
	root.remove_child(_host)
	_check(local_source.get_authority_peer_id() == original_authority and _host._network_client_helm_input_sources.is_empty(),
		"Main detach retires the prediction input lease while preserving its source")
	root.add_child(_host)
	await process_frame
	await physics_frame
	_check(_craft.get_local_input_source() == local_source and local_source.get_authority_peer_id() == original_authority,
		"Main reentry restores the same solo producer without a stale network binding")
	_host.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("NETWORK_REMOTE_HELM_PEER_COMPLETE: %d assertions" % _assertion_count)
		_roll_mark("peer", "finished")
		quit(0)
	else:
		_roll_mark("peer", "failed")
		quit(1)


func _roll_peer_step(send_helm: bool = true) -> void:
	_craft._physics_process(1.0 / 60.0)
	if send_helm: _host._advance_network_remote_helm_stream()
	await physics_frame
	await process_frame


func _roll_peer_wait(role: String, marker: String, send_helm: bool = true) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_roll_directory + "/%s.%s" % [role, marker]): return true
		await _roll_peer_step(send_helm)
	_check(false, "%s reaches %s" % [role, marker])
	return false


func _wait_roll_marker(role: String, marker: String) -> bool:
	var arrived := await _wait_until(func() -> bool:
		return FileAccess.file_exists(_roll_directory + "/%s.%s" % [role, marker]), 60.0)
	_check(arrived, "%s reaches %s" % [role, marker])
	return arrived


func _roll_mark(role: String, marker: String) -> void:
	FileAccess.open(_roll_directory + "/%s.%s" % [role, marker], FileAccess.WRITE).store_string("ready")


func _roll_key_action(action: StringName, pressed: bool) -> void:
	for mapped: InputEvent in InputMap.action_get_events(action):
		if mapped is InputEventKey:
			var key := mapped.duplicate() as InputEventKey
			key.pressed = pressed
			key.echo = false
			Input.parse_input_event(key)
			Input.flush_buffered_events()
			return
	_check(false, "supported action has an authored physical key: %s" % action)
