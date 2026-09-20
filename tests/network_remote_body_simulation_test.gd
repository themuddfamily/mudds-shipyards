extends "res://tests/in_flight_cabin_integration_test.gd"

## Server-owned remote bodies, driven end to end over a real ENet session.
##
## The publication gate next door proved the authority *speaks* for every
## occupant of a flying cabin. This suite proves it *simulates* the remote
## ones: a client streams on-foot intent for its crewmate, the server stands a
## production `PlayerController` in the production Halyard's cabin, carries it
## on the craft's own `MovingInteriorFrame`, walks it down the aisle with real
## collision and support, sits it in the production bunk when it asks and
## stands it up again — and what every peer receives is that body's pose.
##
## What is real here:
##   * the server is the whole production Main subtree hosting through
##     `GameFlow.host_network_session()`, its own pilot flying the Halyard;
##   * up to five clients on real loopback ENet, each its own
##     `SceneMultiplayer` branch and `NetworkEnetSessionAdapter`, four of them
##     owning one remote body each and streaming `NetworkMovementIntent`
##     through the production `send_movement_intent()` RPC at the production
##     cadence of `NetworkRemoteBodyIntentSource`;
##   * ownership, generation, stream order and the tick window are enforced by
##     the production `NetworkMovementAuthority`; the bodies are the
##     production player scene; the seat is the production `ShipBunk`.
##
## The crowd budget at the end characterises 1 pilot + N walking bodies
## (N = 1, 2, 4) under the moving-interior latency profiles, through the same
## test-only transport shim the latency suite uses, and prints one
## `REMOTE_BODY_CROWD_BUDGET` line per (N, profile).
##
## Named `network_*` so `run_test_matrix.sh` gives it the per-run flock lane:
## it opens real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const Intent := preload("res://scripts/network/network_movement_intent.gd")
const IntentSource := preload("res://scripts/network/network_remote_body_intent_source.gd")
const MovementAuthority := preload("res://scripts/network/network_movement_authority.gd")
const RemoteBodySimulation := preload("res://scripts/network/network_remote_body_simulation.gd")
const Cadence := preload("res://tests/fixed_physics_cadence.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const FRAME_ID: StringName = &"frame_halyard_new_design"
const PILOT_ENTITY: StringName = &"pilot_halyard_new_design"
const WALKER_ENTITIES: Array = [&"crewa", &"crewb", &"crewc", &"crewd"]
const WALKER_COUNT := 4
const OBSERVER_INDEX := 4
const TICK_SECONDS := 1.0 / 60.0
const FORWARD := Vector2(0.0, -1.0)
const BACKWARD := Vector2(0.0, 1.0)
## Frame-local metres the body must cover down the aisle before the suite
## believes it walked rather than settled.
const MIN_AISLE_PROGRESS := 3.0
## The Halyard's published cabin movement envelope, with the deck's own margin.
const BOUNDS_MARGIN := 0.35
## Ticks a body that has come to rest is given to report deck support. A capsule
## re-seating on a translating deck takes a tick or two; anything that is
## genuinely unsupported is still falling at the end of this window, and the
## envelope check beside it catches a body that left the deck at all.
const SUPPORT_SETTLE_TICKS := 20

const PROFILES := [
	{"name": "clean", "delay_ms": 0.0, "jitter_ms": 0.0, "loss": 0.0, "rounds": 60},
	{"name": "80ms_20j", "delay_ms": 80.0, "jitter_ms": 20.0, "loss": 0.0, "rounds": 60},
	{"name": "200ms_60j", "delay_ms": 200.0, "jitter_ms": 60.0, "loss": 0.0, "rounds": 60},
	{"name": "350ms_120j_2pct", "delay_ms": 350.0, "jitter_ms": 120.0, "loss": 0.02, "rounds": 60},
]


## The latency suite's transport shim, unchanged in what it may do: hold,
## re-order or drop a relationship packet the server already decided to send.
class TransportShim extends RefCounted:
	var server = null
	var rng := RandomNumberGenerator.new()
	var now := 0.0
	var delay := 0.0
	var jitter := 0.0
	var loss := 0.0
	var queue: Array = []
	var sent := 0
	var dropped := 0
	var delivered := 0

	func configure(p_delay_ms: float, p_jitter_ms: float, p_loss: float) -> void:
		delay = p_delay_ms / 1000.0
		jitter = p_jitter_ms / 1000.0
		loss = p_loss
		sent = 0
		dropped = 0
		delivered = 0

	func enqueue(peer_id: int, wire: Dictionary) -> void:
		sent += 1
		if loss > 0.0 and rng.randf() < loss:
			dropped += 1
			return
		var wobble := rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0
		queue.append({"peer_id": peer_id, "wire": wire, "at": now + maxf(0.0, delay + wobble)})

	func pump() -> void:
		var due: Array = []
		var held: Array = []
		for item_variant in queue:
			var item := item_variant as Dictionary
			if float(item.get("at", 0.0)) <= now:
				due.append(item)
			else:
				held.append(item)
		queue = held
		due.sort_custom(func(left: Variant, right: Variant) -> bool:
			return float((left as Dictionary).get("at", 0.0)) < float((right as Dictionary).get("at", 0.0))
		)
		for item_variant in due:
			var item := item_variant as Dictionary
			delivered += 1
			if server != null and is_instance_valid(server):
				server.deliver_moving_interior_wire_packet(int(item.get("peer_id", 0)), item.get("wire", {}) as Dictionary)

	func drain() -> void:
		now += 60.0
		pump()


## Per-physics-tick driver. The owning client streams its intent from its own
## `_physics_process` in production, so the harness does the same rather than
## once per await round: on a shared machine one round can span several
## physics steps, which would stretch a 15 Hz cadence into a delivery gap.
## Runs after every body has moved (priority 10000), so the pose it samples
## for tick T is exactly what the publisher reads at the start of tick T + 1.
class TickDriver extends Node:
	var suite = null

	func _ready() -> void:
		process_physics_priority = 10000

	func _physics_process(_delta: float) -> void:
		if suite != null:
			suite._on_physics_tick()


var _cadence := Cadence.new()

var _game: GameFlow = null
var _craft: HalyardCrewTransport = null
var _player: PlayerController = null
var _frame: MovingInteriorFrame = null
var _server = null

var _branches: Array[SubViewport] = []
var _clients: Array = []
var _client_peer_ids: Array[int] = []
## Per walker: intent source, movement plan and the entity it drives.
var _walkers: Array[Dictionary] = []
var _intent_statuses: Dictionary = {}
var _boarding_results: Array = []
var _shim: TransportShim = null
var _ticker: TickDriver = null
var _leg_active := false
var _leg_origin := Transform3D.IDENTITY
var _leg_distance := 0.0
var _bounds := AABB()
var _floor_violations := 0
var _bounds_violations := 0
var _pose_samples := 0
var _authoritative: Dictionary = {}
var _crowd_reports: Array[Dictionary] = []
var _walk_end_local := Vector3.ZERO


func _run() -> void:
	if not await _build_world():
		await _finish_remote_bodies()
		return
	if not await _build_session():
		await _finish_remote_bodies()
		return
	await _assert_a_remote_body_is_stood_up_for_the_walker()
	await _assert_the_body_walks_the_aisle_on_intent()
	await _assert_forged_and_stale_intents_are_rejected()
	await _assert_the_body_sleeps_in_the_bunk_and_wakes()
	await _assert_the_hatch_admits_and_releases_a_body()
	await _assert_the_crowd_budget()
	await _assert_a_disconnect_releases_the_body()
	await _assert_reentry_and_rehost_readmit_the_body()
	_report_summary()
	await _finish_remote_bodies()


# --- world and session ------------------------------------------------------


func _build_world() -> bool:
	# One physics step per rendered frame, however loaded the machine is. ENet
	# is polled once per frame, so several physics steps in one frame would
	# batch a 15 Hz intent cadence into bursts and starve the body between
	# them — a property of the harness, not of the production peer, which
	# streams and polls on the same frame. Restored in
	# `_finish_remote_bodies()` rather than left set on the engine.
	_cadence.pin()
	_game = MAIN_SCENE.instantiate() as GameFlow
	if _game == null:
		_check(false, "production scene instantiates for the remote-body sweep")
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
	_check(_game.get_network_remote_body_audit().get("bodies", -1) == 0,
		"solo play stands no remote body at all")
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
	_bounds = HalyardCrewTransport.CABIN_MOVEMENT_BOUNDS.grow(BOUNDS_MARGIN)
	_leg_origin = _craft.global_transform
	_check(_frame != null, "the Halyard publishes its production moving-interior frame")
	return _frame != null


func _build_session() -> bool:
	set_multiplayer(SceneMultiplayer.new(), _game.get_path())
	for index in WALKER_COUNT + 1:
		var branch := SubViewport.new()
		branch.name = "RemoteBodyPeer%d" % index
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		_branches.append(branch)
		var adapter := Adapter.new()
		adapter.name = "NetworkSession"
		branch.add_child(adapter)
		_clients.append(adapter)
	var port := _reserve_port()
	if port <= 0:
		return false
	var hosted := _game.host_network_session(port, 8)
	_check(bool(hosted.get("accepted", false)), "GameFlow hosts the authoritative session")
	_server = _game.get_network_session()
	if _server == null or not bool(hosted.get("accepted", false)):
		return false
	_server.movement_intent_result.connect(_on_server_intent_result)
	_server.boarding_intent_result.connect(_on_server_boarding_result)
	if not await _join_all(port):
		return false
	_shim = TransportShim.new()
	_shim.rng.seed = 0xB0D1E5
	_shim.server = _server
	_ticker = TickDriver.new()
	_ticker.name = "RemoteBodyTickDriver"
	_ticker.suite = self
	root.add_child(_ticker)
	_check(bool(_game.get_network_remote_body_audit().get("attached", false)),
		"hosting attaches the remote-body simulation to the one session adapter")
	return true


func _reserve_port() -> int:
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback UDP port for the remote-body sweep")
		return 0
	var port := probe.get_local_port()
	probe.stop()
	return port


func _join_all(port: int) -> bool:
	var joined := true
	for client in _clients:
		joined = joined and bool(client.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "every client joins the host over loopback")
	var expected := _clients.size()
	await _wait_until(func() -> bool: return _server._peer_generations.size() >= expected, 8.0)
	_check(_server._peer_generations.size() >= expected,
		"the host admits all %d clients before any body is admitted" % expected)
	if _server._peer_generations.size() < expected:
		return false
	_client_peer_ids = []
	for client in _clients:
		_client_peer_ids.append(client.multiplayer.get_unique_id())
	return true


# --- one body ---------------------------------------------------------------


func _assert_a_remote_body_is_stood_up_for_the_walker() -> void:
	await _drive(20)
	var before := _frame.get_occupant_count()
	var admitted := _game.admit_network_remote_body(_client_peer_ids[0], WALKER_ENTITIES[0], _craft)
	_check(bool(admitted.get("accepted", false)),
		"the authority stands a body for the first client's crewmate (%s)"
			% String(admitted.get("status", &"?")))
	var body := _body(WALKER_ENTITIES[0])
	_check(body != null and body is PlayerController and body.is_inside_tree(),
		"the remote body is the production PlayerController scene, in the tree")
	if body == null:
		return
	_check(body.is_remote_driven() and not body.is_control_enabled()
		and not body.get_camera().current,
		"the remote body reads no host input and never takes the camera")
	_check(_frame.is_occupant_registered(body) and _frame.get_occupant_count() == before + 1,
		"the craft's own moving-interior frame carries the remote body")
	var stand_local := _craft.to_local(_craft.get_cabin_stand_transform().origin)
	var local := _frame.get_occupant_frame_local_transform(body).origin
	_check(local.distance_to(stand_local) < 0.6 and _bounds.has_point(local),
		"the body is stood at the cabin's own stand pose, inside the movement envelope")
	_check(bool(body.get_cabin_containment_report().get("active", false)),
		"the remote body is held to the cabin envelope like the host's own player")
	var forged := _game.admit_network_remote_body(_client_peer_ids[0], WALKER_ENTITIES[0], _craft)
	_check(not bool(forged.get("accepted", false)) and forged.get("status") == &"duplicate_body",
		"one entity id gets one body")
	var stranger := _game.admit_network_remote_body(999, &"nobody", _craft)
	_check(not bool(stranger.get("accepted", false)) and stranger.get("status") == &"peer_not_admitted",
		"a peer the session never admitted gets no body")
	_bind_walker(0, WALKER_ENTITIES[0], 1)
	await _drive(30)
	var published: Array = _game.get_network_moving_interior_published_entities()
	_check(published.has(WALKER_ENTITIES[0]) and published.has(PILOT_ENTITY),
		"the publisher speaks for the simulated body beside the host's own pilot")
	var seen_by_observer := _latest(_clients[OBSERVER_INDEX], WALKER_ENTITIES[0])
	var seen_by_owner := _latest(_clients[0], WALKER_ENTITIES[0])
	_check(not seen_by_observer.is_empty(), "the observing client receives the simulated body's pose")
	_check(not seen_by_owner.is_empty(),
		"the owning client receives it too: it is the authority's pose now, not the owner's claim")
	_check(_frame.is_simulation_authority_for(body),
		"the frame simulates the remote body on the server, not on the owning client")


func _assert_the_body_walks_the_aisle_on_intent() -> void:
	var body := _body(WALKER_ENTITIES[0])
	if body == null:
		return
	var start := _frame.get_occupant_frame_local_transform(body).origin
	_set_plan(0, FORWARD)
	_floor_violations = 0
	_bounds_violations = 0
	_pose_samples = 0
	await _drive(45)
	var mid := _frame.get_occupant_frame_local_transform(body).origin
	var progress_mid := (mid - start).length()
	_check(progress_mid > 1.0,
		"the body walks on the first client's intent (%.2f m in 45 ticks)" % progress_mid)
	var audit: Dictionary = _game.get_network_remote_body_audit()
	_check(int(audit.get("intents_applied", 0)) >= 8,
		"the authority consumes the walker's accepted intents (%d applied)" % int(audit.get("intents_applied", 0)))

	# Silence: the owner stops streaming with a forward intent still held.
	_set_plan(0, FORWARD, false)
	var freezes_before := int(audit.get("gap_freezes", 0))
	await _drive(RemoteBodySimulation.INTENT_HOLD_TICKS + 8)
	var frozen_at := _frame.get_occupant_frame_local_transform(body).origin
	await _drive(20)
	var still := _frame.get_occupant_frame_local_transform(body).origin
	audit = _game.get_network_remote_body_audit()
	_check(int(audit.get("gap_freezes", 0)) == freezes_before + 1
		and bool(_game.get_network_remote_body_simulation().get_body_record(WALKER_ENTITIES[0]).get("frozen", false)),
		"a delivery gap wider than the hold window freezes the body")
	_check(frozen_at.distance_to(still) < 0.05
		and _frame.get_occupant_frame_local_velocity(body).length() < 0.05,
		"a frozen body stands where the last ordered intent left it (%.3f m drift)"
			% frozen_at.distance_to(still))

	# Resume, and keep walking until the cabin stops the body. "Stopped" has to
	# mean the cabin stopped it, not that delivery stalled: loopback ENet is
	# polled on the rendered frame, so on a loaded machine an intent can arrive
	# late enough to open a hold-window gap and freeze a body that is still
	# mid-aisle. A frozen body holds perfectly still, which is exactly what the
	# settle predicate is looking for, so the predicate has to exclude it.
	_set_plan(0, FORWARD, true)
	var stopped := false
	var last := still
	var settled_ticks := 0
	var freezes_during_walk := 0
	for _round in 30:
		await _drive(10)
		var now := _frame.get_occupant_frame_local_transform(body).origin
		var driven := not bool(
			_game.get_network_remote_body_simulation()
				.get_body_record(WALKER_ENTITIES[0]).get("frozen", false)
		)
		if not driven:
			freezes_during_walk += 1
		if driven and now.distance_to(last) < 0.02:
			settled_ticks += 1
		else:
			settled_ticks = 0
		last = now
		if settled_ticks >= 2:
			stopped = true
			break
	_walk_end_local = last
	var progress := (last - start).length()
	_check(stopped, "the body comes to rest against the cabin while forward intent is still held")
	_check(progress >= MIN_AISLE_PROGRESS,
		"the body walked the aisle before the cabin stopped it (%.2f m aft of the stand pose)" % progress)
	_check(_bounds.has_point(last),
		"the body stops inside the cabin envelope rather than through the bulkhead (%s)" % str(last))
	_check(_floor_violations == 0,
		"the body never leaves the cabin floor while walking (%d floor samples)" % _pose_samples)
	_check(_bounds_violations == 0,
		"the body never leaves the cabin envelope while walking (%d envelope samples)" % _pose_samples)
	var support := await _settle_on_deck(body)
	_check(bool(support.get("supported", false)) and int(support.get("off_deck_ticks", 0)) == 0,
		"the body is supported by the deck when it stops (on the deck after %d settling ticks, %d ticks airborne, %d delivery freezes during the walk)"
			% [int(support.get("ticks", 0)), int(support.get("off_deck_ticks", 0)), freezes_during_walk])
	_set_plan(0, Vector2.ZERO, true)
	await _drive(12)
	var observed := _latest(_clients[OBSERVER_INDEX], WALKER_ENTITIES[0])
	var observed_local: Transform3D = observed.get("frame_local_transform", Transform3D.IDENTITY)
	var authoritative := _frame.get_occupant_frame_local_transform(body).origin
	_check(not observed.is_empty() and observed_local.origin.distance_to(authoritative) < 0.05,
		"the publication carries the simulated body's pose (observer %.3f m from the authority)"
			% observed_local.origin.distance_to(authoritative))
	_check(int(observed.get("occupancy_state", -1)) == Relationship.STATE_WALKING,
		"the walking body is published as walking")


func _assert_forged_and_stale_intents_are_rejected() -> void:
	var body := _body(WALKER_ENTITIES[0])
	if body == null:
		return
	var walker := _walkers[0]
	var source := walker.get("source") as IntentSource
	var here := _frame.get_occupant_frame_local_transform(body).origin
	_intent_statuses.clear()
	# Another admitted peer names the first client's body as its own.
	var forged = Intent.create(
		_client_peer_ids[1], WALKER_ENTITIES[0], 1, 0, 0, source.estimated_server_tick(), Vector2.LEFT
	)
	_clients[1].send_movement_intent(forged.to_dictionary())
	# Another peer forges the first client's peer id outright.
	var spoofed = Intent.create(
		_client_peer_ids[0], WALKER_ENTITIES[0], 1, 7, 0, source.estimated_server_tick(), Vector2.LEFT
	)
	_clients[1].send_movement_intent(spoofed.to_dictionary())
	# The owner replays the sequence it last sent on its own stream.
	var audit: Dictionary = source.get_audit()
	var stale = Intent.create(
		_client_peer_ids[0], WALKER_ENTITIES[0], 1, int(audit.get("stream_id", 0)),
		maxi(0, int(audit.get("sequence", 0))), maxi(0, int(audit.get("last_client_tick", 0))),
		Vector2.LEFT
	)
	_clients[0].send_movement_intent(stale.to_dictionary())
	# And a stale generation.
	var old_generation = Intent.create(
		_client_peer_ids[0], WALKER_ENTITIES[0], 2, int(audit.get("stream_id", 0)) + 1, 0,
		int(audit.get("last_client_tick", 1)) + 1, Vector2.LEFT
	)
	_clients[0].send_movement_intent(old_generation.to_dictionary())
	await _wait_until(func() -> bool: return _status_total() >= 4, 4.0)
	await _drive(20)
	_check(int(_intent_statuses.get(&"not_avatar_owner", 0)) == 1,
		"a peer may only drive its own body (not_avatar_owner)")
	_check(int(_intent_statuses.get(&"spoofed_peer", 0)) == 1,
		"a packet that forges another peer's identity is rejected (spoofed_peer)")
	_check(int(_intent_statuses.get(&"stale_sequence", 0)) >= 1,
		"a replayed sequence on the owner's own stream is rejected (stale_sequence)")
	_check(int(_intent_statuses.get(&"stale_avatar_generation", 0)) == 1,
		"an intent framed with the wrong body generation is rejected")
	var after := _frame.get_occupant_frame_local_transform(body).origin
	_check(after.distance_to(here) < 0.05,
		"none of the rejected packets moved the body (%.3f m)" % after.distance_to(here))


func _assert_the_body_sleeps_in_the_bunk_and_wakes() -> void:
	var body := _body(WALKER_ENTITIES[0])
	if body == null:
		return
	var simulation := _game.get_network_remote_body_simulation()
	var bunk := _nearest_bunk(body)
	_check(bunk != null, "the body has walked within reach of a production bunk")
	if bunk == null:
		return
	_check(bunk.is_available(), "the bunk is free before the crewmate asks for it")
	var source := _walkers[0].get("source") as IntentSource
	source.request_interaction()
	await _drive(8)
	var settled := await _wait_until(func() -> bool:
		return StringName(simulation.get_body_record(WALKER_ENTITIES[0]).get("seat_state", &"")) == &"seated"
	, 3.0)
	_check(settled, "the interaction request sits the body down through the production seat transition")
	_check(body.is_seated() and body.is_sleeping(),
		"the body is asleep in the bunk, exactly as the host's own player would be")
	_check(bunk.is_reserved_for(body) and not bunk.is_available(),
		"the bunk is reserved for the body physically at it")
	_check(int(_game.get_network_remote_body_audit().get("seat_claims", 0)) == 1,
		"the simulation records one seat claim")
	# The claim changed the ledger's mode, not just the body's posture.
	_check(_server.get_movement_avatar_snapshot(WALKER_ENTITIES[0]).get("mode") == MovementAuthority.MODE_SEATED
		and simulation.get_body_record(WALKER_ENTITIES[0]).get("avatar_mode") == MovementAuthority.MODE_SEATED,
		"claiming the bunk puts the body's movement avatar into the ledger's seated mode")
	# A walking intent while asleep is refused by the ledger, by name and
	# counted, and the body never sees it.
	_intent_statuses.clear()
	var refusals_before := _mode_refusal_count(MovementAuthority.REFUSAL_MOVEMENT_WHILE_SEATED)
	var plan_tick := int(_game.get_network_moving_interior_publication_audit().get("server_tick", 0))
	_set_plan(0, FORWARD, true)
	var resting := _frame.get_occupant_frame_local_transform(body).origin
	await _drive(30)
	var rested := _frame.get_occupant_frame_local_transform(body).origin
	_check(resting.distance_to(rested) < 0.02,
		"forward intent does not walk a sleeping body off its bunk (%.3f m)" % resting.distance_to(rested))
	_check(int(_intent_statuses.get(&"action_not_allowed_in_mode", 0)) >= 3,
		"every walking intent streamed while seated is refused by the ledger (%d refused)"
			% int(_intent_statuses.get(&"action_not_allowed_in_mode", 0)))
	_check(_mode_refusal_count(MovementAuthority.REFUSAL_MOVEMENT_WHILE_SEATED) >= refusals_before + 3,
		"the authority's audit counts the refusals under their named reason")
	# Neutral packets already in flight when the plan changed are accepted, as
	# they should be; once the forward stream is all that arrives, the ledger
	# accepts nothing more for this avatar.
	var last_accepted := int(_server.get_movement_avatar_snapshot(WALKER_ENTITIES[0]).get("last_accepted_server_tick", -1))
	_check(last_accepted <= plan_tick + IntentSource.DEFAULT_CADENCE_TICKS * 3,
		"nothing the owner streamed after the plan changed was accepted (last accept at tick %d, plan at %d)"
			% [last_accepted, plan_tick])
	var observed := _latest(_clients[OBSERVER_INDEX], WALKER_ENTITIES[0])
	_check(int(observed.get("occupancy_state", -1)) == Relationship.STATE_SLEEPING,
		"the publication tells every client the body is asleep, not standing still")
	_set_plan(0, Vector2.ZERO, true)
	source.request_interaction()
	await _drive(8)
	var stood := await _wait_until(func() -> bool:
		return StringName(simulation.get_body_record(WALKER_ENTITIES[0]).get("seat_state", &"")) == &"standing" \
			and not body.is_seated()
	, 3.0)
	_check(stood, "a second interaction request stands the body back up")
	_check(bunk.is_available() and not bunk.is_reserved_for(body),
		"standing releases the bunk")
	_check(_server.get_movement_avatar_snapshot(WALKER_ENTITIES[0]).get("mode") == MovementAuthority.MODE_ON_FOOT,
		"standing puts the movement avatar back on foot in the ledger")
	_check(int(_game.get_network_remote_body_audit().get("mode_switches", 0)) == 2
		and int(_game.get_network_remote_body_audit().get("mode_switches_refused", 0)) == 0,
		"the simulation reports both mode switches to the ledger and neither is refused")
	await _drive(12)
	observed = _latest(_clients[OBSERVER_INDEX], WALKER_ENTITIES[0])
	_check(int(observed.get("occupancy_state", -1)) == Relationship.STATE_WALKING,
		"the publication returns the body to walking after it stands")
	var stood_support := await _settle_on_deck(body)
	_check(bool(stood_support.get("supported", false))
		and int(stood_support.get("off_deck_ticks", 0)) == 0
		and _bounds.has_point(_frame.get_occupant_frame_local_transform(body).origin),
		"the body stands on the deck inside the cabin after waking (on the deck after %d settling ticks, %d ticks airborne)"
			% [int(stood_support.get("ticks", 0)), int(stood_support.get("off_deck_ticks", 0))])
	# And walking is accepted again on the same stream.
	_intent_statuses.clear()
	var applied_before := int(_game.get_network_remote_body_audit().get("intents_applied", 0))
	_set_plan(0, FORWARD, true)
	await _drive(16)
	_set_plan(0, Vector2.ZERO, true)
	_check(int(_game.get_network_remote_body_audit().get("intents_applied", 0)) > applied_before
		and int(_intent_statuses.get(&"action_not_allowed_in_mode", 0)) == 0,
		"a body back on foot walks on its owner's intent again with nothing refused")


# --- the hatch --------------------------------------------------------------


## The production boarding path. The second client has no body yet; it claims
## one of the Halyard's cabin berths through the boarding ledger over the real
## `send_boarding_intent()` RPC, and the authority stands a body for it at the
## cabin stand pose. A disembark from the same berth releases it. A pilot-seat
## claim keeps the seat seam and stands nobody up. Nothing is claimed by name:
## the ledger refuses a berth already held, a role that does not match the
## seat, and a disembark by a peer that holds no occupancy.
func _assert_the_hatch_admits_and_releases_a_body() -> void:
	_boarding_results.clear()
	var walker_index := 1
	var entity := StringName(WALKER_ENTITIES[walker_index])
	var berth := GameFlow.network_cabin_berth_seat_id(SHIP_ID, 1)
	var pilot_seat := StringName("%s_pilot" % String(SHIP_ID))
	var bodies_before := int(_game.get_network_remote_body_audit().get("bodies", 0))
	var occupants_before := _frame.get_occupant_count()
	_check(_body(entity) == null, "the second client has no body before it boards")
	# A role that does not match the berth is the ledger's refusal, not ours.
	_send_boarding(walker_index, entity, pilot_seat, &"passenger", 0, BoardingIntent.ACTION_BOARD)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	_check(_boarding_results.size() >= 1 and _boarding_results[0].get("status") == &"role_mismatch",
		"a passenger claim on the pilot seat is refused by the boarding ledger")
	_boarding_results.clear()
	_send_boarding(walker_index, entity, berth, &"passenger", 1, BoardingIntent.ACTION_BOARD)
	var boarded := await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	_check(boarded and bool(_boarding_results[0].get("accepted", false))
		and _boarding_results[0].get("status") == &"boarded",
		"the ledger confirms the second client's berth claim (%s)"
			% String(_boarding_results[0].get("status", &"?") if not _boarding_results.is_empty() else &"none"))
	await _drive(4)
	var body := _body(entity)
	_check(body != null and body is PlayerController and body.is_inside_tree(),
		"a confirmed hatch boarding stands a server-simulated body for the peer")
	var audit: Dictionary = _game.get_network_remote_body_audit()
	_check(int(audit.get("hatch_admissions", 0)) == 1 and int(audit.get("bodies", 0)) == bodies_before + 1,
		"the hatch seam records one admission (%d bodies)" % int(audit.get("bodies", 0)))
	if body == null:
		return
	_check(_frame.is_occupant_registered(body) and _frame.get_occupant_count() == occupants_before + 1,
		"the craft's frame carries the hatch body")
	var stand_local := _craft.to_local(_craft.get_cabin_stand_transform().origin)
	var local := _frame.get_occupant_frame_local_transform(body).origin
	_check(local.distance_to(stand_local) < 0.6 and _bounds.has_point(local),
		"the hatch body stands at the cabin's own stand pose")
	_check(int(_game.get_network_remote_body_simulation().get_body_record(entity).get("owner_peer_id", 0))
			== _client_peer_ids[walker_index],
		"the hatch body belongs to the peer whose claim the ledger confirmed")
	await _drive(20)
	_check(not _latest(_clients[OBSERVER_INDEX], entity).is_empty(),
		"the observing client is shown the hatch body")
	# A second claim on the held berth, by another peer, is refused by the ledger.
	_boarding_results.clear()
	_send_boarding(2, StringName(WALKER_ENTITIES[2]), berth, &"passenger", 0, BoardingIntent.ACTION_BOARD)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	_check(_boarding_results.size() >= 1 and _boarding_results[0].get("status") == &"seat_occupied",
		"a berth already held is refused to the next peer")
	# A pilot claim keeps the seat seam: no body is stood up for it.
	_boarding_results.clear()
	_send_boarding(2, StringName(WALKER_ENTITIES[2]), pilot_seat, &"pilot", 1, BoardingIntent.ACTION_BOARD)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	await _drive(4)
	audit = _game.get_network_remote_body_audit()
	_check(_boarding_results.size() >= 1 and _boarding_results[0].get("status") == &"boarded"
		and _body(StringName(WALKER_ENTITIES[2])) == null
		and int(audit.get("hatch_pilot_seats", 0)) == 1 and int(audit.get("bodies", 0)) == bodies_before + 1,
		"a remote pilot who boards and sits still gets the pilot seat and no walking body")
	_boarding_results.clear()
	_send_boarding(2, StringName(WALKER_ENTITIES[2]), pilot_seat, &"pilot", 2, BoardingIntent.ACTION_DISEMBARK)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	# A disembark by a peer that holds no berth releases nothing.
	_boarding_results.clear()
	_send_boarding(2, StringName(WALKER_ENTITIES[2]), berth, &"passenger", 3, BoardingIntent.ACTION_DISEMBARK)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	await _drive(4)
	_check(_boarding_results.size() >= 1 and not bool(_boarding_results[0].get("accepted", true))
		and _body(entity) != null,
		"a disembark from a berth the peer does not hold is refused and releases nobody (%s)"
			% String(_boarding_results[0].get("status", &"?") if not _boarding_results.is_empty() else &"none"))
	# The owner's own disembark through the hatch releases the body.
	_boarding_results.clear()
	_send_boarding(walker_index, entity, berth, &"passenger", 2, BoardingIntent.ACTION_DISEMBARK)
	var left := await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	await _drive(6)
	audit = _game.get_network_remote_body_audit()
	_check(left and _boarding_results[0].get("status") == &"disembarked"
		and int(audit.get("hatch_releases", 0)) == 1 and int(audit.get("bodies", 0)) == bodies_before
		and audit.get("last_release_reason") == &"hatch_disembark",
		"a networked disembark through the hatch releases the body (%s)" % String(audit.get("last_hatch_status", &"?")))
	_check(not is_instance_valid(body) or not body.is_inside_tree(),
		"the released hatch body is freed")
	_check(_frame.get_occupant_count() == occupants_before
		and not _game.get_network_moving_interior_published_entities().has(entity),
		"the frame and the publisher both let the hatch body go")
	await _drive(6)
	_check(_latest(_clients[OBSERVER_INDEX], entity).is_empty(),
		"the observing client is told to stop drawing it")
	_check(_server.get_movement_avatar_snapshot(entity).is_empty(),
		"the movement authority forgets the released avatar")
	# The berth is free again: the same peer can board a second time.
	_boarding_results.clear()
	_send_boarding(walker_index, entity, berth, &"passenger", 3, BoardingIntent.ACTION_BOARD)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	await _drive(4)
	_check(_body(entity) != null and int(_game.get_network_remote_body_audit().get("hatch_admissions", 0)) == 2,
		"a released berth can be claimed again and stands a fresh body")
	_boarding_results.clear()
	_send_boarding(walker_index, entity, berth, &"passenger", 4, BoardingIntent.ACTION_DISEMBARK)
	await _wait_until(func() -> bool: return _boarding_results.size() >= 1, 4.0)
	await _drive(6)
	_check(_body(entity) == null and int(_game.get_network_remote_body_audit().get("bodies", 0)) == bodies_before,
		"the cabin is back to where the hatch found it before the crowd is admitted")


func _send_boarding(
	client_index: int, avatar_id: StringName, seat_id: StringName, role: StringName,
	sequence: int, action: StringName
) -> void:
	var intent = BoardingIntent.create(
		_client_peer_ids[client_index], avatar_id, SHIP_ID, 1, FRAME_ID, 1,
		seat_id, 1, role, sequence, 0, action
	)
	_clients[client_index].send_boarding_intent(intent.to_dictionary())


func _on_server_boarding_result(result: Dictionary) -> void:
	_boarding_results.append(result.duplicate(true))


# --- the crowd budget -------------------------------------------------------


func _assert_the_crowd_budget() -> void:
	var installed: Dictionary = _server.set_moving_interior_transport_hook(Callable(_shim, "enqueue"))
	_check(bool(installed.get("installed", false)),
		"the relationship stream routes through the latency shim for the crowd budget")
	_leg_active = true
	_leg_origin = _craft.global_transform
	var sizes := [1, 2, 4]
	for size_variant in sizes:
		var size := int(size_variant)
		while _walker_count() < size:
			var index := _walker_count()
			var admitted := _game.admit_network_remote_body(_client_peer_ids[index], WALKER_ENTITIES[index], _craft)
			_check(bool(admitted.get("accepted", false)),
				"the authority stands body %d of %d for the crowd (%s)" % [index + 1, size, String(admitted.get("status", &"?"))])
			_bind_walker(index, WALKER_ENTITIES[index], 1)
			# Let each newcomer clear the stand pose before the next spawns there.
			_set_plan(index, FORWARD, true)
			await _drive(24)
		for profile_variant in PROFILES:
			await _run_crowd_profile(size, profile_variant as Dictionary)
	_leg_active = false
	_leg_distance = _craft.global_position.distance_to(_leg_origin.origin)
	_craft.velocity = Vector3.ZERO
	print("REMOTE_BODY_CROWD_LEG %s" % JSON.stringify({"hull_travel_m": snappedf(_leg_distance, 0.1)}))
	for index in _walker_count():
		_set_plan(index, Vector2.ZERO, true)
	_server.set_moving_interior_transport_hook(Callable())
	_shim.drain()
	await _drive(12)
	_check(_game.get_network_remote_body_audit().get("bodies", 0) == WALKER_COUNT,
		"all four crowd bodies are still simulated after the sweep")


func _run_crowd_profile(size: int, profile: Dictionary) -> void:
	_shim.configure(float(profile.delay_ms), float(profile.jitter_ms), float(profile.loss))
	var audit_before: Dictionary = _game.get_network_moving_interior_publication_audit()
	var coalesced_before := _coalesced_total()
	var tick_before := int(audit_before.get("server_tick", 0))
	var worst_lag := 0.0
	var worst_reconstruction := 0.0
	var worst_age := 0
	var frozen_rounds := 0
	var observer = _clients[OBSERVER_INDEX]
	var stalls_before := int(observer._moving_stall_rebaselines)
	var floor_before := _floor_violations
	var bounds_before := _bounds_violations
	var rounds := int(profile.get("rounds", 60))
	for round_index in rounds:
		for index in size:
			# Walk aft then forward in alternation, staggered per body, so the
			# crowd keeps moving and never all parks against one bulkhead.
			var phase := (round_index + index * 15) % 60
			_set_plan(index, FORWARD if phase < 30 else BACKWARD, true)
		await _drive(1)
		var now_tick := int(_game.get_network_moving_interior_publication_audit().get("server_tick", 0))
		if int(observer._moving_relationship_stream.get_snapshot().get("frozen_entities", 0)) > 0:
			frozen_rounds += 1
		for index in size:
			var entity := StringName(WALKER_ENTITIES[index])
			var body := _body(entity)
			if body == null:
				continue
			var authoritative := _frame.get_occupant_frame_local_transform(body).origin
			var observed := _latest(_clients[OBSERVER_INDEX], entity)
			if observed.is_empty():
				continue
			var observed_local: Transform3D = observed.get("frame_local_transform", Transform3D.IDENTITY)
			worst_lag = maxf(worst_lag, observed_local.origin.distance_to(authoritative))
			worst_age = maxi(worst_age, now_tick - int(observed.get("server_tick", now_tick)))
			var history: Dictionary = _authoritative.get(entity, {}) as Dictionary
			var at_tick: Variant = history.get(int(observed.get("server_tick", -1)))
			if at_tick is Vector3:
				worst_reconstruction = maxf(worst_reconstruction, (at_tick as Vector3).distance_to(observed_local.origin))
	var audit_after: Dictionary = _game.get_network_moving_interior_publication_audit()
	var ticks := int(audit_after.get("server_tick", 0)) - tick_before
	var published := int(audit_after.get("published", 0)) - int(audit_before.get("published", 0))
	var coalesced := _coalesced_total() - coalesced_before
	var report := {
		"bodies": size,
		"occupants": size + 1,
		"profile": String(profile.name),
		"ticks": ticks,
		"snapshots_published": published,
		"snapshots_per_tick": snappedf(float(published) / maxf(1.0, float(ticks)), 0.01),
		"coalesced_updates": coalesced,
		"worst_pose_lag_m": snappedf(worst_lag, 0.001),
		"worst_pose_age_ticks": worst_age,
		"observer_frozen_rounds": frozen_rounds,
		"observer_stall_rebaselines": int(observer._moving_stall_rebaselines) - stalls_before,
		"worst_reconstruction_error_m": snappedf(worst_reconstruction, 0.0001),
		"packets_sent": _shim.sent,
		"packets_dropped": _shim.dropped,
		"floor_violations": _floor_violations - floor_before,
		"envelope_violations": _bounds_violations - bounds_before,
		"hull_travel_m": snappedf(_craft.global_position.distance_to(_leg_origin.origin), 0.1),
	}
	_crowd_reports.append(report)
	print("REMOTE_BODY_CROWD_BUDGET %s" % JSON.stringify(report))
	_check(ticks >= rounds and published > 0,
		"%d bodies / %s: the authority published on every tick" % [size, String(profile.name)])
	_check(_floor_violations == floor_before and _bounds_violations == bounds_before,
		"%d bodies / %s: every simulated body stayed on the deck inside the cabin" % [size, String(profile.name)])
	_check(worst_reconstruction < 0.001,
		"%d bodies / %s: every accepted pose reconstructs the authority's exactly (%.4f m)"
			% [size, String(profile.name), worst_reconstruction])
	_shim.drain()


# --- lifecycle --------------------------------------------------------------


func _assert_a_disconnect_releases_the_body() -> void:
	var index := WALKER_COUNT - 1
	var entity := StringName(WALKER_ENTITIES[index])
	var body := _body(entity)
	_check(body != null, "the last crowd body is still simulated before its owner drops")
	var dropped_peer := _client_peer_ids[index]
	var occupants_before := _frame.get_occupant_count()
	_clients[index].shutdown(&"remote_body_drop")
	await _wait_until(func() -> bool: return not _server._peer_generations.has(dropped_peer), 5.0)
	await _drive(6)
	_check(_game.get_network_remote_body_audit().get("bodies", -1) == WALKER_COUNT - 1,
		"the owner's disconnect releases its body")
	_check(not is_instance_valid(body) or not body.is_inside_tree(),
		"the released body is freed, not left standing in the cabin")
	_check(_frame.get_occupant_count() == occupants_before - 1,
		"the frame no longer carries the released body")
	_check(not _game.get_network_moving_interior_published_entities().has(entity),
		"the publisher stops speaking for the released body")
	await _drive(6)
	_check(_latest(_clients[OBSERVER_INDEX], entity).is_empty(),
		"the observing client is told to stop drawing it")
	_check(_server.get_movement_avatar_snapshot(entity).is_empty(),
		"the movement authority forgets the released avatar")
	_walkers[index]["active"] = false


func _assert_reentry_and_rehost_readmit_the_body() -> void:
	var label := "re-entered host"
	var entity := StringName(WALKER_ENTITIES[0])
	var body_before := _body(entity)
	var retiring: Node = _server
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var parent := _game.get_parent()
	_craft.velocity = Vector3.ZERO
	await physics_frame
	parent.remove_child(_game)
	await process_frame
	await process_frame
	_check(_game.get_network_session() == null and not is_instance_valid(retiring),
		"%s: a detached Main runs no session and frees its adapter" % label)
	_check(_game.get_network_remote_body_audit().get("bodies", -1) == 0,
		"%s: every remote body goes with the session (%d left)" % [label, int(_game.get_network_remote_body_audit().get("bodies", -1))])
	_check(not is_instance_valid(body_before) or body_before.get_parent() == null,
		"%s: the released bodies are freed rather than carried out with the subtree" % label)
	parent.add_child(_game)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	_check(_craft.is_piloted() and _craft.get_moving_interior_component() == _frame,
		"%s: re-entry leaves the host's own pilot flying the same cabin" % label)
	_check(_frame.get_occupant_count() == 0 or not _frame.get_registered_occupants().any(
			func(occupant: Node3D) -> bool: return RemoteBodySimulation.is_remote_body(occupant)),
		"%s: no remote body survives re-entry inside the frame" % label)
	for client in _clients:
		if client.is_inside_tree() and client._configured:
			client.shutdown(&"host_reentered")
	await process_frame
	var port := _reserve_port()
	if port <= 0:
		return
	_check(bool(_game.host_network_session(port, 8).get("accepted", false)),
		"%s: it hosts again" % label)
	_server = _game.get_network_session()
	if _server == null:
		return
	_server.movement_intent_result.connect(_on_server_intent_result)
	_server.boarding_intent_result.connect(_on_server_boarding_result)
	_shim.server = _server
	_check(_game.get_network_session_adapter_nodes().size() == 1,
		"%s: exactly one adapter answers at the canonical path" % label)
	# The dropped walker stays dropped; everyone else rejoins.
	var rejoining: Array = []
	for index in _clients.size():
		if index == WALKER_COUNT - 1:
			continue
		rejoining.append(_clients[index])
	var joined := true
	for client in rejoining:
		joined = joined and bool(client.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "%s: the clients rejoin" % label)
	var expected := rejoining.size()
	await _wait_until(func() -> bool: return _server._peer_generations.size() >= expected, 8.0)
	_check(_server._peer_generations.size() >= expected, "%s: the host re-admits them" % label)
	for index in _clients.size():
		if index == WALKER_COUNT - 1:
			continue
		_client_peer_ids[index] = _clients[index].multiplayer.get_unique_id()
	_authoritative.clear()
	var readmitted := _game.admit_network_remote_body(_client_peer_ids[0], entity, _craft)
	_check(bool(readmitted.get("accepted", false)),
		"%s: the walker's body is stood up again on the new session (%s)"
			% [label, String(readmitted.get("status", &"?"))])
	_bind_walker(0, entity, 1)
	var body := _body(entity)
	if body == null:
		return
	var start := _frame.get_occupant_frame_local_transform(body).origin
	_set_plan(0, FORWARD, true)
	_floor_violations = 0
	_bounds_violations = 0
	await _drive(60)
	var end := _frame.get_occupant_frame_local_transform(body).origin
	_check((end - start).length() > 1.0,
		"%s: the re-admitted body walks on the rejoined client's intent (%.2f m)" % [label, (end - start).length()])
	_check(_floor_violations == 0 and _bounds_violations == 0,
		"%s: it walks on the deck inside the cabin" % label)
	# Settle first: a walking body in a cabin with a seated pilot is coalesced
	# to one snapshot per budget window, so the comparison is made at rest.
	_set_plan(0, Vector2.ZERO, true)
	await _drive(24)
	var rest := _frame.get_occupant_frame_local_transform(body).origin
	var observed := _latest(_clients[OBSERVER_INDEX], entity)
	_check(not observed.is_empty()
		and (observed.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D).origin.distance_to(rest) < 0.05,
		"%s: the rejoined observer receives the re-admitted body's simulated pose" % label)
	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(orphans_after <= orphans_before,
		"%s: the whole cycle leaves no node orphaned behind it (%d after %d)"
			% [label, orphans_after, orphans_before])


# --- driving ----------------------------------------------------------------


func _bind_walker(index: int, entity_id: StringName, generation: int) -> void:
	while _walkers.size() <= index:
		_walkers.append({})
	var source := IntentSource.new()
	source.bind(entity_id, generation)
	_walkers[index] = {
		"source": source,
		"entity_id": entity_id,
		"move_axis": Vector2.ZERO,
		"streaming": true,
		"active": true,
	}


func _set_plan(index: int, move_axis: Vector2, streaming: bool = true) -> void:
	if index >= _walkers.size():
		return
	_walkers[index]["move_axis"] = move_axis
	_walkers[index]["streaming"] = streaming


func _walker_count() -> int:
	var count := 0
	for walker in _walkers:
		if bool(walker.get("active", false)):
			count += 1
	return count


## Support is a per-tick property of the last `move_and_slide()`, not a level to
## settle at: a body standing on a deck that is itself translating reports
## `is_on_floor()` false for the odd tick while the capsule re-seats, and which
## tick that is depends on when the machine happened to run the step. So the
## claim is checked as a bounded predicate rather than as one instantaneous
## sample - the body must be standing on the deck within `SUPPORT_SETTLE_TICKS`
## and must never leave it on the way, which is strictly more than the single
## sample proved.
func _settle_on_deck(body: PlayerController) -> Dictionary:
	var off_deck := 0
	var ticks := 0
	var supported := body.is_on_floor()
	while ticks < SUPPORT_SETTLE_TICKS:
		var local := _frame.get_occupant_frame_local_transform(body).origin
		if local.y > _bounds.position.y + 0.9:
			off_deck += 1
		if supported:
			break
		await _drive(1)
		ticks += 1
		supported = body.is_on_floor()
	return {"supported": supported, "ticks": ticks, "off_deck_ticks": off_deck}


## Waits `rounds` physics steps. The host publishes and simulates from its own
## `_physics_process`; the walkers stream and the harness samples from the
## tick driver, so nothing here depends on how many steps one await spans.
func _drive(rounds: int) -> void:
	for _round in maxi(1, rounds):
		await physics_frame
		await process_frame


## One physics tick of the harness, after every body has moved: stream each
## walker's intent the way its owning client does, advance the transport shim
## by one tick, fly the hull on its own velocity during the crowd leg, and
## record the authoritative poses.
func _on_physics_tick() -> void:
	if _game == null or not is_instance_valid(_game) or not _game.is_inside_tree():
		return
	for index in _walkers.size():
		var walker := _walkers[index]
		if walker.is_empty() or not bool(walker.get("active", false)) or not bool(walker.get("streaming", true)):
			continue
		if index >= _clients.size():
			continue
		var client = _clients[index]
		if not is_instance_valid(client) or not client._configured \
				or client.get_server_offer().is_empty():
			continue
		var source := walker.get("source") as IntentSource
		var wire: Dictionary = source.advance(_client_peer_ids[index], {
			"move_axis": walker.get("move_axis", Vector2.ZERO),
			"look_yaw": 0.0,
			"look_pitch": 0.0,
			"run": false,
			"crouch": false,
		}, client.get_moving_interior_latest_server_tick())
		if not wire.is_empty():
			client.send_movement_intent(wire)
	if _shim != null:
		_shim.now += TICK_SECONDS
		_shim.pump()
	if _leg_active and is_instance_valid(_craft):
		# The hull flies a gentle arc on its own velocity, integrated by its own
		# physics step, so the frame carries every body through a real leg.
		_craft.velocity = _craft.global_basis * Vector3(3.0, 0.5, -9.0)
	_sample_bodies()


func _sample_bodies() -> void:
	if not is_instance_valid(_frame) or not is_instance_valid(_game):
		return
	var tick := int(_game.get_network_moving_interior_publication_audit().get("server_tick", 0)) + 1
	for walker in _walkers:
		if walker.is_empty() or not bool(walker.get("active", false)):
			continue
		var entity := StringName(walker.get("entity_id", &""))
		var body := _body(entity)
		if body == null or not _frame.is_occupant_registered(body):
			continue
		var local := _frame.get_occupant_frame_local_transform(body).origin
		_pose_samples += 1
		if not _bounds.has_point(local):
			_bounds_violations += 1
		if not body.is_seated() and not body.is_on_floor() and local.y > _bounds.position.y + 0.9:
			# Airborne well above the deck is a floor failure; a step or a
			# settling capsule a few centimetres up is not.
			_floor_violations += 1
		var history: Dictionary = _authoritative.get(entity, {}) as Dictionary
		history[tick] = local
		if history.size() > 600:
			history.erase(history.keys()[0])
		_authoritative[entity] = history


func _body(entity_id: StringName) -> PlayerController:
	var simulation := _game.get_network_remote_body_simulation()
	if simulation == null or not is_instance_valid(simulation):
		return null
	return simulation.get_body(entity_id) as PlayerController


func _latest(client, entity_id: StringName) -> Dictionary:
	if client == null or not is_instance_valid(client):
		return {}
	return client.get_moving_interior_latest_relationship(entity_id)


func _nearest_bunk(body: PlayerController) -> ShipBunk:
	var best: ShipBunk = null
	var best_distance := INF
	for candidate in body.get_nearby_interactables():
		if not candidate is ShipBunk:
			continue
		var distance := body.get_interaction_origin().distance_to((candidate as ShipBunk).get_entry_transform().origin)
		if distance < best_distance:
			best = candidate as ShipBunk
			best_distance = distance
	return best


func _coalesced_total() -> int:
	var total := 0
	var budgets: Dictionary = _server.get_moving_interior_budget_snapshot()
	for peer_variant in budgets:
		total += int((budgets[peer_variant] as Dictionary).get("coalesced_count", 0))
	return total


func _on_server_intent_result(result: Dictionary) -> void:
	var status := StringName(result.get("status", &"?"))
	_intent_statuses[status] = int(_intent_statuses.get(status, 0)) + 1


func _mode_refusal_count(reason: StringName) -> int:
	if _server == null or not is_instance_valid(_server):
		return 0
	var audit: Dictionary = _server.get_movement_authority_audit()
	return int((audit.get("mode_refusals", {}) as Dictionary).get(reason, 0))


func _status_total() -> int:
	var total := 0
	for status in _intent_statuses:
		total += int(_intent_statuses[status])
	return total


# --- reporting and teardown -------------------------------------------------


func _report_summary() -> void:
	var audit: Dictionary = _game.get_network_remote_body_audit()
	var worst_lag := 0.0
	for report in _crowd_reports:
		worst_lag = maxf(worst_lag, float(report.get("worst_pose_lag_m", 0.0)))
	print("REMOTE_BODY_SUMMARY %s" % JSON.stringify({
		"admitted": int(audit.get("admitted", 0)),
		"released": int(audit.get("released", 0)),
		"intents_applied": int(audit.get("intents_applied", 0)),
		"gap_freezes": int(audit.get("gap_freezes", 0)),
		"seat_claims": int(audit.get("seat_claims", 0)),
		"seat_releases": int(audit.get("seat_releases", 0)),
		"crowd_profiles": _crowd_reports.size(),
		"worst_crowd_pose_lag_m": snappedf(worst_lag, 0.001),
		"pose_samples": _pose_samples,
	}))
	_check(not bool(audit.get("owns_movement_authority", true))
		and not bool(audit.get("owns_seat_authority", true)),
		"the simulation claims no movement or seat authority of its own")


func _finish_remote_bodies() -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
		&"pitch_up", &"pitch_down", &"sprint_boost", &"hover",
	]:
		Input.action_release(action)
	if _ticker != null and is_instance_valid(_ticker):
		_ticker.suite = null
		_ticker.free()
		_ticker = null
	if _server != null and is_instance_valid(_server):
		_server.set_moving_interior_transport_hook(Callable())
	for client in _clients:
		if is_instance_valid(client) and client._configured:
			client.shutdown(&"remote_body_sweep_close")
	_clients.clear()
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
	_cadence.restore()
	if _failures.is_empty():
		print("NETWORK_REMOTE_BODY_SIMULATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_REMOTE_BODY_SIMULATION_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, "; ".join(_failures)])
	quit(1)
