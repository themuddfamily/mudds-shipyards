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


## Failure injection at the existing real adapter's publication seam only.
## ENet, admission, leases, physical craft and independent input stay real.
class LandingPublicationProbe extends Adapter:
	var fail_state: StringName = &""
	var failed_publications := 0

	func publish_landing_snapshot(entity_id: StringName, entity_generation: int,
			position: Vector3, state: StringName, recipients: Array = [], server_tick: int = 0) -> Dictionary:
		if state == fail_state:
			failed_publications += 1
			return {"accepted": false, "status": &"injected_publication_failure"}
		return super.publish_landing_snapshot(entity_id, entity_generation, position, state, recipients, server_tick)


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
var _production_max_physics_steps_per_frame := Engine.max_physics_steps_per_frame
var _clock_trace_rejections := 0
var _roll_pose_snapshot: Dictionary = {}
var _immediate_stall_probe := false
var _immediate_stall_results_start := 0
var _immediate_stall_claim: Array = []


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_immediate_stall_probe = args.has("--immediate-stall-probe")
	args.erase("--immediate-stall-probe")
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
	_assert_landing_marked_helm_rate_limit()
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
	_host._retire_network_session(&"landing_test_probe")
	var landing_adapter := LandingPublicationProbe.new()
	landing_adapter.name = GameFlow.NETWORK_SESSION_NODE_NAME
	_host.add_child(landing_adapter)
	_host.network_session = landing_adapter
	for binding: Array in _host._network_session_signal_bindings():
		_host._connect_signal_once(landing_adapter, StringName(binding[0]), binding[1] as Callable)
	_host._attach_network_halyard_command_bridge()
	_host._attach_network_ship_authority_composition()
	_check(bool(_host.host_network_session(port, 4).get("accepted", false)),
		"the host GameFlow opens the authoritative session")
	_server = _host.get_network_session()
	if _server == null:
		return false
	_server.movement_intent_result.connect(func(result: Dictionary) -> void:
		_movement_results.append(result.duplicate(true))
		if result.get("status") == &"client_tick_too_far_ahead" and _clock_trace_rejections < 8:
			_clock_trace_rejections += 1
			print("MOVEMENT_REFUSAL_TRACE: ", result)
			_clock_trace("host-admission-refusal-%d" % _clock_trace_rejections))
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
	client.ships = _host.ships
	client._network_session_mode = &"client"
	client.active_ship = _craft
	client._piloting = true
	client._network_client_boarding_claim = {"ship_id": SHIP_ID, "role": &"pilot"}
	client._network_remote_helm_stream_epoch = 1 # D2 already delivered stream 1.
	client._network_client_boarding_server_tick = _helm_stamp + 1
	# Retain the real production clock prerequisite even though this coordinator
	# has no scene physics: only accepted claimed-craft snapshots refresh it.
	_pilot.snapshot_applied.connect(client._on_network_snapshot_applied)
	var observed := await _wait_until(func() -> bool:
		var sample := client._network_craft_pose_stream.latest_sample(SHIP_ID)
		return not sample.is_empty() and int(sample.get("pilot_peer_id", 0)) == _pilot.multiplayer.get_unique_id(), 4.0)
	_check(observed, "the restart fixture receives its claimed craft through the production snapshot handler")
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
	_pilot.snapshot_applied.disconnect(client._on_network_snapshot_applied)
	client.network_session = null
	client.free()


# --- E ------------------------------------------------------------------------


func _assert_every_release_hands_the_craft_back() -> void:
	var unsafe := await _board(BoardingIntent.ACTION_DISEMBARK)
	_check(not unsafe.get("accepted", true) and unsafe.get("status") in [&"propulsion_not_offline", &"exterior_departure_requires_landing"]
		and _craft.get_command_source() is RemotePilotSource,
		"the real host refuses an unsafe airborne exterior departure and retains its pilot")
	var left := await _board(BoardingIntent.ACTION_SWAP, BoardingIntent.ROLE_PASSENGER)
	_check(left.get("status") == &"seat_swapped", "the airborne pilot releases the helm into a supported cabin berth")
	await _drive(2)
	_check(_craft.get_command_source() == _craft.get_local_input_source() and not _craft.is_piloted()
		and not _craft.is_remote_piloted(),
		"the ledger disembark hands the craft back to its own input, unpiloted")
	_assert_the_host_observes_its_own_body("after ledger release")
	_check(int(_server.get_remote_ship_command_snapshot().get("pilot_count", -1)) == 0,
		"the helm registration went with the seat")
	var again := await _board(BoardingIntent.ACTION_SWAP)
	await _drive(2)
	_check(again.get("status") == &"seat_swapped" and _craft.get_command_source() is RemotePilotSource,
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


func _board(action: StringName, role: StringName = BoardingIntent.ROLE_PILOT) -> Dictionary:
	_boarding_results.clear()
	_boarding_sequence += 1
	var intent = BoardingIntent.create(
		_pilot.multiplayer.get_unique_id(), PILOT_AVATAR, SHIP_ID, 1, FRAME_ID, 1,
		PILOT_SEAT if role == BoardingIntent.ROLE_PILOT else GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1),
		1, role, _boarding_sequence,
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
		_check(_host._network_landing_handoffs.is_empty() and _host._network_landing_entities.is_empty(),
			"session stop retires landing identities from completed and aborted remote approaches")
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
	# Earlier same-process fixtures cap catch-up to one step. Independent
	# processes must both use production catch-up: otherwise load discards host
	# ticks while the client advances, manufacturing a +30 authority refusal.
	Engine.max_physics_steps_per_frame = _production_max_physics_steps_per_frame
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
	if _immediate_stall_probe: args.append("--immediate-stall-probe")
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
	await _assert_clock_stall_recovery(source)
	if not _immediate_stall_probe: await _assert_long_clock_stall(source, "roll")
	_roll_mark("host", "press")
	if not await _wait_roll_marker("peer", "pressed"):
		return
	var received := await _wait_until(func() -> bool: return _roll_edges > 0, 2.0)
	_check(received and _craft._roll_animation > 0.0,
		"one independent local barrel-roll press reaches the host flight owner")
	if _immediate_stall_probe:
		_clock_trace("immediate-host-roll-deadline")
		print("IMMEDIATE_STALL_ROLL_OWNER: ", {"received_within_two_seconds": received,
			"edges": _roll_edges, "same_source": _craft.get_command_source() == source,
			"same_claim": _server.get_boarding_snapshot().get("occupancies", []) == _immediate_stall_claim,
			"receipt": source.get_roll_receipt(),
			"movement_results": _movement_results.slice(_immediate_stall_results_start).slice(-12)})
	_roll_mark("host", "observed")
	if _immediate_stall_probe:
		_roll_mark("host", "immediate_finish")
		await _wait_roll_marker("peer", "finished")
		await _wait_until(func() -> bool: return not OS.is_process_running(_roll_child_pid), 10.0)
		_check(not OS.is_process_running(_roll_child_pid), "immediate diagnostic client stops cleanly")
		return
	if not await _wait_roll_marker("peer", "held"):
		return
	_check(_roll_edges == 1, "repeated held helm packets never replay the roll edge")
	_check(_host.get_viewport().get_camera_3d() == camera and not _host._piloting,
		"remote action preserves the host on-foot camera and pilot ownership")
	await _wait_until(func() -> bool: return _craft._roll_animation <= 0.0, 3.0)
	var invalidation_main_physics := _host.is_physics_processing()
	var invalidation_craft_physics := _craft.is_physics_processing()
	_host.set_physics_process(false)
	_craft.set_physics_process(false)
	_roll_mark("host", "invalidate")
	var revoked_while_stopped := await _wait_roll_marker("peer", "revoked_while_stopped")
	_host.set_physics_process(invalidation_main_physics)
	_craft.set_physics_process(invalidation_craft_physics)
	if not revoked_while_stopped: return
	_check(_roll_edges == 1, "invalidating a producer revokes its deferred roll while authority physics is stopped")
	_roll_mark("host", "invalidate_resumed")
	if not await _wait_roll_marker("peer", "revoked"): return
	_check(_roll_edges == 1, "source invalidation revokes an unsent roll between cadence sends")
	# The marker reports a client send, not host consumption. Establish the exact
	# neutral source boundary before the one-packet fresh-edge experiment.
	var revoked_boundary := JSON.parse_string(FileAccess.get_file_as_string(_roll_directory + "/peer.revoked")) as Dictionary
	var neutral_consumed := await _wait_until(func() -> bool:
		var receipt := source.get_roll_receipt()
		return int(receipt.stream) == int(revoked_boundary.stream_id) \
			and int(receipt.sequence) == int(revoked_boundary.sequence) \
			and int(receipt.request) == 0, 2.0)
	_check(neutral_consumed, "authority consumes the exact revoked neutral boundary before the fresh first packet")
	print("ROLL_NEUTRAL_BOUNDARY: ", {"sent": revoked_boundary, "consumed": source.get_roll_receipt()})
	var fresh_result_start := _movement_results.size()
	_roll_mark("host", "fresh")
	if not await _wait_roll_marker("peer", "fresh"): return
	var fresh_roll_received := await _wait_until(func() -> bool: return _roll_edges == 2, 2.0)
	if not fresh_roll_received:
		print("ROLL_FRESH_DIAGNOSTIC: ", {"edges": _roll_edges, "source": source.get_audit(),
			"receipt": source.get_roll_receipt(), "movement_results": _movement_results.slice(maxi(0, _movement_results.size() - 12)),
			"craft_piloted": _craft.is_piloted(), "command": _craft.get_last_ship_command().to_dictionary()})
	_check(fresh_roll_received, "fresh physical press after source invalidation reaches host once")
	var fresh_wire := JSON.parse_string(FileAccess.get_file_as_string(_roll_directory + "/peer.fresh")) as Dictionary
	var fresh_receipt := source.get_roll_receipt()
	var fresh_admitted := false
	for result: Dictionary in _movement_results.slice(fresh_result_start):
		if result.get("accepted", false) and result.get("entity_id") == SHIP_ID and int(result.get("sequence", -1)) == 0:
			fresh_admitted = true
	_check(fresh_admitted and int(fresh_receipt.stream) == int(fresh_wire.stream_id)
		and int(fresh_receipt.sequence) == 0 and int(fresh_receipt.request) == 1,
		"the single fresh physical packet is admitted and consumed by the actual authority source")
	print("ROLL_FIRST_PACKET_OWNER: ", {"wire_stream": fresh_wire.stream_id, "wire_sequence": fresh_wire.sequence,
		"admitted": fresh_admitted, "receipt": fresh_receipt, "roll_edges": _roll_edges})
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
	await _assert_independent_landing()
	_roll_mark("host", "finish")
	await _wait_roll_marker("peer", "finished")
	await _wait_until(func() -> bool: return not OS.is_process_running(_roll_child_pid), 10.0)
	_check(not OS.is_process_running(_roll_child_pid) and not FileAccess.file_exists(_roll_directory + "/peer.failed"),
		"independent client completes without diagnostic failure")
	_check(not (_craft.get_command_source() is RemotePilotSource) and not _craft.is_remote_piloted(),
		"independent disconnect retires the action source and restores local control")
	_check(_host._network_remote_pilot_roll_receipts.is_empty(), "peer disconnect retires the bounded roll receipt cache")
	var berth := _host._resolve_berth_node(_craft.get_home_berth_id())
	_check(not _craft.is_landing_active() and not berth.is_reserved()
		and not _host._network_landing_handoffs.has(SHIP_ID),
		"disconnect during remote landing releases the physical reservation and network handoff")


# Stop the real host physics while the independent physical helm keeps sending.
# Recovery precedes fresh actions, preserving their original delivery deadlines.
func _assert_clock_stall_recovery(source: NetworkRemotePilotCommandSource) -> void:
	var main_physics := _host.is_physics_processing()
	var craft_physics := _craft.is_physics_processing()
	var claim_before: Dictionary = _server.get_boarding_snapshot().duplicate(true)
	_immediate_stall_claim = claim_before.get("occupancies", []).duplicate(true)
	var receipt_before := source.get_roll_receipt().duplicate(true)
	_clock_trace_rejections = 0
	_movement_results.clear()
	_clock_trace("stall-host-before")
	_host.set_physics_process(false)
	_craft.set_physics_process(false)
	_roll_mark("host", "stall")
	if not await _wait_roll_marker("peer", "stalled"):
		_host.set_physics_process(main_physics)
		_craft.set_physics_process(craft_physics)
		return
	_clock_trace("stall-host-frozen")
	var refused := false
	for result: Dictionary in _movement_results:
		if result.get("status") == &"client_tick_too_far_ahead": refused = true
	_check(not refused, "bounded helm sends avoid ahead-tick refusals throughout the real host stall")
	_host.set_physics_process(main_physics)
	_craft.set_physics_process(craft_physics)
	_check(_host.is_physics_processing() == main_physics and _craft.is_physics_processing() == craft_physics,
		"host restoration retains the exact Main and craft physics flags")
	_clock_trace("stall-host-restored")
	var results_start := _movement_results.size()
	_immediate_stall_results_start = results_start
	_roll_mark("host", "resume")
	if _immediate_stall_probe:
		_check(_craft.get_command_source() == source
			and claim_before.occupancies == _server.get_boarding_snapshot().get("occupancies", [])
			and int(source.get_roll_receipt().stream) == int(receipt_before.stream),
			"long-stall resume retains the exact pilot claim, authority source and helm stream")
		return
	if not await _wait_roll_marker("peer", "stall_sampled"): return
	_clock_trace("stall-host-after-sampling")
	var accepted_after := 0
	var ahead_after := 0
	var first_accepted: Dictionary = {}
	for result: Dictionary in _movement_results.slice(results_start):
		if result.get("accepted", false):
			if result.get("entity_id") == SHIP_ID:
				accepted_after += 1
				if first_accepted.is_empty(): first_accepted = result.duplicate(true)
		if result.get("status") == &"client_tick_too_far_ahead": ahead_after += 1
	var claim_after: Dictionary = _server.get_boarding_snapshot()
	var receipt_after := source.get_roll_receipt()
	print("CLOCK_STALL_RECOVERY_OWNER: ", {"accepted": accepted_after, "ahead_refused": ahead_after,
		"first_accepted": first_accepted, "edges": _roll_edges, "before": receipt_before, "after": receipt_after,
		"same_source": _craft.get_command_source() == source,
		"same_claim": claim_before.occupancies == claim_after.occupancies,
		"event_sequence_before": claim_before.event_sequence, "event_sequence_after": claim_after.event_sequence,
		"command": _craft.get_last_ship_command().to_dictionary()})
	_check(accepted_after > 0 and _roll_edges == 0 and _craft.get_last_ship_command().throttle > 0.0,
		"continuing physical throttle recovers within 180 steps before a fresh action")
	_check(_craft.get_command_source() == source and claim_before.occupancies == claim_after.occupancies
		and claim_before.event_sequence == claim_after.event_sequence
		and int(receipt_before.stream) == int(receipt_after.stream),
		"clock recovery preserves the exact pilot claim, authority source and helm stream")


func _assert_long_clock_stall(source: NetworkRemotePilotCommandSource, marker: String) -> void:
	_check(source != null, "%s stall retains a real authority helm source" % marker)
	if source == null: return
	var main_physics := _host.is_physics_processing()
	var craft_physics := _craft.is_physics_processing()
	var claim: Dictionary = _server.get_boarding_snapshot().duplicate(true)
	var receipt := source.get_roll_receipt().duplicate(true)
	var results_start := _movement_results.size()
	_host.set_physics_process(false)
	_craft.set_physics_process(false)
	_clock_trace("%s-long-stall-host-before" % marker)
	_roll_mark("host", "%s_stall" % marker)
	var stopped := await _wait_roll_marker("peer", "%s_stalled" % marker)
	_host.set_physics_process(main_physics)
	_craft.set_physics_process(craft_physics)
	if not stopped: return
	var ahead_refused := 0
	for result: Dictionary in _movement_results.slice(results_start):
		if result.get("status") == &"client_tick_too_far_ahead": ahead_refused += 1
	_check(ahead_refused == 0, "%s long stall produces no ahead-tick authority refusals" % marker)
	_check(_host.is_physics_processing() == main_physics and _craft.is_physics_processing() == craft_physics
		and _craft.get_command_source() == source
		and _server.get_boarding_snapshot().get("occupancies", []) == claim.occupancies
		and _server.get_boarding_snapshot().get("event_sequence") == claim.event_sequence
		and int(source.get_roll_receipt().stream) == int(receipt.stream),
		"%s immediate resume preserves exact physics flags, claim, authority source and helm stream" % marker)
	_clock_trace("%s-long-stall-host-restored" % marker)
	_roll_mark("host", "%s_resume" % marker)


func _run_long_clock_stall(marker: String) -> void:
	await _roll_peer_wait("host", "%s_stall" % marker)
	var producer := int(_host._network_remote_helm.producer_id)
	var producer_stream := int(_host._network_remote_helm.producer_stream)
	var helm_stream := int(_host._network_remote_helm.stream_id)
	var claim := _host._network_client_boarding_claim.duplicate(true)
	var held: Dictionary = {}
	for step in 600:
		await _roll_peer_step()
		if step == 59: held = _host._network_remote_helm.duplicate(true)
	var adapter := _host.get_network_session()
	var helm := _host._network_remote_helm
	_check(int(helm.last_stamp) <= adapter.get_boarding_result_server_tick() + Adapter.BOARDING_MAX_TICK_AHEAD,
		"%s long stall bounds the sender by the last real authority observation" % marker)
	_check(int(helm.sequence) == int(held.sequence) and int(helm.last_stamp) == int(held.last_stamp)
		and int(helm.sample_sequence) > int(held.sample_sequence),
		"%s long stall keeps sampling physical input while holding wire sequence and stamp" % marker)
	print("IMMEDIATE_LONG_STALL_SENDER: ", {"action": marker, "observed_tick": adapter.get_boarding_result_server_tick(),
		"estimate": adapter.get_boarding_server_tick_estimate(), "held": held, "after": helm})
	_roll_mark("peer", "%s_stalled" % marker)
	await _roll_peer_wait("host", "%s_resume" % marker)
	var resumed := _host._network_remote_helm
	_check(int(resumed.producer_id) == producer and int(resumed.producer_stream) == producer_stream
		and int(resumed.stream_id) == helm_stream and _host._network_client_boarding_claim == claim,
		"%s immediate physical action keeps the exact producer, helm stream and confirmed claim" % marker)


func _run_clock_stall_peer() -> void:
	await _roll_peer_wait("host", "stall")
	_clock_trace("stall-peer-before")
	for step in (600 if _immediate_stall_probe else 120):
		await _roll_peer_step()
		if step == 59: _clock_trace("stall-peer-mid")
	_clock_trace("stall-peer-frozen-host")
	var adapter := _host.get_network_session()
	var heard_before := adapter._boarding_heard_physics_frame
	var producer_before := int(_host._network_remote_helm.producer_id)
	var producer_stream_before := int(_host._network_remote_helm.producer_stream)
	var helm_stream_before := int(_host._network_remote_helm.stream_id)
	var duplicate := _roll_pose_snapshot.duplicate(true)
	var sample_before := _host._network_craft_pose_stream.latest_sample(SHIP_ID)
	_check(not duplicate.is_empty(), "stall fixture retains a real authoritative movement snapshot")
	_host._on_network_snapshot_applied({"accepted": true, "snapshot": duplicate})
	_check(adapter._boarding_heard_physics_frame == heard_before
		and _host._network_craft_pose_stream.latest_sample(SHIP_ID) == sample_before,
		"duplicate current-craft snapshot cannot refresh the boarding clock")
	var stale := duplicate.duplicate(true)
	var movement: Array = stale.get("sections", {}).get("movement", [])
	var identity := NetworkRemoteCraftPoseStream.pose_entity_id(SHIP_ID)
	var display := _host._network_craft_pose_stream._display_batch_from_movement(movement)
	var facts: Array = display.get(identity, [])
	var current_craft_row := false
	for row: Dictionary in movement:
		if row.get("mode") == NetworkRemoteCraftPoseStream.MODE and row.get("entity_id") == identity:
			current_craft_row = true
	_check(current_craft_row and facts.size() == 11 and StringName(facts[0]) == SHIP_ID
		and int(facts[1]) == int(sample_before.pose_tick) and int(facts[1]) > 0,
		"duplicate and stale checks contain the actual accepted claimed pilot craft facts")
	if facts.size() == 11 and int(facts[1]) > 0:
		facts[1] = int(facts[1]) - 1
		facts[2] = int(facts[2]) - 1
		var bytes := var_to_bytes(display.values())
		for row: Dictionary in movement:
			if row.has("display_facts"):
				row.display_size = bytes.size()
				row.display_facts = bytes.compress(FileAccess.COMPRESSION_ZSTD)
	_host._on_network_snapshot_applied({"accepted": true, "snapshot": stale})
	_check(adapter._boarding_heard_physics_frame == heard_before
		and _host._network_craft_pose_stream.latest_sample(SHIP_ID) == sample_before,
		"stale current-craft snapshot cannot refresh the boarding clock")
	var estimate_before := adapter.get_boarding_server_tick_estimate()
	_check(int(_host._network_remote_helm.last_stamp) <= adapter.get_boarding_result_server_tick() + Adapter.BOARDING_MAX_TICK_AHEAD,
		"stalled helm stamps stay inside the last real authority observation's existing window")
	_roll_mark("peer", "stalled")
	await _roll_peer_wait("host", "resume")
	_clock_trace("stall-peer-resumed")
	if _immediate_stall_probe:
		_check(int(_host._network_remote_helm.producer_id) == producer_before
			and int(_host._network_remote_helm.producer_stream) == producer_stream_before
			and int(_host._network_remote_helm.stream_id) == helm_stream_before,
			"immediate post-stall action retains its exact physical producer and helm stream")
		return
	var refreshed_downward := false
	for step in 180:
		await _roll_peer_step()
		if adapter._boarding_heard_physics_frame > heard_before \
			and adapter.get_boarding_server_tick_estimate() < estimate_before:
			refreshed_downward = true
		if step in [59, 119, 179]: _clock_trace("stall-peer-recovery-%d" % (step + 1))
	_check(refreshed_downward, "fresh accepted pilot sample corrects the extrapolated boarding clock downward")
	_check(int(_host._network_remote_helm.producer_id) == producer_before
		and int(_host._network_remote_helm.producer_stream) == producer_stream_before
		and int(_host._network_remote_helm.stream_id) == helm_stream_before,
		"recovery retains the exact physical input producer and helm epoch")
	_roll_key_action(&"move_forward", false)
	_roll_key_action(&"move_forward", true)
	_roll_mark("peer", "stall_sampled")


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
	_host._try_request_landing()
	_check(_landing_toast_is("Landing unavailable"), "unconfirmed client landing copy does not claim a submitted or accepted request")
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
	# Projectile-only publications can replace canonical movement. Retain the
	# actual accepted envelope that supplied this pilot's newest validated pose.
	# GameFlow connected first, so its consumer has committed before this runs.
	var capture_pose := func(result: Dictionary) -> void:
		if not result.get("accepted", false): return
		var snapshot: Dictionary = result.get("snapshot", {})
		var movement: Array = snapshot.get("sections", {}).get("movement", [])
		var identity := NetworkRemoteCraftPoseStream.pose_entity_id(SHIP_ID)
		var facts: Array = _host._network_craft_pose_stream._display_batch_from_movement(movement).get(identity, [])
		var sample := _host._network_craft_pose_stream.latest_sample(SHIP_ID)
		if facts.size() != 11 or sample.is_empty(): return
		for row: Dictionary in movement:
			if row.get("entity_id") == identity and int(row.get("owner_peer_id", 0)) == _host._network_client_peer_id() \
				and int(row.get("entity_generation", 0)) == int(sample.entity_generation) \
				and int(facts[1]) == int(sample.pose_tick) and int(facts[2]) == int(sample.operation_tick) \
				and int(facts[4]) == int(sample.craft_epoch):
				_roll_pose_snapshot = snapshot.duplicate(true)
	_host.get_network_session().snapshot_applied.connect(capture_pose)
	_host.set_physics_process(false)
	for ship: HeroShip in _host.ships: ship.set_physics_process(false)
	_roll_key_action(&"move_forward", true)
	for _step in 120: await _roll_peer_step()
	_roll_mark("peer", "ready")
	await _run_clock_stall_peer()
	_host.get_network_session().snapshot_applied.disconnect(capture_pose)
	if not _immediate_stall_probe: await _run_long_clock_stall("roll")
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
	if _immediate_stall_probe:
		await _roll_peer_wait("host", "immediate_finish")
		_roll_key_action(&"move_forward", false)
		_roll_key_action(&"barrel_roll", false)
		_clock_trace("immediate-peer-before-clean-teardown")
		_host.shutdown_network_session(&"immediate_probe_complete")
		_check(local_source.get_authority_peer_id() == original_authority
			and local_source.enabled == original_enabled, "immediate diagnostic restores retained input authority")
		_host.queue_free()
		await process_frame
		await process_frame
		_roll_mark("peer", "finished")
		quit(0 if _failures.is_empty() else 1)
		return
	for _step in 40: await _roll_peer_step()
	_roll_mark("peer", "held")
	await _roll_peer_wait("host", "invalidate")
	for _step in 60: await _roll_peer_step()
	while int(_host._network_remote_helm.get("ticks", 0)) % RemotePilotSource.SEND_INTERVAL_TICKS != 1:
		await _roll_peer_step()
	var held_sequence := int(_host._network_remote_helm.sequence)
	var held_stamp := int(_host._network_remote_helm.last_stamp)
	_roll_key_action(&"barrel_roll", true)
	await _roll_peer_step()
	_roll_key_action(&"barrel_roll", false)
	_check(int(_host._network_remote_helm.roll_request_id) == 2, "physical press is retained before its next cadence send")
	for _step in 4: await _roll_peer_step()
	_check(int(_host._network_remote_helm.sequence) == held_sequence
		and int(_host._network_remote_helm.last_stamp) == held_stamp,
		"authority clock hold retains the fresh roll counter without advancing wire sequence or stamp")
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	local_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	for _step in 8: await _roll_peer_step()
	_check(int(_host._network_remote_helm.roll_request_id) == 0, "focus invalidation discards the pending old-source press")
	_check(int(_host._network_remote_helm.sequence) == 0,
		"invalidated deferred source cannot send its retired physical edge")
	_roll_mark("peer", "revoked_while_stopped")
	await _roll_peer_wait("host", "invalidate_resumed")
	_check(await _wait_peer_until(func() -> bool: return int(_host._network_remote_helm.sequence) > 0, 2.0),
		"fresh authority observation resumes the new producer's neutral packet")
	FileAccess.open(_roll_directory + "/peer.revoked", FileAccess.WRITE).store_string(JSON.stringify({
		"stream_id": _host._network_remote_helm.stream_id,
		"sequence": int(_host._network_remote_helm.sequence) - 1,
		"client_tick": _host._network_remote_helm.last_stamp,
	}))
	await _roll_peer_wait("host", "fresh", false)
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
	print("ROLL_FRESH_WIRE: ", old_wire)
	_check(edge.barrel_roll and int(_host._network_remote_helm.sequence) == 1,
		"new producer epoch sends the physical roll as its first packet")
	FileAccess.open(_roll_directory + "/peer.fresh", FileAccess.WRITE).store_string(JSON.stringify(old_wire))
	await _roll_peer_wait("host", "release", false)
	_host._request_network_client_helm_release(_craft)
	_check(await _wait_until(func() -> bool: return _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PASSENGER, 10.0),
		"supported cabin swap releases the independent pilot lease")
	_host._advance_network_remote_helm_stream()
	_check(local_source.get_authority_peer_id() == original_authority and _host._network_client_helm_input_sources.is_empty(),
		"seat release restores the exact retained local producer authority")
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_SWAP, BoardingIntent.ROLE_PILOT, seats)
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
	await _run_landing_peer_actions(seats)
	await _roll_peer_wait("host", "finish", false)
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
	_host._advance_network_craft_pose_replica(1.0 / 60.0)
	await physics_frame
	await process_frame


func _wait_peer_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await _roll_peer_step()
	return bool(predicate.call())


func _peer_interact() -> void:
	_roll_key_action(&"interact", true)
	await _roll_peer_step()
	_roll_key_action(&"interact", false)
	await _roll_peer_step()


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


func _assert_independent_landing() -> void:
	var berth := _host._resolve_berth_node(_craft.get_home_berth_id())
	_check(berth != null, "remote landing uses the actual registered home berth")
	if berth == null: return
	var camera := _host.get_viewport().get_camera_3d()
	var host_phase := _host.phase
	var host_ship := _host.active_ship
	var departed := _host._sortie_departed_berth
	var returned := _host._return_registered
	var host_request := _host._landing_request_active
	var host_berth := _host._active_landing_berth_id
	_place_remote_approach(berth)
	await _assert_long_clock_stall(_craft.get_command_source() as RemotePilotSource, "landing")
	_roll_mark("host", "land")
	if not await _wait_roll_marker("peer", "landing_sent"): return
	_check(await _wait_until(func() -> bool: return _craft.is_landing_active(), 2.0),
		"normal independent landing key starts the host craft's existing berth assist")
	var token := StringName(_host._berth_tokens.get(_craft.get_instance_id(), &""))
	_check(berth.has_valid_lease(_craft, token, SHIP_ID)
		and _server.get_landing_entity(SHIP_ID).get("state") == &"landing_pending",
		"remote assist holds the exact existing physical lease and network pending handoff")
	var landing_result: Dictionary = (_host._network_remote_pilots[SHIP_ID] as Dictionary).get("landing_result", {}).duplicate(true)
	var landing_source := _craft.get_command_source() as RemotePilotSource
	await _drive(8)
	_check(bool(landing_result.get("accepted", false))
		and (_host._network_remote_pilots[SHIP_ID] as Dictionary).get("landing_result", {}) == landing_result
		and int(landing_source.get_roll_receipt().landing_request) == 1,
		"held packets consume the immediate post-stall landing edge once without restarting its request")
	berth.release(_craft, token)
	_check(await _wait_until(func() -> bool: return not _craft.is_landing_active() \
		and _server.get_landing_entity(SHIP_ID).get("state") == &"flying", 2.0),
		"ordinary reservation loss aborts remote assist and publishes flying")
	_check(not _host._berth_tokens.has(_craft.get_instance_id()) and not berth.is_reserved(),
		"remote abort releases craft bookkeeping without altering host landing flags")
	_place_remote_approach(berth)
	_server.fail_state = &"landed"
	_roll_mark("host", "land_retry")
	if not await _wait_roll_marker("peer", "landing_retry_sent"): return
	_check(await _wait_until(func() -> bool: return berth.get_occupant() == _craft, 6.0),
		"fresh normal landing press recovers to actual physical berth occupancy")
	_check(bool((_host._network_landing_handoffs.get(SHIP_ID, {}) as Dictionary).get("completion_retry", false))
		and berth.get_occupant() == _craft, "failed landed publication retains actual occupancy for per-craft retry")
	_server.fail_state = &""
	_check(await _wait_until(func() -> bool: return not bool((_host._network_landing_handoffs.get(SHIP_ID, {}) as Dictionary).get("completion_retry", true)), 2.0),
		"per-craft heartbeat retries landed publication after physical completion")
	_check(_server.get_landing_entity(SHIP_ID).get("state") == &"landed"
		and bool(_craft.get_landing_contract_report().get("strict_dock_acceptance", false))
		and _craft.global_transform.is_equal_approx(berth.get_dock_transform()),
		"remote physical completion commits the existing network landing at the exact dock transform")
	_check(_host.active_ship == host_ship and _host.phase == host_phase
		and _host.get_viewport().get_camera_3d() == camera and not _host._piloting
		and _host._sortie_departed_berth == departed and _host._return_registered == returned
		and _host._landing_request_active == host_request and _host._active_landing_berth_id == host_berth,
		"remote docking and abort preserve host on-foot craft, camera, phase and solo completion state")
	_check(await _wait_until(func() -> bool: return _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE, 6.0),
		"host automatically shuts down the actually docked craft before exterior departure")
	print("DOCK_EXIT_HOST_BEFORE: ", {"engine": _craft.get_telemetry().get("engine_state"),
		"landed": _craft.get_telemetry().get("landed"), "entity": _server.get_landing_entity(SHIP_ID)})
	_roll_mark("host", "dock_exit")
	if not await _wait_roll_marker("peer", "dock_exit_pressed"): return
	_check(await _wait_until(func() -> bool: return not _host._network_remote_pilots.has(SHIP_ID), 2.0),
		"actual independent postdock interact releases the host-confirmed pilot seat")
	if not await _wait_roll_marker("peer", "dock_reboarded"): return
	_check(_host._network_remote_pilots.has(SHIP_ID) and berth.get_occupant() == _craft,
		"actual hatch and cockpit keys reuse the same parked craft and pilot owner")
	var first_landing_generation := int(_server.get_landing_entity(SHIP_ID).get("entity_generation", 0))
	_roll_mark("host", "reuse_takeoff")
	_check(await _wait_until(func() -> bool: return not bool(_craft.get_telemetry().get("landed", true)) \
		and not berth.is_reserved() and _server.get_landing_entity(SHIP_ID).get("state") == &"flying", 6.0),
		"reused client physical flight control departs and retires the exact parked lease")
	_roll_mark("host", "reuse_neutral")
	if not await _wait_roll_marker("peer", "reuse_neutral_sent"): return
	var neutral := JSON.parse_string(FileAccess.get_file_as_string(_roll_directory + "/peer.reuse_neutral_sent")) as Dictionary
	_check(await _wait_until(func() -> bool:
		var receipt: Dictionary = _craft.get_command_source().get_roll_receipt()
		return int(receipt.get("stream", -1)) == int(neutral.get("stream_id", -2)) \
			and int(receipt.get("sequence", -1)) >= int(neutral.get("sequence", 0)) \
			and is_zero_approx(_craft.get_last_ship_command().throttle), 2.0),
		"host consumes the exact neutral stream boundary before the second landing approach")
	_place_remote_approach(berth)
	_clock_trace_rejections = 0
	_clock_trace("host-second-dock-before-request")
	_roll_mark("host", "reuse_redock")
	if not await _wait_roll_marker("peer", "reuse_redock_pressed"): return
	var second_docked := await _wait_until(func() -> bool: return berth.get_occupant() == _craft \
		and _server.get_landing_entity(SHIP_ID).get("state") == &"landed", 6.0)
	_clock_trace("host-second-dock-after-request")
	print("SECOND_DOCK_HOST_TRACE: ", {"docked": second_docked,
		"landing_result": (_host._network_remote_pilots.get(SHIP_ID, {}) as Dictionary).get("landing_result", {}),
		"entity": _server.get_landing_entity(SHIP_ID), "first_generation": first_landing_generation,
		"handoff": _host._network_landing_handoffs.get(SHIP_ID, {}),
		"physical_occupant": berth.get_occupant() == _craft,
		"physical_token": _host._berth_tokens.get(_craft.get_instance_id(), &""),
		"contract": _craft.get_landing_contract_report(), "telemetry": _craft.get_telemetry(),
		"command": _craft.get_last_ship_command().to_dictionary(),
		"receipt": _craft.get_command_source().get_roll_receipt(),
		"movement_results": _movement_results.slice(maxi(0, _movement_results.size() - 8))})
	_check(second_docked
		and int(_server.get_landing_entity(SHIP_ID).get("entity_generation", 0)) > first_landing_generation,
		"second physical landing request commits a new landing generation on the same unchanged hull")
	_check(await _wait_until(func() -> bool: return _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE, 6.0),
		"redocked craft automatically shuts down before its next physical exterior exit")
	_roll_mark("host", "reuse_exit")
	if not await _wait_roll_marker("peer", "reuse_exited"): return
	_check(not _host._network_remote_pilots.has(SHIP_ID) and berth.get_occupant() == _craft,
		"second confirmed exterior exit leaves the exact host berth occupied and releases only the pilot")
	if not await _wait_roll_marker("peer", "reuse_reboarded"): return
	_check(_host._network_remote_pilots.has(SHIP_ID), "same peer reboards the redocked craft through actual cabin and cockpit keys")
	_roll_mark("host", "interrupt_exit")
	if not await _wait_roll_marker("peer", "exit_detached"): return
	_check(not _host._network_remote_pilots.has(SHIP_ID) and berth.get_occupant() == _craft,
		"client detach after confirmed exterior departure releases its helm while retaining the physical dock")
	_roll_mark("host", "exit_reconnect")
	_clock_trace("host-exit-reconnect")
	if not await _wait_roll_marker("peer", "exit_restored"): return
	_clock_trace("host-exit-restored")
	_check(_host._network_remote_pilots.has(SHIP_ID), "reentered Main reuses the same dock through newly confirmed physical boarding")
	_check(_host._release_network_landing_handoff(_craft, berth).get("accepted", false),
		"occupied-berth fixture retires the completed network dock through its existing owner")
	_host._release_ship_berth(_craft)
	var occupier := HeroShip.new()
	occupier.ship_definition = _craft.get_ship_definition()
	_host.add_child(occupier)
	occupier.set_physics_process(false)
	occupier.collision_layer = 0
	occupier.collision_mask = 0
	occupier.global_position = Vector3(0, 1000, 0)
	var occupied_token := berth.try_reserve(occupier, occupier.get_ship_definition())
	_check(not occupied_token.is_empty() and berth.occupy(occupier, occupied_token),
		"another craft owns a real physical berth occupancy")
	_place_remote_approach(berth)
	_roll_mark("host", "land_occupied")
	if not await _wait_roll_marker("peer", "landing_occupied_sent"): return
	await _wait_until(func() -> bool: return (_host._network_remote_pilots.get(SHIP_ID, {}) as Dictionary) \
		.get("landing_result", {}).get("accepted", true) == false, 2.0)
	_check(not _craft.is_landing_active() and berth.get_occupant() == occupier
		and not _host._network_landing_handoffs.has(SHIP_ID),
		"normal remote landing refuses an occupied berth without replacing its lease")
	berth.release(occupier, occupied_token)
	occupier.queue_free()
	await process_frame
	var other := _host.get_node("TorrentInterceptor") as HeroShip
	_host.active_ship = other
	_host._piloting = true
	other.set_piloted(true)
	_host.phase = GameFlow.Phase.FREE_FLIGHT
	var flying_camera := _host.get_viewport().get_camera_3d()
	_trace_host_other_craft("before-request", other, flying_camera)
	_place_remote_approach(berth)
	_clock_trace("host-before-other-craft-edge")
	_roll_mark("host", "land_release")
	if not await _wait_roll_marker("peer", "landing_release_sent"): return
	var other_craft_landing_active := await _wait_until(func() -> bool: return _craft.is_landing_active(), 2.0)
	print("LANDING_OTHER_CRAFT_OWNER: ", {"active": other_craft_landing_active,
		"landing_result": (_host._network_remote_pilots.get(SHIP_ID, {}) as Dictionary).get("landing_result", {}),
		"entity": _server.get_landing_entity(SHIP_ID), "handoff": _host._network_landing_handoffs.get(SHIP_ID, {}),
		"physical_phase": _craft.get_landing_contract_report().get("phase"),
		"landed": _craft.get_telemetry().get("landed"),
		"receipt": _craft.get_command_source().get_roll_receipt(),
		"server_tick": _host._network_boarding_server_tick, "physics_catchup": Engine.max_physics_steps_per_frame,
		"movement_results": _movement_results.slice(maxi(0, _movement_results.size() - 8))})
	_check(other_craft_landing_active, "remote landing also engages while the host pilots another craft")
	_trace_host_other_craft("after-request", other, flying_camera)
	_server.fail_state = &"flying"
	_roll_mark("host", "release_landing_seat")
	if not await _wait_roll_marker("peer", "landing_seat_released"): return
	var failed_before := int(_server.failed_publications)
	_check(not _host._network_remote_pilots.has(SHIP_ID)
		and (_host._network_landing_handoffs.get(SHIP_ID, {}) as Dictionary).get("state") == &"abort_pending_publication",
		"failed abort publication retains its handoff after the pilot source is retired")
	_check(await _wait_until(func() -> bool: return int(_server.failed_publications) > failed_before, 2.0),
		"the existing craft handoff keeps retrying publication without a pilot binding")
	_server.fail_state = &""
	_check(await _wait_until(func() -> bool: return not _host._network_landing_handoffs.has(SHIP_ID), 2.0),
		"unbound abort retry publishes flying and retires its handoff")
	_roll_mark("host", "regrant_landing_seat")
	if not await _wait_roll_marker("peer", "landing_seat_rebound"): return
	_trace_host_other_craft("after-rebind", other, flying_camera)
	_check(await _wait_until(func() -> bool: return not _craft.is_landing_active(), 2.0)
		and not berth.is_reserved() and _server.get_landing_entity(SHIP_ID).get("state") == &"flying",
		"seat release aborts the actual remote assist and clears its physical/network reservation")
	for _step in 8:
		await physics_frame
		await process_frame
	_check(not _craft.is_landing_active() and not berth.is_reserved(),
		"old and queued prior-seat landing packets cannot reacquire a reservation after rebind")
	_trace_host_other_craft("before-preservation-check", other, flying_camera)
	_check(_host.active_ship == other and _host._piloting and other.is_piloted()
		and _host.phase == GameFlow.Phase.FREE_FLIGHT
		and _host.get_viewport().get_camera_3d() == flying_camera,
		"remote request, abort and seat rebind preserve the host's other flying craft and camera")
	_place_remote_approach(berth)
	_roll_mark("host", "land_disconnect")
	if not await _wait_roll_marker("peer", "landing_disconnect_sent"): return
	_check(await _wait_until(func() -> bool: return _craft.is_landing_active(), 2.0),
		"fresh physical landing press after rebind remains supported")
	# The parent sends finish next; disconnect must abort this pending assist.
	other.set_piloted(false)
	_host.active_ship = host_ship
	_host._piloting = false
	_host.phase = host_phase
	camera.make_current()


func _trace_host_other_craft(marker: String, craft: HeroShip, expected_camera: Camera3D) -> void:
	var current_camera := _host.get_viewport().get_camera_3d()
	print("HOST_OTHER_CRAFT_TRACE: ", {"marker": marker,
		"active_ship": _host.active_ship.get_path() if is_instance_valid(_host.active_ship) else NodePath(),
		"expected_ship": craft.get_path(), "piloting": _host._piloting,
		"craft_piloted": craft.is_piloted(), "craft_destroyed": craft.is_destroyed(),
		"phase": _host.phase, "expected_phase": GameFlow.Phase.FREE_FLIGHT,
		"camera": current_camera.get_path() if is_instance_valid(current_camera) else NodePath(),
		"expected_camera": expected_camera.get_path() if is_instance_valid(expected_camera) else NodePath(),
		"transition_busy": _host._transition_busy, "telemetry": craft.get_telemetry(),
		"command": craft.get_last_ship_command().to_dictionary()})


func _place_remote_approach(berth: ShipBerth) -> void:
	_craft.global_transform = berth.get_dock_transform().translated_local(Vector3(0, 3, 0))
	_craft.velocity = Vector3.ZERO
	_craft._landed = false
	_craft._docked_latch = false


func _landing_peer_press(marker: String) -> void:
	# Deliberately capture the physical edge between lower-rate helm sends.
	_clock_trace("peer-before-%s" % marker)
	if _host._network_client_remote_helm_ship() != _craft:
		_check(false, "landing fixture has a confirmed pilot before %s" % marker)
		_roll_mark("peer", marker)
		return
	while int(_host._network_remote_helm.get("ticks", 0)) % RemotePilotSource.SEND_INTERVAL_TICKS != 1:
		await _roll_peer_step()
	_roll_key_action(&"landing_assist", true)
	await _roll_peer_step()
	_roll_key_action(&"landing_assist", false)
	_check(_craft.get_last_ship_command().landing, "authored physical landing key produces %s" % marker)
	_host._consume_active_ship_command_edges()
	print("LANDING_CLIENT_LIFECYCLE: ", {"marker": marker, "phase": _host.phase,
		"transition_busy": _host._transition_busy, "paused": paused, "piloting": _host._piloting,
		"claim_role": _host._network_client_boarding_claim.get("role"),
		"command_sequence": _craft.get_last_ship_command().sequence,
		"lifecycle_sequence": _host._last_lifecycle_command_sequence,
		"toast_title": _host.hud._toast_title.text, "toast_deferred": _host.hud._toast_deferred})
	_check(_landing_toast_is("Landing request pending"), "the actual client lifecycle consumer presents a pending landing request")
	for _step in 4: await _roll_peer_step()
	print("LANDING_PEER_EDGE: ", {"marker": marker, "helm": _host._network_remote_helm})
	_clock_trace("peer-sent-%s" % marker)
	_roll_mark("peer", marker)


func _clock_trace(marker: String) -> void:
	var adapter := _host.get_network_session()
	var row := {"marker": marker, "frames": Engine.get_physics_frames(),
		"main_physics": _host.is_physics_processing(), "craft_physics": _craft.is_physics_processing(),
		"catchup": Engine.max_physics_steps_per_frame, "flow_boarding_tick": _host._network_boarding_server_tick,
		"client_answer_tick": _host._network_client_boarding_server_tick,
		"helm": _host._network_remote_helm.duplicate(true)}
	if is_instance_valid(adapter):
		row["answer_anchor"] = adapter._boarding_result_server_tick
		row["heard_frame"] = adapter._boarding_heard_physics_frame
		row["estimate"] = adapter.get_boarding_server_tick_estimate()
		row["flow_stamp"] = _host._network_client_boarding_tick_stamp() if not adapter.is_server() else -1
		if adapter.is_server():
			row["command_server_tick"] = adapter._remote_ship_commands._authority._server_tick
			row["command_snapshot"] = adapter.get_remote_ship_command_snapshot()
	print("DOCK_EXIT_CLOCK_TRACE: ", row)


func _peer_reboard_from_exterior() -> void:
	# Approach setup uses the actual hatch and production discovery. No direct
	# board call, claim/phase write, or synthetic logical action replaces the key.
	_host.player.teleport_to(Transform3D(Basis.IDENTITY, _craft.get_boarding_position() + Vector3(8, 0, 0)))
	await _roll_peer_step(false)
	_host._refresh_interaction_targets()
	_host.player.teleport_to(Transform3D(Basis.IDENTITY, _craft.get_boarding_position()))
	await _roll_peer_step(false)
	await _peer_interact()
	_check(await _wait_peer_until(func() -> bool: return _host.phase == GameFlow.Phase.IN_FLIGHT_CABIN \
		and _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PASSENGER \
		and not _host._transition_busy, 8.0), "physical hatch key boards a confirmed cabin berth after exterior exit")
	_host.player.teleport_to(_craft.get_in_flight_cabin_report().get("stand_transform"))
	await _roll_peer_step(false)
	_host._refresh_interaction_targets()
	print("DOCK_REUSE_COCKPIT_BEFORE: ", {"phase": _host.phase, "busy": _host._transition_busy,
		"claim": _host._network_client_boarding_claim, "player_local": _craft.to_local(_host.player.global_position),
		"seat_local": _craft.to_local(_craft.get_pilot_seat_anchor().global_position),
		"near_pilot": _host._network_client_near_pilot_seat(_craft), "near_ship": _host._near_ship,
		"candidate": _host.boarding_candidate.get_ship_id() if is_instance_valid(_host.boarding_candidate) else &"",
		"station": _host.station_interaction_candidate.name if is_instance_valid(_host.station_interaction_candidate) else &""})
	var supported_approach := _craft.get_in_flight_cabin_report().get("stand_transform") as Transform3D
	var seat_local := _craft.to_local(_craft.get_pilot_seat_anchor().global_position)
	var stand_local := _craft.to_local(supported_approach.origin)
	supported_approach.origin = _craft.to_global(Vector3(seat_local.x, stand_local.y, seat_local.z + 1.0))
	_host.player.teleport_to(supported_approach)
	await _roll_peer_step(false)
	_host._refresh_interaction_targets()
	_check(_host._network_client_near_pilot_seat(_craft) and _host.boarding_candidate == _craft,
		"supported cabin approach is within actual cockpit reach before the physical key")
	await _peer_interact()
	var cockpit_reused := await _wait_peer_until(func() -> bool: return _host._piloting and _craft.is_piloted() \
		and _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PILOT \
		and not _host._transition_busy, 8.0)
	print("DOCK_REUSE_COCKPIT_AFTER: ", {"reused": cockpit_reused, "phase": _host.phase,
		"claim": _host._network_client_boarding_claim, "request": _host._network_client_boarding_request,
		"boarding": _host.get_network_client_boarding_audit(), "player_local": _craft.to_local(_host.player.global_position)})
	_check(cockpit_reused, "physical cockpit key returns the same client to the confirmed pilot seat")


func _run_landing_peer_actions(seats: Array[StringName]) -> void:
	await _run_long_clock_stall("landing")
	await _roll_peer_wait("host", "land")
	await _landing_peer_press("landing_sent")
	await _roll_peer_wait("host", "land_retry")
	await _landing_peer_press("landing_retry_sent")
	await _roll_peer_wait("host", "dock_exit")
	await _wait_until(func() -> bool: return not _host._transition_busy, 10.0)
	_check(await _wait_peer_until(func() -> bool:
		var operation: Dictionary = _host._network_craft_pose_stream.latest_sample(SHIP_ID).get("operation_presentation", {})
		return operation.get("engine") == HeroShip.ENGINE_OFFLINE and bool(operation.get("landed", false)) \
			and bool(operation.get("docked", false)), 6.0), "client hears the committed host dock and automatic shutdown")
	var retained := _craft.get_local_input_source()
	var retained_authority := int((_host._network_client_helm_input_sources[_craft.get_instance_id()] as Dictionary).authority)
	print("DOCK_EXIT_CLIENT_BEFORE: ", {"phase": _host.phase, "busy": _host._transition_busy,
		"predicted_landed": _craft.get_telemetry().get("landed"), "predicted_engine": _craft.get_telemetry().get("engine_state"),
		"host_operation": _host._network_craft_pose_stream.latest_sample(SHIP_ID).get("operation_presentation", {}).get("docked")})
	var parked_tick := int(_host._network_craft_pose_stream.latest_sample(SHIP_ID).get("operation_tick", 0))
	_check(await _wait_peer_until(func() -> bool: return int(_host._network_craft_pose_stream.latest_sample(SHIP_ID).get("operation_tick", 0)) \
		- parked_tick >= 180, 6.0), "delayed parked physical exit waits on actual host operation ticks")
	var requests_before := int(_host.get_network_client_boarding_audit().requests)
	_roll_key_action(&"interact", true)
	_craft._physics_process(1.0 / 60.0)
	var stale_exit := _craft.get_last_ship_command()
	_roll_key_action(&"interact", false)
	retained.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	retained.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_host._consume_active_ship_command(stale_exit)
	_check(stale_exit.interact and int(_host.get_network_client_boarding_audit().requests) == requests_before
		and _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PILOT and _host._piloting,
		"retired physical exit edge cannot issue a boarding release or change confirmed pilot presentation")
	await _roll_peer_step()
	_roll_key_action(&"interact", true)
	await _roll_peer_step()
	_roll_key_action(&"interact", false)
	_host._consume_active_ship_command_edges()
	_check(_craft.get_last_ship_command().interact, "actual authored postdock interact produces its lifecycle edge")
	_check(await _wait_peer_until(func() -> bool: return _host.player._embodiment_state == PlayerController.EmbodimentState.DISEMBARKING, 3.0)
		and float(_craft.get_network_operation_presentation_snapshot().get("canopy", 0.0)) > 0.95,
		"confirmed avatar passage owns an actually open canopy over the settled host display")
	await _wait_peer_until(func() -> bool: return not _host._piloting and not _host._transition_busy \
		and _host._network_client_boarding_claim.is_empty() and _host.player.is_control_enabled(), 8.0)
	print("DOCK_EXIT_CLIENT_AFTER: ", {"phase": _host.phase, "busy": _host._transition_busy,
		"piloting": _host._piloting, "claim": _host._network_client_boarding_claim,
		"request": _host._network_client_boarding_request, "boarding": _host.get_network_client_boarding_audit(),
		"cursor": _host._last_lifecycle_command_sequence, "toast": _host.hud._toast_title.text})
	_check(not _host._piloting and _host._network_client_boarding_claim.is_empty(),
		"normal physical postdock interact confirms exterior disembark")
	_check(_host.player.is_on_floor() and _host.player.is_control_enabled() and not _host.player.is_seated()
		and _host.player.get_camera().current, "confirmed exterior departure has physical floor support and the player camera")
	_check(_craft.get_local_input_source() == retained and retained.get_authority_peer_id() == retained_authority
		and _host._network_client_helm_input_sources.is_empty(), "external disembark restores the same retained input producer")
	_check(_craft._network_canopy_motion_owner == 0 and _host._network_exterior_canopy_generation == 0,
		"completed exterior passage releases its exact canopy token")
	_roll_mark("peer", "dock_exit_pressed")
	await _peer_reboard_from_exterior()
	_roll_mark("peer", "dock_reboarded")
	await _roll_peer_wait("host", "reuse_takeoff")
	_roll_key_action(&"move_forward", true)
	await _roll_peer_wait("host", "reuse_neutral")
	_roll_key_action(&"move_forward", false)
	for _step in 4: await _roll_peer_step()
	FileAccess.open(_roll_directory + "/peer.reuse_neutral_sent", FileAccess.WRITE).store_string(JSON.stringify({
		"stream_id": _host._network_remote_helm.stream_id, "sequence": int(_host._network_remote_helm.sequence) - 1}))
	await _roll_peer_wait("host", "reuse_redock")
	await _landing_peer_press("reuse_redock_pressed")
	await _roll_peer_wait("host", "reuse_exit")
	_check(await _wait_peer_until(func() -> bool:
		var operation: Dictionary = _host._network_craft_pose_stream.latest_sample(SHIP_ID).get("operation_presentation", {})
		return operation.get("engine") == HeroShip.ENGINE_OFFLINE and bool(operation.get("docked", false)), 6.0),
		"client hears actual second dock and automatic shutdown")
	print("SECOND_DOCK_CLIENT_TRACE: ", {"latest_sample": _host._network_craft_pose_stream.latest_sample(SHIP_ID),
		"landing": _host.get_network_session().get_authoritative_snapshot().get("sections", {}).get("landing", []),
		"helm": _host._network_remote_helm.duplicate(true)})
	await _peer_interact()
	_check(await _wait_peer_until(func() -> bool: return not _host._piloting and not _host._transition_busy \
		and _host._network_client_boarding_claim.is_empty() and _host.player.is_control_enabled(), 8.0)
		and _host.player.is_on_floor() and _host.player.get_camera().current,
		"second physical exit completes with floor support despite the newer independent landing generation")
	_roll_mark("peer", "reuse_exited")
	await _peer_reboard_from_exterior()
	_roll_mark("peer", "reuse_reboarded")
	await _roll_peer_wait("host", "interrupt_exit")
	_check(await _wait_peer_until(func() -> bool: return _host._network_craft_pose_stream.latest_sample(SHIP_ID) \
		.get("operation_presentation", {}).get("engine") == HeroShip.ENGINE_OFFLINE, 6.0),
		"interruption fixture has an actual offline dock before its physical exit request")
	var canopy_source_open := _craft._canopy_open
	await _peer_interact()
	_check(await _wait_peer_until(func() -> bool: return _host._network_exterior_canopy_generation > 0 \
		and _host._network_client_boarding_claim.is_empty(), 2.0),
		"physical departure is host-confirmed and owns its canopy before Main removal")
	var old_answer := _host.get_network_session().get_boarding_intent_result_replica()
	root.remove_child(_host)
	_check(_craft._network_canopy_motion_owner == 0 and _host._network_exterior_canopy_generation == 0
		and not _host._transition_busy and _craft._canopy_open == canopy_source_open,
		"Main removal retires the exact canopy transition and restores its retained source flag")
	_check(_craft.get_local_input_source() == retained and retained.get_authority_peer_id() == retained_authority
		and _host._network_client_helm_input_sources.is_empty(), "interrupted exterior departure restores the exact retained input authority")
	root.add_child(_host)
	await process_frame
	for _step in 4: await _roll_peer_step(false)
	_host._on_network_client_boarding_answer(old_answer)
	_check(_host._network_client_boarding_claim.is_empty() and not _host._piloting
		and _host.player.is_control_enabled() and _host.player.is_on_floor() and _host.player.get_camera().current
		and not _host.player.is_seated() and is_zero_approx(float(_craft.get_network_operation_presentation_snapshot().get("canopy", -1.0))),
		"reentered Main has supported external control and a closed canopy; late departure answer cannot revive a seat")
	_roll_mark("peer", "exit_detached")
	await _roll_peer_wait("host", "exit_reconnect", false)
	_clock_trace("peer-before-exit-reconnect")
	_check(_host.join_network_session("127.0.0.1", _roll_port).get("accepted", false), "interrupted exterior Main reconnects through its public session entry")
	_check(await _wait_peer_until(func() -> bool: return not _host.get_network_session().get_server_offer().is_empty(), 15.0),
		"reentered exterior client is admitted before normal physical boarding")
	_clock_trace("peer-after-exit-reconnect-offer")
	await _peer_reboard_from_exterior()
	_clock_trace("peer-after-exit-reconnect-reboard")
	_roll_mark("peer", "exit_restored")
	await _roll_peer_wait("host", "land_occupied")
	await _landing_peer_press("landing_occupied_sent")
	await _roll_peer_wait("host", "land_release")
	await _landing_peer_press("landing_release_sent")
	var old_wire := RemotePilotSource.build_helm_intent(_host._network_client_peer_id(), SHIP_ID, 1,
		int(_host._network_remote_helm.sequence), int(_host._network_remote_helm.last_stamp) + 1,
		_craft.get_last_ship_command(), int(_host._network_remote_helm.stream_id),
		int(_host._network_remote_helm.roll_request_id), int(_host._network_remote_helm.landing_request_id))
	var old_landing_counter := int(_host._network_remote_helm.landing_request_id)
	await _roll_peer_wait("host", "release_landing_seat", false)
	_host._request_network_client_helm_release(_craft)
	_check(await _wait_until(func() -> bool: return _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PASSENGER, 10.0),
		"client releases its real pilot seat into the cabin during landing")
	_check(_host.get_network_session().send_movement_intent(old_wire).get("accepted", false),
		"send stale landing request after seat release")
	_roll_mark("peer", "landing_seat_released")
	await _roll_peer_wait("host", "regrant_landing_seat", false)
	_host._begin_network_client_boarding_request(_craft, _craft.get_node("ShipBoardingArea"),
		BoardingIntent.ACTION_SWAP, BoardingIntent.ROLE_PILOT, seats)
	_check(await _wait_until(func() -> bool: return _host._piloting and _craft.is_piloted() \
		and _host._network_client_boarding_claim.get("role") == BoardingIntent.ROLE_PILOT \
		and _host._network_client_boarding_request.is_empty(), 10.0),
		"client reclaims the pilot seat after aborted landing")
	_check(_host.get_network_session().send_movement_intent(old_wire).get("accepted", false),
		"send previous-seat landing request first after regrant")
	old_wire.sequence = int(old_wire.sequence) + 1
	old_wire.client_tick = int(old_wire.client_tick) + 1
	old_wire.boarding_target_id = StringName("pilot_landing_%d" % (old_landing_counter + 1))
	_check(_host.get_network_session().send_movement_intent(old_wire).get("accepted", false),
		"send queued higher-counter landing from the retired helm epoch")
	_roll_mark("peer", "landing_seat_rebound")
	await _roll_peer_wait("host", "land_disconnect", false)
	await _landing_peer_press("landing_disconnect_sent")


func _assert_landing_marked_helm_rate_limit() -> void:
	var limiter := preload("res://scripts/network/network_remote_ship_command_source.gd").new()
	_check(limiter.register_pilot(2, SHIP_ID, 1).get("accepted", false), "rate check uses the registered pilot helm owner")
	for tick in limiter.MAX_COMMANDS_PER_WINDOW:
		limiter.set_server_tick(tick)
		var wire := RemotePilotSource.build_helm_intent(2, SHIP_ID, 1, tick, tick, null, 1, 0, tick + 1)
		_check(limiter.accept_command(2, wire).get("accepted", false), "landing-marked helm remains admitted inside its existing rate window")
		limiter.consume(SHIP_ID, tick)
	var tick: int = limiter.MAX_COMMANDS_PER_WINDOW
	limiter.set_server_tick(tick)
	var over_window := RemotePilotSource.build_helm_intent(2, SHIP_ID, 1, tick, tick, null, 1, 0, tick + 1)
	_check(limiter.accept_command(2, over_window).get("status") == &"command_rate_limited",
		"landing marker cannot bypass the registered pilot's existing helm rate refusal")


func _landing_toast_is(title: String) -> bool:
	return _host.hud._toast_title.text == title.to_upper() \
		or String(_host.hud._toast_deferred.get("title", "")) == title
