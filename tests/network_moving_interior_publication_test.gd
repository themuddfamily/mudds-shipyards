extends "res://tests/in_flight_cabin_integration_test.gd"

## Authority-side moving-interior occupancy, driven end to end.
##
## The two suites next door prove what a client does with a walking crewmate:
## `tests/network_moving_interior_latency_test.gd` measures the replica under
## latency and `tests/network_moving_interior_presentation_test.gd` measures the
## node on screen. Both fed the walk through the relationship stream by hand,
## because the server did not publish one. This suite is the missing half: the
## poses on the wire are produced by `GameFlow._advance_network_moving_interior_publication()`
## running on the production `res://scenes/main.tscn`, from the occupancy the
## production `MovingInteriorFrame` already owns.
##
## What is real here:
##   * the server is the whole production Main subtree, hosting through
##     `GameFlow.host_network_session()`, with its own `PlayerController` boarding
##     the production `HalyardCrewTransport` on real `E` interactions, climbing
##     out on real thrust, leaving the seat, walking the aisle on real
##     locomotion input and sleeping in the production `ShipBunk`;
##   * two clients on real loopback ENet, each on its own `SceneMultiplayer`
##     branch with its own `NetworkEnetSessionAdapter`;
##   * one of them owns a real `NetworkMovingInteriorPresenter` drawing the
##     production pilot visual from the production replica and binding.
##
## Nothing publishes a relationship on the suite's behalf. Every pose asserted
## below was read off the flying cabin by the server, on its own physics tick.
##
## Named `network_*` for the same reason its neighbours are: only suites under
## `tests/network/*` or `tests/network_*` take `run_test_matrix.sh`'s per-run
## flock lane, and this one opens real `ENetMultiplayerPeer` sockets.
##
## The bounded-wait helpers, the real-input helpers and `_check` come from
## `in_flight_cabin_integration_test.gd`; this suite adds no second test driver.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Presenter := preload("res://scripts/network/network_moving_interior_presenter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const PILOT_ENTITY: StringName = &"pilot_halyard_new_design"
const FRAME_ID: StringName = &"frame_halyard_new_design"
const CREW_ENTITY: StringName = &"crewb"
const TICK_SECONDS := 1.0 / 60.0
## Mirrors the production replica horizon in `NetworkEnetSessionAdapter._init()`.
const EXTRAPOLATION_HORIZON_SECONDS := 0.25
## The aisle walk from the cockpit to the bunks is long; size the budget for it
## the way `ship_sleep_gameplay_test.gd` does rather than trusting the shared one.
const AISLE_TICK_BUDGET := 1500
## The turning leg the cabin flies while its crew walks it. An arc, not a
## straight line: the hull translates and yaws every tick, so a frame-local pose
## that never changes still traces a curve through the world. Radius and step are
## sized so one tick moves the hull about a metre — well inside
## `MovingInteriorFrame`'s teleport thresholds, so the crew is carried by the
## production rigid-delta path rather than being re-seated by a discontinuity.
const LEG_RADIUS := 240.0
const LEG_ANGLE_STEP := 0.004

var _game: GameFlow = null
var _craft: HalyardCrewTransport = null
var _player: PlayerController = null
var _frame: MovingInteriorFrame = null
var _server = null

var _branches: Array[SubViewport] = []
var _clients: Array = []
var _client_peer_ids: Array[int] = []
var _presenter: Presenter = null
var _presenter_holder: Node3D = null

var _crew_body: CharacterBody3D = null
var _crew_local := Vector3.ZERO
var _leg_active := false
var _leg_angle := 0.0
var _leg_origin := Transform3D.IDENTITY


func _run() -> void:
	if not await _build_world():
		await _finish_publication()
		return
	if not await _build_session():
		await _finish_publication()
		return
	await _assert_the_seated_pilot_is_published()
	await _assert_steady_state_costs_nothing()
	await _assert_a_busy_cabin_never_coalesces_the_seat()
	await _assert_leaving_the_seat_keeps_one_relationship()
	await _assert_the_client_follows_the_aisle_walk()
	await _assert_the_bunk_publishes_its_own_state()
	await _assert_a_crew_member_leaving_retires_everywhere()
	await _assert_reentry_republishes_the_same_occupancy()
	await _assert_craft_loss_retires_the_occupancy()
	_report_summary()
	await _finish_publication()


# --- world and session ------------------------------------------------------


func _build_world() -> bool:
	_game = MAIN_SCENE.instantiate() as GameFlow
	if _game == null:
		_check(false, "production scene instantiates for the publication sweep")
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
## relative path each client branch gives its own adapter, which is what lets the
## production RPCs route between them in one process.
func _build_session() -> bool:
	set_multiplayer(SceneMultiplayer.new(), _game.get_path())
	for branch_name in ["PublicationViewer", "PublicationCrew"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		_branches.append(branch)
		var adapter := Adapter.new()
		adapter.name = "NetworkSession"
		branch.add_child(adapter)
		_clients.append(adapter)
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port for the publication sweep")
		return false
	var port := probe.get_local_port()
	probe.stop()
	var hosted := _game.host_network_session(port, 4)
	_check(bool(hosted.get("accepted", false)), "GameFlow hosts the authoritative session")
	_server = _game.get_network_session()
	if _server == null or not bool(hosted.get("accepted", false)):
		return false
	var joined := true
	for client in _clients:
		joined = joined and bool(client.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "both clients join the host over loopback")
	await _wait_until(func() -> bool: return _server._peer_generations.size() >= 2, 6.0)
	_check(_server._peer_generations.size() >= 2,
		"the host admits both clients before any occupancy is published")
	if _server._peer_generations.size() < 2:
		return false
	_client_peer_ids = [
		_clients[0].multiplayer.get_unique_id(),
		_clients[1].multiplayer.get_unique_id(),
	]
	_presenter_holder = Node3D.new()
	_presenter_holder.name = "ViewerWorld"
	_branches[0].add_child(_presenter_holder)
	_presenter = Presenter.new()
	_presenter.name = "NetworkMovingInteriorPresenter"
	_presenter_holder.add_child(_presenter)
	_check(bool(_presenter.attach(_clients[0]).get("accepted", false)),
		"the drawing client's presenter attaches to its own session adapter")
	_check(bool(_presenter.register_frame(FRAME_ID, 1, _craft).get("accepted", false)),
		"the presenter resolves the host's published frame id to the live Halyard")
	return true


# --- the publication assertions ---------------------------------------------


func _assert_the_seated_pilot_is_published() -> void:
	await _drive(30)
	var audit: Dictionary = _game.get_network_moving_interior_publication_audit()
	_check(int(audit.get("published", 0)) > 0,
		"the host publishes its seated pilot without anyone asking it to")
	for index in _clients.size():
		var sample := _sample(_clients[index], PILOT_ENTITY)
		_check(not sample.is_empty(),
			"client %d receives the seated pilot's relationship" % index)
		_check(int(sample.get("occupancy_state", -1)) == Relationship.STATE_SEATED,
			"client %d is told the pilot is in a seat, not standing in the cabin" % index)
	var seat_anchor := _craft.get_pilot_seat_anchor()
	var expected := (_craft.global_transform.affine_inverse() * seat_anchor.global_transform).origin
	var drawn := (_sample(_clients[0], PILOT_ENTITY).get(
		"local_transform", Transform3D.IDENTITY
	) as Transform3D).origin
	_check(drawn.distance_to(expected) < 0.5,
		"the published seat pose is the craft's own seat anchor, not the cabin origin (%.2f m)"
			% drawn.distance_to(expected))
	_check(_presenter.get_avatar_node(PILOT_ENTITY) != null,
		"the drawing client puts a body in the pilot seat of the craft it is watching")
	_check(int(_presenter.get_avatar_occupancy_state(PILOT_ENTITY)) == Relationship.STATE_SEATED,
		"the drawn body is posed as a seated occupant")


## Steady state - the same crew aboard the same cabin, tick after tick - must
## build nothing. The roster, each occupant's record and each recipient list are
## produced when the cabin's crew or the admitted peer set changes and then
## reused, so a leg that changes neither moves none of the three counters while
## the poses keep going out.
func _assert_steady_state_costs_nothing() -> void:
	var before: Dictionary = _game.get_network_moving_interior_publication_audit()
	await _drive(40)
	var after: Dictionary = _game.get_network_moving_interior_publication_audit()
	_check(int(after.get("rebuilds", 0)) == int(before.get("rebuilds", 0)),
		"a steady leg rebuilds the published roster not once (%d)" % int(after.get("rebuilds", 0)))
	_check(int(after.get("records_built", 0)) == int(before.get("records_built", 0))
		and int(after.get("recipient_rebuilds", 0)) == int(before.get("recipient_rebuilds", 0)),
		"a steady leg builds no occupant record and no recipient list")
	_check(int(after.get("published", 0)) > int(before.get("published", 0)) + 30,
		"the host is still publishing the cabin every tick while it costs nothing to do so")


## Two occupants at 60 Hz is more than the 8-snapshots-per-10-tick budget can
## carry, so the walking body is coalesced — which is the point of the budget.
## The secured occupant is not: a pilot whose seat snapshot is parked is drawn
## standing in mid-cabin on every other client until they get up again.
func _assert_a_busy_cabin_never_coalesces_the_seat() -> void:
	_stand_second_crew_member_in_the_cabin()
	await _drive(40)
	var viewer: int = _client_peer_ids[0]
	var budget: Dictionary = _server.get_moving_interior_budget_snapshot(viewer)
	_check(int(budget.get("coalesced_count", 0)) > 0,
		"a busy cabin really does exhaust the per-recipient budget (%d coalesced)"
			% int(budget.get("coalesced_count", 0)))
	_check(int(budget.get("forced_priority_count", 0)) > 0,
		"the secured occupant is forced through that full budget (%d times)"
			% int(budget.get("forced_priority_count", 0)))
	var seat_lag := 0
	var walker_lag := 0
	for _round in 30:
		await _drive(1)
		var tick := int(_game.get_network_moving_interior_publication_audit().get("server_tick", 0))
		seat_lag = maxi(seat_lag, tick - int(_sample(_clients[0], PILOT_ENTITY).get("server_tick", 0)))
		var walker := _sample(_clients[0], CREW_ENTITY)
		if not walker.is_empty():
			walker_lag = maxi(walker_lag, tick - int(walker.get("server_tick", 0)))
	_check(seat_lag <= Adapter.MOVING_INTERIOR_BUDGET_WINDOW_TICKS,
		"the seat snapshot is never parked by the budget (worst lag %d ticks)" % seat_lag)
	_check(walker_lag > seat_lag,
		"the walking occupant is the one the budget coalesces (%d ticks against %d)"
			% [walker_lag, seat_lag])
	# The second crew member belongs to the second client, which is simulating
	# that body itself. Handing it back its own echo would stand two of them in
	# the cabin, one frame apart.
	_check(not _sample(_clients[0], CREW_ENTITY).is_empty(),
		"the other client is shown the second crew member")
	_check(_sample(_clients[1], CREW_ENTITY).is_empty(),
		"the crew member's own client is never shown its own body")
	_check(not _sample(_clients[1], PILOT_ENTITY).is_empty(),
		"that same client is still shown everybody else aboard")


func _assert_leaving_the_seat_keeps_one_relationship() -> void:
	var before: Dictionary = _server.get_moving_interior_occupancy(PILOT_ENTITY)
	_check(not before.is_empty(),
		"the seated pilot holds one authority occupancy record")
	_dispatch_pilot_action(_game, &"interact")
	var left := await _wait_for_phase(_game, GameFlow.Phase.IN_FLIGHT_CABIN, 2.0)
	left = left and await _wait_until(
		func() -> bool: return _player.is_control_enabled() and not bool(_game.get("_transition_busy")),
		3.0
	)
	_check(left, "E leaves the pilot seat into the cabin")
	if not left:
		print("EXIT STATE: phase=", _game.phase, " busy=", _game.get("_transition_busy"),
			" piloting=", _game.get("_piloting"), " telemetry=", _craft.get_telemetry(),
			" cabin=", _craft.get_in_flight_cabin_report().get("status", &""))
		return
	await _drive(20)
	var after: Dictionary = _server.get_moving_interior_occupancy(PILOT_ENTITY)
	_check(not after.is_empty()
		and int(after.get("entity_generation", 0)) == int(before.get("entity_generation", 0)),
		"leaving the seat is a change of posture on the same claim, not a new one")
	_check(_frame.is_occupant_registered(_player),
		"the craft's own interior frame now owns the walking pilot")
	var sample := _sample(_clients[0], PILOT_ENTITY)
	_check(int(sample.get("occupancy_state", -1)) == Relationship.STATE_WALKING,
		"the same relationship now says the pilot is on foot in the cabin")
	_check(_presenter.get_avatar_node(PILOT_ENTITY) != null,
		"the drawing client keeps the same body through the transition")


## The whole point of the phase: a crewmate walking the aisle of a Halyard that
## is translating and yawing, drawn on another client inside the same cabin.
func _assert_the_client_follows_the_aisle_walk() -> void:
	_player.global_basis = _craft.global_basis
	_player._camera_yaw.rotation.y = 0.0
	await process_frame
	await physics_frame
	_leg_origin = _craft.global_transform
	_leg_angle = 0.0
	_leg_active = true
	var max_lag := 0.0
	var max_world_travel := 0.0
	var max_local_travel := 0.0
	var first_world := Vector3.ZERO
	var first_local := Vector3.ZERO
	var have_first := false
	var drawn_rounds := 0
	var clips: Dictionary = {}
	Input.action_press(&"move_back")
	var ticks := 0
	while _craft.to_local(_player.global_position).z < 6.45 and ticks < AISLE_TICK_BUDGET:
		await _drive(1)
		ticks += 1
		var avatar: Node3D = _presenter.get_avatar_node(PILOT_ENTITY)
		if avatar == null:
			continue
		drawn_rounds += 1
		clips[_presenter.get_avatar_animation_clip(PILOT_ENTITY)] = true
		var live := _frame.get_occupant_frame_local_transform(_player).origin
		var local_origin := (_craft.global_transform.affine_inverse() * avatar.global_transform).origin
		max_lag = maxf(max_lag, local_origin.distance_to(live))
		if not have_first:
			first_world = avatar.global_position
			first_local = local_origin
			have_first = true
		max_world_travel = maxf(max_world_travel, first_world.distance_to(avatar.global_position))
		max_local_travel = maxf(max_local_travel, first_local.distance_to(local_origin))
	Input.action_release(&"move_back")
	await _drive(8)
	_leg_active = false
	var walked := _craft.to_local(_player.global_position).z >= 6.45
	_check(walked, "real locomotion walks the connected aisle while the cabin flies a turning leg")
	_check(drawn_rounds > 20, "the client draws the walking pilot for the whole aisle (%d rounds)"
		% drawn_rounds)
	var bound := (6.0 * TICK_SECONDS + EXTRAPOLATION_HORIZON_SECONDS) * 6.0 + 0.6
	_check(max_lag <= bound,
		"the drawn body stays within the interpolation bound of the live authoritative pose (%.3f m of %.3f m)"
			% [max_lag, bound])
	# The whole point of a moving interior: a crewmate who walks the length of
	# the aisle covers a few metres of cabin and hundreds of metres of sky,
	# because the cabin takes them with it.
	_check(max_world_travel > 100.0 and max_world_travel > 5.0 * maxf(max_local_travel, 0.001),
		"the drawn body is carried by the cabin, not left behind in world space (%.1f m world, %.2f m cabin)"
			% [max_world_travel, max_local_travel])
	_check(clips.has(&"walk") or clips.has(&"run"),
		"a walking crewmate is animated as moving, from the cabin-local speed the host published (clips: %s)"
			% str(clips.keys()))


func _assert_the_bunk_publishes_its_own_state() -> void:
	var bunk := _craft.get_node(
		"WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction"
	) as ShipBunk
	_player.global_basis = _craft.global_basis * Basis(Vector3.UP, PI / 2.0)
	_player._camera_yaw.rotation.y = 0.0
	await _drive(4)
	await _press_live_action(&"interact", 1)
	var sleeping := await _wait_until(func() -> bool: return _player.is_sleeping(), 2.0)
	_check(sleeping, "E lies down in the production bunk in flight")
	if not sleeping:
		return
	_check(bunk.is_reserved_for(_player), "the sleeping crewmate holds the bunk")
	await _drive(20)
	for index in _clients.size():
		_check(int(_sample(_clients[index], PILOT_ENTITY).get("occupancy_state", -1))
				== Relationship.STATE_SLEEPING,
			"client %d is told the crewmate is asleep in a bunk, not standing still" % index)
	_check(int(_presenter.get_avatar_occupancy_state(PILOT_ENTITY)) == Relationship.STATE_SLEEPING,
		"the drawn body is posed as a sleeper rather than an idle stander")
	var sleeping_budget: Dictionary = _server.get_moving_interior_budget_snapshot(_client_peer_ids[0])
	var forced_before := int(sleeping_budget.get("forced_priority_count", 0))
	await _drive(20)
	_check(int(_server.get_moving_interior_budget_snapshot(_client_peer_ids[0])
			.get("forced_priority_count", 0)) > forced_before,
		"a sleeper is a secured occupant and outranks the coalescing budget too")
	await _press_live_action(&"interact", 1)
	var awake := await _wait_until(func() -> bool: return not _player.is_sleeping(), 3.0)
	_check(awake, "E wakes the crewmate again")
	await _drive(20)
	_check(int(_sample(_clients[0], PILOT_ENTITY).get("occupancy_state", -1))
			== Relationship.STATE_WALKING,
		"waking republishes the same relationship as an on-foot occupant")


func _assert_a_crew_member_leaving_retires_everywhere() -> void:
	_check(not _sample(_clients[0], CREW_ENTITY).is_empty(),
		"the second crew member is on screen before they leave the cabin")
	_frame.unregister_occupant(_crew_body, false, &"publication_sweep_disembark")
	await _drive(20)
	_check(_server.get_moving_interior_occupancy(CREW_ENTITY).is_empty(),
		"the host retires the authority occupancy of a crew member who left the cabin")
	_check(_sample(_clients[0], CREW_ENTITY).is_empty(),
		"the other client stops drawing a crew member who left the cabin")
	_check(_presenter.get_avatar_node(CREW_ENTITY) == null,
		"the released crew member's avatar is gone, not frozen mid-aisle")
	_check(not _sample(_clients[0], PILOT_ENTITY).is_empty(),
		"the crewmate still aboard is unaffected by the other one leaving")


## A whole-Main detach ends the host's session, so every body it was publishing
## has to be retired with a real tombstone rather than left to a disconnect. On
## the way back in the pilot is still in the cabin, and the same entity id — the
## same claim — is published again.
func _assert_reentry_republishes_the_same_occupancy() -> void:
	var before: Dictionary = _server.get_moving_interior_occupancy(PILOT_ENTITY)
	_check(not before.is_empty(), "the walking pilot holds an occupancy before the detach")
	var parent := _game.get_parent()
	var pose_before := _craft.to_local(_player.global_position)
	_craft.velocity = Vector3.ZERO
	await physics_frame
	parent.remove_child(_game)
	await process_frame
	await process_frame
	_check(_game.get_network_moving_interior_published_entities().is_empty(),
		"a detached Main retires every occupancy it was publishing")
	_check(_presenter.get_avatar_node(PILOT_ENTITY) == null,
		"the drawing client stops drawing the crewmate of a host that went away")
	parent.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	_check(_game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _frame.is_occupant_registered(_player),
		"re-entry restores the pilot's cabin occupancy")
	_check(_craft.to_local(_player.global_position).distance_to(pose_before) < 0.5,
		"the host's own player is where it was, unaffected by the network teardown")
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a second loopback port for the re-entered host")
		return
	var port := probe.get_local_port()
	probe.stop()
	_check(bool(_game.host_network_session(port, 4).get("accepted", false)),
		"the re-entered host starts its session again")
	_server = _game.get_network_session()
	# The re-entered Main retires its old adapter on the way out, so hosting
	# again produces one adapter at the one canonical path the clients address.
	# `tests/network_rehost_after_reentry_test.gd` owns that rule; this only
	# refuses to measure publication through a path the clients cannot resolve.
	_check(_game.get_network_session_adapter_nodes().size() == 1
		and _game.get_network_session_rpc_path() == GameFlow.NETWORK_SESSION_NODE_NAME,
		"the re-entered host hosts through one adapter at the canonical RPC path")
	for client in _clients:
		client.shutdown(&"publication_sweep_rehost")
	for client in _clients:
		_check(bool(client.join("127.0.0.1", port).get("accepted", false)),
			"each client rejoins the re-entered host")
	await _wait_until(func() -> bool: return _server._peer_generations.size() >= 2, 6.0)
	_client_peer_ids = [
		_clients[0].multiplayer.get_unique_id(),
		_clients[1].multiplayer.get_unique_id(),
	]
	_presenter.attach(_clients[0])
	_presenter.register_frame(FRAME_ID, 1, _craft)
	await _drive(30)
	var after: Dictionary = _server.get_moving_interior_occupancy(PILOT_ENTITY)
	_check(not after.is_empty()
		and int(after.get("entity_generation", 0)) == int(before.get("entity_generation", 0)),
		"the re-entered host republishes the same occupancy under the same entity generation")
	_check(not _sample(_clients[0], PILOT_ENTITY).is_empty()
		and _presenter.get_avatar_node(PILOT_ENTITY) != null,
		"the crewmate is drawn again once the re-entered host is publishing")


func _assert_craft_loss_retires_the_occupancy() -> void:
	_check(not _server.get_moving_interior_occupancy(PILOT_ENTITY).is_empty(),
		"the cabin occupancy is live before the craft is lost")
	_craft.apply_damage(_craft.maximum_hull + 1.0, _craft.global_position, Vector3.UP)
	var recalled := await _wait_for_phase(_game, GameFlow.Phase.APPROACH_SHIP, 3.0)
	await _drive(30)
	_check(recalled and not _frame.is_occupant_registered(_player),
		"losing the craft runs the existing regeneration recall and empties the cabin")
	_check(_server.get_moving_interior_occupancy(PILOT_ENTITY).is_empty(),
		"losing the craft retires the cabin occupancy rather than leaving it claimed")
	_check(_sample(_clients[0], PILOT_ENTITY).is_empty()
		and _sample(_clients[1], PILOT_ENTITY).is_empty(),
		"every peer stops drawing a crewmate whose cabin no longer exists")
	_check(_presenter.get_child_count() == 0,
		"no avatar node survives the craft loss (%d children)" % _presenter.get_child_count())


# --- driving and reporting --------------------------------------------------


## One authoritative tick, plus the render frames the presenter needs. The host
## publishes from its own `_physics_process`; nothing here publishes for it.
func _drive(rounds: int) -> void:
	for _round in maxi(1, rounds):
		if _leg_active and is_instance_valid(_craft):
			_advance_turning_leg()
		if _crew_body != null and is_instance_valid(_crew_body) and is_instance_valid(_craft):
			# A second body that keeps moving, so its snapshots are never
			# identical and the budget has real traffic to coalesce.
			_crew_local.x = sin(float(Time.get_ticks_msec()) * 0.004) * 0.6
			_crew_body.global_transform = _craft.global_transform * Transform3D(
				Basis.IDENTITY, _crew_local
			)
		await physics_frame
		await process_frame


## One continuous arc flown by the hull itself. The craft is idled offline, so
## nothing else is moving it; this is the flight the crew are walking inside.
func _advance_turning_leg() -> void:
	_leg_angle += LEG_ANGLE_STEP
	var offset := Vector3(
		LEG_RADIUS * sin(_leg_angle),
		2.4 * sin(_leg_angle * 3.0),
		LEG_RADIUS * (1.0 - cos(_leg_angle))
	)
	_craft.global_transform = Transform3D(
		_leg_origin.basis.rotated(Vector3.UP, _leg_angle),
		_leg_origin.origin + _leg_origin.basis * offset
	)
	_craft.velocity = Vector3.ZERO


func _stand_second_crew_member_in_the_cabin() -> void:
	_crew_body = CharacterBody3D.new()
	_crew_body.name = "PublicationCrewBody"
	root.add_child(_crew_body)
	_crew_local = _craft.to_local(_player.global_position) + Vector3(0.0, 0.0, 2.0)
	_crew_body.global_transform = _craft.global_transform * Transform3D(Basis.IDENTITY, _crew_local)
	_check(bool(_game.register_network_moving_interior_occupant(
			_crew_body, CREW_ENTITY, _client_peer_ids[1]).get("accepted", false)),
		"a second crew member is named to the publisher as the second client's body")
	var registration: Dictionary = _frame.register_occupant(_crew_body, {
		"require_inside_bounds": false,
		"registration_source": &"publication_sweep_crew",
	})
	_check(bool(registration.get("registered", false)),
		"the craft's own interior frame accepts the second crew member")


func _sample(client, entity_id: StringName) -> Dictionary:
	return (client._moving_replica_samples.get(entity_id, {}) as Dictionary).duplicate(true)


func _report_summary() -> void:
	var audit: Dictionary = _game.get_network_moving_interior_publication_audit()
	print("PUBLICATION_SUMMARY %s" % JSON.stringify({
		"server_ticks": int(audit.get("ticks", 0)),
		"published": int(audit.get("published", 0)),
		"secured_snapshots": int(audit.get("secured_snapshots", 0)),
		"retired": int(audit.get("retired", 0)),
		"roster_rebuilds": int(audit.get("rebuilds", 0)),
		"records_built": int(audit.get("records_built", 0)),
		"recipient_rebuilds": int(audit.get("recipient_rebuilds", 0)),
		"unidentified_occupants": int(audit.get("unidentified_occupants", 0)),
	}))
	_check(not bool(audit.get("owns_seat_authority", true))
		and not bool(audit.get("owns_movement_authority", true)),
		"the publication seam claims no seat or movement authority at any point")


func _finish_publication() -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"sprint_boost", &"hover",
	]:
		Input.action_release(action)
	if _presenter != null and is_instance_valid(_presenter):
		_presenter.detach(&"suite_finished")
	for client in _clients:
		if is_instance_valid(client):
			client.shutdown(&"publication_sweep_close")
	if _presenter_holder != null and is_instance_valid(_presenter_holder):
		if _presenter_holder.get_parent() != null:
			_presenter_holder.get_parent().remove_child(_presenter_holder)
		_presenter_holder.free()
	_presenter_holder = null
	_presenter = null
	_clients.clear()
	if _crew_body != null and is_instance_valid(_crew_body):
		_crew_body.queue_free()
	if _game != null and is_instance_valid(_game):
		if _game.get_parent() != null:
			_game.get_parent().remove_child(_game)
		_game.free()
		_game = null
	await process_frame
	for branch in _branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	_branches.clear()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_MOVING_INTERIOR_PUBLICATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_MOVING_INTERIOR_PUBLICATION_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, "; ".join(_failures)])
	quit(1)
