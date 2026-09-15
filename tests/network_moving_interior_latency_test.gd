extends SceneTree

## Moving-interior stability under transport latency, jitter, reordering, loss
## and a hard stall, driven through the real ENet session in-process.
##
## The suite is named `network_*` on purpose: `tools/release/run_test_matrix.sh`
## marks a suite as a network suite when its path is `tests/network/*` or
## `tests/network_*`, and only marked suites take the per-run flock lane. This
## suite creates real `ENetMultiplayerPeer` sockets, so it has to take that lane.
##
## What is real here:
##   * `res://scenes/main.tscn` runs on the server side, so the moving frame is
##     the production `HalyardCrewTransport` with its own `MovingInteriorFrame`
##     and published `INTERIOR_BOUNDS`, and the server's own player is the
##     production `PlayerController`.
##   * One server and two clients each own a real `NetworkEnetSessionAdapter`
##     on its own `SceneMultiplayer` branch, connected over loopback ENet.
##   * Seat claims, transfers, occupancy, publication, budget framing, the
##     per-recipient ordering buffer, the relationship stream and the replica are
##     the production scripts; nothing is stubbed.
##
## What the harness adds: a test-only transport shim installed through
## `NetworkEnetSessionAdapter.set_moving_interior_transport_hook()`. The hook is
## unset in production (one `Callable.is_null()` per published packet) and it can
## only hold back, re-order or drop a packet the server already decided to send,
## on the relationship stream alone. It is not an authority seam: every packet it
## releases goes back through the same authority RPC.
##
## The shim runs on a simulated clock advanced one 60 Hz tick per round, so the
## measured profiles do not depend on how fast the host machine happens to be.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const TICK_SECONDS := 1.0 / 60.0
const PILOT_ENTITY: StringName = &"pilota"
const CREW_ENTITY: StringName = &"crewb"
const FRAME_ID: StringName = &"halyardframe"
const SHIP_ID: StringName = &"halyard"
const SEAT_ID: StringName = &"halyardpilot"

## Documented replica bounds, mirrored from the production construction in
## `NetworkEnetSessionAdapter._init()`:
##     MovingInteriorReplica.new(AUTHORITY_PEER_ID, 2, 0.0, 0.25, 8.0)
## The replica's timeline is the server tick axis, so the extrapolation horizon
## is 0.25 tick-steps of the published linear velocity and the teleport
## tolerance is 8 m of frame-local displacement between accepted samples.
const MAX_HOLD_TICKS := 2
const EXTRAPOLATION_HORIZON_TICKS := 0.25
const TELEPORT_TOLERANCE_METRES := 8.0
## Frame-local reconstruction is exact by contract: the wire carries the pose in
## the cabin's own coordinates, so latency may cost lag but never distortion.
const RECONSTRUCTION_TOLERANCE_METRES := 0.0005

## Walk and seat poses are frame-local metres inside the Halyard cabin. The
## walking crew member moves at an ordinary 2.7 m/s, one 60 Hz step per
## published tick, so the distances in the report are the distances a player
## would actually cover in the cabin over the sweep.
const WALK_SPEED := 2.7
const WALK_FLOOR_Y := 0.95
const AISLE_APPROACH_METRES := 6.0
const SEAT_LOCAL := Vector3(0.0, 1.05, -10.4)

## Each round publishes one relationship per tracked entity. Budget windows are
## keyed on a logical tick that advances a whole window per round, so the
## per-recipient budget never coalesces the sweep's own traffic away; the
## published `server_tick` still advances by one so the relationship stream sees
## a real, gap-free tick sequence.
const BUDGET_TICKS_PER_ROUND := 10

const PROFILES := [
	{"name": "clean", "delay_ms": 0.0, "jitter_ms": 0.0, "loss": 0.0, "rounds": 60, "stall_ticks": 0},
	{"name": "lan", "delay_ms": 80.0, "jitter_ms": 20.0, "loss": 0.0, "rounds": 180, "stall_ticks": 0},
	{"name": "regional", "delay_ms": 200.0, "jitter_ms": 60.0, "loss": 0.0, "rounds": 90, "stall_ticks": 0},
	{"name": "intercontinental", "delay_ms": 350.0, "jitter_ms": 120.0, "loss": 0.02, "rounds": 90, "stall_ticks": 0},
	{"name": "stall", "delay_ms": 80.0, "jitter_ms": 20.0, "loss": 0.0, "rounds": 150, "stall_ticks": 90},
]

var _failures: Array[String] = []
var _assertions := 0

var _game: Node = null
var _craft: Node3D = null
var _frame_component: Node = null
var _server_player: Node3D = null
var _interior_bounds := AABB()

var _branches: Array[SubViewport] = []
var _adapters: Array = []
var _server
var _clients: Array = []
var _client_peer_ids: Array[int] = []
var _shim: TransportShim = null

var _server_tick := 0
var _budget_tick := 0
var _authoritative: Dictionary = {}
var _tracked: Dictionary = {}
var _status_counts: Array[Dictionary] = []
var _generation_floor: Array[int] = []
var _revision_floor: Array[int] = []
var _profile_reports: Array[Dictionary] = []

var _leg_angle := 0.0
var _leg_origin := Transform3D.IDENTITY
var _server_player_origin := Vector3.ZERO
var _bunk_local := Vector3(0.0, WALK_FLOOR_Y, 6.4)
## Seat requests carry per-occupant monotonic sequences; replays are rejected.
var _sequence := 1


## Test-only transport shim. It never inspects or rewrites a relationship: it
## decides only when (or whether) an already-published packet reaches the peer.
class TransportShim extends RefCounted:
	var server = null
	var rng := RandomNumberGenerator.new()
	var now := 0.0
	var delay := 0.0
	var jitter := 0.0
	var loss := 0.0
	var stalled := false
	var queue: Array = []
	var sent := 0
	var dropped := 0
	var delivered := 0
	var reordered := 0
	var _last_revision: Dictionary = {}

	func configure(p_delay_ms: float, p_jitter_ms: float, p_loss: float) -> void:
		delay = p_delay_ms / 1000.0
		jitter = p_jitter_ms / 1000.0
		loss = p_loss
		sent = 0
		dropped = 0
		delivered = 0
		reordered = 0

	func enqueue(peer_id: int, wire: Dictionary) -> void:
		sent += 1
		if stalled:
			dropped += 1
			return
		if loss > 0.0 and rng.randf() < loss:
			dropped += 1
			return
		var wobble := rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0
		queue.append({
			"peer_id": peer_id,
			"wire": wire,
			"at": now + maxf(0.0, delay + wobble),
		})

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
			var peer_id := int(item.get("peer_id", 0))
			var wire := item.get("wire", {}) as Dictionary
			var revision := int(wire.get("revision", 0))
			if revision < int(_last_revision.get(peer_id, 0)):
				reordered += 1
			else:
				_last_revision[peer_id] = revision
			delivered += 1
			if server != null:
				server.deliver_moving_interior_wire_packet(peer_id, wire)

	func drain() -> void:
		now += 60.0
		pump()

	func forget_peer(peer_id: int) -> void:
		_last_revision.erase(peer_id)
		var held: Array = []
		for item_variant in queue:
			if int((item_variant as Dictionary).get("peer_id", 0)) != peer_id:
				held.append(item_variant)
		queue = held


func _initialize() -> void:
	await process_frame
	await _run()


func _run() -> void:
	if not await _build_world():
		await _finish()
		return
	if not await _build_session():
		await _finish()
		return
	await _board_the_halyard()
	for profile_variant in PROFILES:
		await _run_profile(profile_variant as Dictionary)
	await _assert_disconnect_releases_a_seat()
	_report_summary()
	await _finish()


# --- world and session ------------------------------------------------------


func _build_world() -> bool:
	_game = MAIN_SCENE.instantiate()
	if _game == null:
		_fail("production scene instantiates for the latency sweep")
		return false
	root.add_child(_game)
	await process_frame
	await physics_frame
	_craft = _game.get_node_or_null("HalyardCrewTransport") as Node3D
	_server_player = _game.get_node_or_null("Player") as Node3D
	_check(_craft != null and _server_player != null,
		"the production Main subtree supplies the Halyard and the server's own player")
	if _craft == null or _server_player == null:
		return false
	if _game.has_method("start_shift"):
		_game.start_shift()
	await process_frame
	await physics_frame
	_frame_component = _craft.get_moving_interior_component()
	_interior_bounds = _craft.get_interior_bounds()
	_check(_frame_component != null and _interior_bounds.size.length() > 1.0,
		"the Halyard publishes a real moving-interior frame and walkable bounds")
	_leg_origin = _craft.global_transform
	_server_player_origin = _server_player.global_position
	_resolve_bunk_pose()
	return _frame_component != null


## The bunk the sleeping crew member lies on is the production `ShipBunk` node
## inside the Halyard's own walkable interior, expressed in the cabin's frame.
func _resolve_bunk_pose() -> void:
	var bunk := _craft.get_node_or_null(
		"WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction"
	)
	if bunk == null or not bunk.has_method("get_seat_anchor"):
		_fail("the Halyard still publishes a physical bunk for the in-flight sleep beat")
		return
	var anchor := bunk.get_seat_anchor() as Node3D
	if anchor == null:
		_fail("the Halyard bunk still publishes a seat anchor")
		return
	var candidate := _craft.to_local(anchor.global_position)
	candidate.y = maxf(candidate.y, _interior_bounds.position.y + 0.3)
	_check(_interior_bounds.has_point(candidate),
		"the production bunk anchor resolves inside the published cabin bounds")
	if _interior_bounds.has_point(candidate):
		_bunk_local = candidate


func _build_session() -> bool:
	for branch_name in ["LatencyServer", "LatencyClientA", "LatencyClientB"]:
		var branch := SubViewport.new()
		branch.name = branch_name
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		_branches.append(branch)
		var adapter := Adapter.new()
		adapter.name = "Session"
		branch.add_child(adapter)
		_adapters.append(adapter)
	_server = _adapters[0]
	_clients = [_adapters[1], _adapters[2]]
	for index in _clients.size():
		_status_counts.append({})
		_generation_floor.append(0)
		_revision_floor.append(0)
		var client = _clients[index]
		client.moving_interior_result.connect(_on_client_moving_result.bind(index))
	_shim = TransportShim.new()
	_shim.rng.seed = 0x5EA7_1A7E
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_fail("reserve a loopback UDP port for the latency sweep")
		return false
	var port := probe.get_local_port()
	probe.stop()
	_check(bool(_server.host(port, 4).get("accepted", false)), "host a real ENet session for the sweep")
	var joined := true
	for client in _clients:
		joined = joined and bool(client.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "two clients join the real session over loopback")
	# A client holding the server offer is not yet an admitted peer on the
	# server: publication and seat claims are refused until the server itself
	# has recorded the peer generation.
	await _pump(func() -> bool:
		for client in _clients:
			if client.get_server_offer().is_empty():
				return false
		return _server._peer_generations.size() >= _clients.size()
	)
	_client_peer_ids = []
	for client in _clients:
		_client_peer_ids.append(client.multiplayer.get_unique_id())
	var admitted := true
	for peer_id in _client_peer_ids:
		admitted = admitted and _server._peer_generations.has(peer_id)
	_check(admitted, "the server admits both clients before any authority call")
	_check(_client_peer_ids[0] > 1 and _client_peer_ids[1] > 1 and _client_peer_ids[0] != _client_peer_ids[1],
		"both clients are admitted with distinct peer identities")
	_shim.server = _server
	var installed: Dictionary = _server.set_moving_interior_transport_hook(Callable(_shim, "enqueue"))
	_check(bool(installed.get("installed", false)), "the relationship stream routes through the test transport shim")
	return not _client_peer_ids.is_empty()


func _board_the_halyard() -> void:
	_check(bool(_server.register_owned_ship(SHIP_ID, 1, _client_peer_ids[0]).get("accepted", false)),
		"the server hands the Halyard to the first client")
	_check(bool(_server.register_moving_interior_frame(FRAME_ID, 1).get("accepted", false)),
		"the server registers the Halyard's moving-interior frame")
	_check(bool(_server.register_crew_seat(SEAT_ID, SHIP_ID, &"pilot", FRAME_ID, 1).get("accepted", false)),
		"the server registers the Halyard pilot seat against that frame")
	var claim: Dictionary = _server.claim_crew_seat(_client_peer_ids[0], PILOT_ENTITY, SEAT_ID, &"pilot", 1)
	var claim_relationship := claim.get("moving_interior_relationship", {}) as Dictionary
	_check(bool(claim.get("accepted", false))
		and StringName(claim_relationship.get("parent_frame_id", &"")) == FRAME_ID
		and int(claim_relationship.get("parent_frame_generation", 0)) == 1,
		"the first client's pilot claim is tied to one moving-interior frame generation")
	_check(bool(_server.register_moving_interior_occupancy(
			_client_peer_ids[1], CREW_ENTITY, 1, FRAME_ID, 1).get("accepted", false)),
		"the second client is registered as a walking occupant of the same frame")
	_tracked = {
		PILOT_ENTITY: {"peer_id": _client_peer_ids[0], "generation": 1},
		CREW_ENTITY: {
			"peer_id": _client_peer_ids[1],
			"generation": 1,
			"local_origin": _aisle_start(),
			"walk_target": _aisle_start(),
			"walk_distance": 0.0,
		},
	}
	_check(bool(_server.register_moving_interior_occupancy(
			_client_peer_ids[0], PILOT_ENTITY, 1, FRAME_ID, 1).get("accepted", false)),
		"the seated pilot is an occupant of the frame it claimed")


# --- the sweep --------------------------------------------------------------


func _run_profile(profile: Dictionary) -> void:
	var name := String(profile.get("name", "?"))
	var rounds := int(profile.get("rounds", 32))
	var stall_ticks := int(profile.get("stall_ticks", 0))
	var stall_start := int(rounds / 4)
	_shim.configure(
		float(profile.get("delay_ms", 0.0)),
		float(profile.get("jitter_ms", 0.0)),
		float(profile.get("loss", 0.0))
	)
	var measurement := {
		"max_reconstruction_error_m": 0.0,
		"max_presentation_lag_m": 0.0,
		"max_extrapolation_m": 0.0,
		"max_sample_step_m": 0.0,
		"frozen_rounds": 0,
		"samples": 0,
	}
	var last_sampled: Dictionary = {}
	var stalled_this_profile := false
	for round_index in rounds:
		if stall_ticks > 0:
			var inside := round_index >= stall_start and round_index < stall_start + stall_ticks
			if inside and not _shim.stalled:
				_shim.stalled = true
				stalled_this_profile = true
			elif not inside and _shim.stalled:
				_shim.stalled = false
		await _drive_round(name, round_index)
		_measure_round(measurement, last_sampled)
		await _profile_event(name, round_index, rounds)
	_shim.stalled = false
	_shim.drain()
	await _settle()
	_measure_round(measurement, last_sampled)
	var report := {
		"LATENCY_PROFILE": name,
		"one_way_delay_ms": float(profile.get("delay_ms", 0.0)),
		"jitter_ms": float(profile.get("jitter_ms", 0.0)),
		"loss_ratio": float(profile.get("loss", 0.0)),
		"stall_seconds": snappedf(float(stall_ticks) * TICK_SECONDS, 0.01),
		"published_packets": _shim.sent,
		"delivered_packets": _shim.delivered,
		"dropped_packets": _shim.dropped,
		"reordered_arrivals": _shim.reordered,
		"max_reconstruction_error_m": snappedf(float(measurement.max_reconstruction_error_m), 0.00001),
		"max_presentation_lag_m": snappedf(float(measurement.max_presentation_lag_m), 0.001),
		"max_extrapolation_m": snappedf(float(measurement.max_extrapolation_m), 0.001),
		"max_sample_step_m": snappedf(float(measurement.max_sample_step_m), 0.001),
		"frozen_rounds": int(measurement.frozen_rounds),
		"stale_rejections": _client_stale_rejections(),
		"stall_rebaselines": _client_stall_rebaselines(),
		"replica_teleports": _client_teleports(),
	}
	_profile_reports.append(report)
	print("LATENCY_PROFILE %s" % JSON.stringify(report))

	_check(int(measurement.samples) > 0, "%s: the sweep actually measured replica state" % name)
	_check(float(measurement.max_reconstruction_error_m) <= RECONSTRUCTION_TOLERANCE_METRES,
		"%s: frame-local reconstruction stays exact under transport disorder (%.5f m)"
			% [name, float(measurement.max_reconstruction_error_m)])
	var lag_bound := _presentation_lag_bound(profile)
	_check(float(measurement.max_presentation_lag_m) <= lag_bound,
		"%s: what a client draws trails the live pose by no more than the profile allows (%.3f m of %.3f m)"
			% [name, float(measurement.max_presentation_lag_m), lag_bound])
	_check(float(measurement.max_extrapolation_m) <= EXTRAPOLATION_HORIZON_TICKS * WALK_SPEED + 0.001,
		"%s: extrapolation stops at the documented horizon (%.3f m)"
			% [name, float(measurement.max_extrapolation_m)])
	_check(float(measurement.max_sample_step_m) <= TELEPORT_TOLERANCE_METRES,
		"%s: no presented step exceeds the documented teleport tolerance (%.3f m)"
			% [name, float(measurement.max_sample_step_m)])
	_check(_client_teleports() == 0, "%s: no replica sample is classified as a teleport" % name)
	if stalled_this_profile:
		_check(int(measurement.frozen_rounds) > 0,
			"%s: the relationship stream freezes across the stall (tick gap beyond %d holds the last pose)"
				% [name, MAX_HOLD_TICKS])
		_check(_client_stall_rebaselines() > 0,
			"%s: the stall is recorded as an ordering re-baseline rather than silently dropped" % name)
		for index in _clients.size():
			_check(not _presented(_clients[index], PILOT_ENTITY).is_empty()
				and not _presented(_clients[index], CREW_ENTITY).is_empty(),
				"%s: client %d still tracks both cabin occupants after the stall" % [name, index])
		_check(_last_presented_tick(_clients[0], CREW_ENTITY) >= _server_tick - 4
			and _last_presented_tick(_clients[1], CREW_ENTITY) >= _server_tick - 4,
			"%s: the stream resumes at the live server tick once delivery returns" % name)


## The visible cost of latency is bounded by the walk speed times the time the
## pose spent in flight: one delay, the jitter window on both sides, the stall,
## and a few ticks of scheduling slack, plus a small constant margin.
func _presentation_lag_bound(profile: Dictionary) -> float:
	var seconds := float(profile.get("delay_ms", 0.0)) / 1000.0
	seconds += 2.0 * float(profile.get("jitter_ms", 0.0)) / 1000.0
	seconds += float(int(profile.get("stall_ticks", 0))) * TICK_SECONDS
	seconds += 4.0 * TICK_SECONDS
	return seconds * WALK_SPEED + 0.3


func _profile_event(profile_name: String, round_index: int, rounds: int) -> void:
	# The bunk beat starts early in its profile because the crew member walks
	# there: six metres of aisle at 2.7 m/s is roughly 133 published ticks.
	if profile_name == "lan" and round_index == 8:
		_begin_bunk_sleep()
	elif profile_name == "lan" and round_index == rounds - 10:
		_end_bunk_sleep()
	elif profile_name == "regional" and round_index == int(rounds / 3):
		_transfer_seat(0, 1)
	elif profile_name == "regional" and round_index == int(rounds * 2 / 3):
		_transfer_seat(1, 0)
	elif profile_name == "intercontinental" and round_index == int(rounds / 2):
		await _drop_and_readmit_second_client()
	elif profile_name == "stall" and round_index == rounds - 12:
		await _reenter_whole_main()


func _drive_round(profile_name: String, round_index: int) -> void:
	_shim.now += TICK_SECONDS
	_server_tick += 1
	_budget_tick += BUDGET_TICKS_PER_ROUND
	_advance_turning_leg()
	_server.set_moving_interior_server_tick(_server_tick)
	var recipients: Array = []
	for peer_id in _client_peer_ids:
		recipients.append(peer_id)
	for entity_variant in _tracked.keys():
		var entity_id := StringName(entity_variant)
		var record := _tracked[entity_id] as Dictionary
		var pose := _authoritative_pose(entity_id)
		var relationship := Relationship.create(
			_server_tick, entity_id, int(record.get("generation", 1)), FRAME_ID, 1,
			pose.get("transform", Transform3D.IDENTITY) as Transform3D,
			pose.get("velocity", Vector3.ZERO) as Vector3
		)
		var snapshot := relationship.get_snapshot()
		_remember_authoritative(entity_id, _server_tick, pose)
		# The authority's own latency observer sees exactly what it published.
		var handoff: Dictionary = _server.handoff_moving_interior_sample({
			"snapshot": snapshot,
			"arrival_time_seconds": _shim.now,
		})
		if not bool(handoff.get("accepted", false)) and round_index == 0:
			_fail("%s: the authority accepts its own relationship sample (%s)"
				% [profile_name, String(handoff.get("status", &"?"))])
		var published: Dictionary = _server.publish_moving_interior_snapshot(
			snapshot, recipients, _budget_tick
		)
		if not bool(published.get("accepted", false)) and round_index == 0:
			_fail("%s: the server publishes the relationship (%s)"
				% [profile_name, String(published.get("status", &"?"))])
	_shim.pump()
	await process_frame
	await process_frame
	await physics_frame


## An arc, not a straight line: the cabin translates and yaws every round, so a
## frame-local pose that never moves still traces a curve through the world.
func _advance_turning_leg() -> void:
	_leg_angle += 0.006
	var radius := 240.0
	var offset := Vector3(
		radius * sin(_leg_angle),
		2.4 * sin(_leg_angle * 3.0),
		radius * (1.0 - cos(_leg_angle))
	)
	var basis := _leg_origin.basis.rotated(Vector3.UP, _leg_angle)
	_craft.global_transform = Transform3D(basis, _leg_origin.origin + _leg_origin.basis * offset)
	if _craft.has_method("set_velocity"):
		_craft.velocity = Vector3.ZERO


## The crew member's authoritative pose is one continuous walk along the cabin
## aisle at 2.7 m/s, one 60 Hz step per published tick. No scenario beat ever
## snaps the pose: a snap would be a teleport inside the cabin rather than a
## transport measurement, and it would hide exactly what this sweep is for.
func _authoritative_pose(entity_id: StringName) -> Dictionary:
	if entity_id == PILOT_ENTITY:
		return {"transform": Transform3D(Basis.IDENTITY, SEAT_LOCAL), "velocity": Vector3.ZERO}
	var record := _tracked[entity_id] as Dictionary
	var here: Vector3 = record.get("local_origin", _aisle_start())
	var target: Vector3 = record.get("walk_target", _bunk_local)
	var step := WALK_SPEED * TICK_SECONDS
	var remaining := here.distance_to(target)
	var velocity := Vector3.ZERO
	if remaining > 0.0005:
		var direction := (target - here).normalized()
		if remaining <= step:
			here = target
		else:
			here += direction * step
			velocity = direction * WALK_SPEED
		record["walk_distance"] = float(record.get("walk_distance", 0.0)) + minf(step, remaining)
	elif bool(record.get("asleep_requested", false)):
		record["asleep"] = true
	else:
		# Off shift the crew member paces the aisle rather than standing still,
		# so every profile measures a moving body inside a moving cabin.
		record["walk_target"] = _bunk_local if target.is_equal_approx(_aisle_start()) else _aisle_start()
	record["local_origin"] = here
	_tracked[entity_id] = record
	return {"transform": Transform3D(Basis.IDENTITY, here), "velocity": velocity}


func _aisle_start() -> Vector3:
	return Vector3(0.0, WALK_FLOOR_Y, _bunk_local.z - AISLE_APPROACH_METRES)


func _remember_authoritative(entity_id: StringName, tick: int, pose: Dictionary) -> void:
	var history: Dictionary = _authoritative.get(entity_id, {}) as Dictionary
	history[tick] = (pose.get("transform", Transform3D.IDENTITY) as Transform3D).origin
	if history.size() > 512:
		var oldest: int = 0
		for key in history.keys():
			oldest = int(key) if oldest == 0 else mini(oldest, int(key))
		history.erase(oldest)
	_authoritative[entity_id] = history
	var live: Dictionary = _tracked.get(entity_id, {}) as Dictionary
	live["live_origin"] = (pose.get("transform", Transform3D.IDENTITY) as Transform3D).origin
	_tracked[entity_id] = live


# --- measurement ------------------------------------------------------------


func _measure_round(measurement: Dictionary, last_sampled: Dictionary) -> void:
	var frame_world: Transform3D = _craft.global_transform
	for index in _clients.size():
		var client = _clients[index]
		var jitter_state: Dictionary = client.get_moving_interior_jitter_state()
		var generation := int(jitter_state.get("migration_generation", 1))
		var next_revision := int(jitter_state.get("next_revision", 1))
		if generation < _generation_floor[index]:
			_fail("client %d migration generation regressed to %d" % [index, generation])
		_generation_floor[index] = maxi(_generation_floor[index], generation)
		if next_revision < _revision_floor[index]:
			_fail("client %d ordering cursor regressed to %d" % [index, next_revision])
		_revision_floor[index] = maxi(_revision_floor[index], next_revision)
		for entity_variant in _tracked.keys():
			var entity_id := StringName(entity_variant)
			var presented := _presented(client, entity_id)
			if presented.is_empty():
				continue
			measurement["samples"] = int(measurement.samples) + 1
			var local: Transform3D = presented.get("local_transform", Transform3D.IDENTITY)
			var presented_tick := int(presented.get("server_tick", -1))
			var history: Dictionary = _authoritative.get(entity_id, {}) as Dictionary
			if history.has(presented_tick):
				var authoritative_origin: Vector3 = history[presented_tick]
				measurement["max_reconstruction_error_m"] = maxf(
					float(measurement.max_reconstruction_error_m),
					local.origin.distance_to(authoritative_origin)
				)
			var live_origin: Vector3 = (_tracked[entity_id] as Dictionary).get("live_origin", local.origin)
			measurement["max_presentation_lag_m"] = maxf(
				float(measurement.max_presentation_lag_m),
				local.origin.distance_to(live_origin)
			)
			_check_contained(index, entity_id, local, frame_world, "presented")
			var sampled: Dictionary = client.sample_moving_interior_replica(entity_id, float(_server_tick))
			if not bool(sampled.get("accepted", false)):
				continue
			if bool(sampled.get("frozen", false)):
				measurement["frozen_rounds"] = int(measurement.frozen_rounds) + 1
			var sampled_transform: Transform3D = sampled.get("transform", Transform3D.IDENTITY)
			measurement["max_extrapolation_m"] = maxf(
				float(measurement.max_extrapolation_m),
				sampled_transform.origin.distance_to(local.origin)
			)
			var step_key := "%d:%s" % [index, String(entity_id)]
			if last_sampled.has(step_key):
				var previous: Vector3 = last_sampled[step_key]
				measurement["max_sample_step_m"] = maxf(
					float(measurement.max_sample_step_m),
					previous.distance_to(sampled_transform.origin)
				)
			last_sampled[step_key] = sampled_transform.origin
			_check_contained(index, entity_id, sampled_transform, frame_world, "sampled")


## The headline property of the frame-local contract: whatever the transport
## does, a replica resolved against the live frame is still inside the cabin and
## still standing on its floor.
func _check_contained(
	index: int,
	entity_id: StringName,
	local: Transform3D,
	frame_world: Transform3D,
	label: String
) -> void:
	if not _interior_bounds.has_point(local.origin):
		_fail("client %d %s %s pose left the cabin bounds at %s"
			% [index, String(entity_id), label, str(local.origin)])
		return
	if local.origin.y < _interior_bounds.position.y:
		_fail("client %d %s %s pose fell through the cabin floor at %s"
			% [index, String(entity_id), label, str(local.origin)])
		return
	var world_origin := (frame_world * local).origin
	if _frame_component != null and _frame_component.has_interior_bounds() \
			and not _frame_component.contains_world_position(world_origin):
		_fail("client %d %s %s pose resolved outside the live frame volume"
			% [index, String(entity_id), label])


func _presented(client, entity_id: StringName) -> Dictionary:
	return (client._moving_replica_samples.get(entity_id, {}) as Dictionary).duplicate(true)


func _last_presented_tick(client, entity_id: StringName) -> int:
	return int(_presented(client, entity_id).get("server_tick", -1))


func _client_stale_rejections() -> int:
	var total := 0
	for index in _clients.size():
		var telemetry: Dictionary = (_clients[index].get_moving_interior_jitter_state()
			.get("telemetry", {}) as Dictionary)
		total += int(telemetry.get("stale_rejection_count", 0))
		total += int((_status_counts[index] as Dictionary).get(&"stale_or_reordered_tick", 0))
	return total


func _client_stall_rebaselines() -> int:
	var total := 0
	for client in _clients:
		total += int(client.get_moving_interior_jitter_state().get("stall_rebaselines", 0))
	return total


func _client_teleports() -> int:
	var total := 0
	for client in _clients:
		total += int(client._moving_replica.get_snapshot().get("teleport_count", 0))
	return total


func _on_client_moving_result(result: Dictionary, index: int) -> void:
	var status := StringName(result.get("status", &"?"))
	var counts := _status_counts[index] as Dictionary
	counts[status] = int(counts.get(status, 0)) + 1
	_status_counts[index] = counts


# --- scenario beats ---------------------------------------------------------


func _begin_bunk_sleep() -> void:
	var record := _tracked[CREW_ENTITY] as Dictionary
	record["walk_target"] = _bunk_local
	record["asleep_requested"] = true
	record["asleep"] = false
	_tracked[CREW_ENTITY] = record
	_check(_interior_bounds.has_point(_bunk_local),
		"the in-flight bunk pose the server publishes is inside the walkable cabin")


func _end_bunk_sleep() -> void:
	var record := _tracked[CREW_ENTITY] as Dictionary
	_check(bool(record.get("asleep", false)),
		"the crew member walks the aisle to the bunk and lies down while the ship flies its leg")
	for index in _clients.size():
		var presented := _presented(_clients[index], CREW_ENTITY)
		var local: Transform3D = presented.get("local_transform", Transform3D.IDENTITY)
		_check(local.origin.distance_to(_bunk_local) < 0.01,
			"client %d holds the sleeping crew member still at the bunk in flight" % index)
		var sampled: Dictionary = _clients[index].sample_moving_interior_replica(
			CREW_ENTITY, float(_server_tick)
		)
		_check(bool(sampled.get("accepted", false))
			and (sampled.get("transform", Transform3D.IDENTITY) as Transform3D
				).origin.distance_to(_bunk_local) < 0.01,
			"client %d does not extrapolate a sleeping body off its bunk" % index)
	record["asleep_requested"] = false
	record["asleep"] = false
	record["walk_target"] = _aisle_start()
	_tracked[CREW_ENTITY] = record


func _transfer_seat(from_index: int, to_index: int) -> void:
	var from_peer := _client_peer_ids[from_index]
	var to_peer := _client_peer_ids[to_index]
	var before: Dictionary = _server.get_crew_moving_interior_relationship(from_peer, PILOT_ENTITY)
	var result: Dictionary = _server.transfer_crew_seat(
		from_peer, to_peer, PILOT_ENTITY, SEAT_ID, _next_sequence(), 1
	)
	_check(bool(result.get("accepted", false)),
		"the pilot seat transfers from client %d to client %d in flight (%s)"
			% [from_index, to_index, String(result.get("status", &"?"))])
	var after: Dictionary = _server.get_crew_moving_interior_relationship(to_peer, PILOT_ENTITY)
	_check(_server.get_crew_moving_interior_relationship(from_peer, PILOT_ENTITY).is_empty()
		and not after.is_empty()
		and int(after.get("parent_frame_generation", 0)) >= int(before.get("parent_frame_generation", 0)),
		"the transferred claim carries exactly one relationship forward without a generation regression")


func _next_sequence() -> int:
	_sequence += 1
	return _sequence


func _drop_and_readmit_second_client() -> void:
	var dropped_peer := _client_peer_ids[1]
	# A reconnecting crew member resumes from where the cabin left them, so the
	# re-registered stream must not look like a jump to any other client.
	var crew_pose_before_drop: Vector3 = (_tracked[CREW_ENTITY] as Dictionary).get(
		"local_origin", _aisle_start()
	)
	var pilot_before: Dictionary = _server.get_crew_assignment(_client_peer_ids[0], PILOT_ENTITY)
	_clients[1].shutdown(&"latency_sweep_drop")
	await _pump(func() -> bool: return not _server._peer_generations.has(dropped_peer))
	_shim.forget_peer(dropped_peer)
	_check(not _server._peer_generations.has(dropped_peer),
		"the server observes the second client dropping mid-leg")
	_check(_server.get_moving_interior_occupancy(CREW_ENTITY).is_empty(),
		"the dropped peer's moving-interior occupancy is released exactly as documented")
	var pilot_after: Dictionary = _server.get_crew_assignment(_client_peer_ids[0], PILOT_ENTITY)
	_check(not pilot_after.is_empty()
		and int(pilot_after.get("seat_generation", 0)) == int(pilot_before.get("seat_generation", 0)),
		"the surviving client keeps its own seat claim across the other client's drop")
	await _settle()
	_check(_presented(_clients[0], CREW_ENTITY).is_empty(),
		"the remaining client stops drawing the crew member who left the cabin")
	_check(_presented(_clients[1], CREW_ENTITY).is_empty()
		and not _clients[1].sample_moving_interior_replica(CREW_ENTITY, float(_server_tick)).get("accepted", false),
		"a torn-down client keeps no pre-disconnect pose to show on reconnect")
	_tracked.erase(CREW_ENTITY)

	var port: int = _server.get_local_port()
	_check(bool(_clients[1].join("127.0.0.1", port).get("accepted", false)),
		"the dropped client reconnects to the same session")
	await _pump(func() -> bool: return not _clients[1].get_server_offer().is_empty())
	_client_peer_ids[1] = _clients[1].multiplayer.get_unique_id()
	var readmitted: Dictionary = _server.register_moving_interior_occupancy(
		_client_peer_ids[1], CREW_ENTITY, 2, FRAME_ID, 1
	)
	_check(bool(readmitted.get("accepted", false)),
		"the reconnected client is re-registered under a fresh entity generation (%s)"
			% String(readmitted.get("status", &"?")))
	_tracked[CREW_ENTITY] = {
		"peer_id": _client_peer_ids[1],
		"generation": 2,
		"local_origin": crew_pose_before_drop,
		"walk_target": _aisle_start(),
		"walk_distance": 0.0,
	}
	_generation_floor[1] = 0
	_revision_floor[1] = 0


func _reenter_whole_main() -> void:
	var parent := _game.get_parent()
	var frame_before := _craft.global_transform
	var player_before := _server_player.global_position
	var pilot_before: Dictionary = _server.get_crew_assignment(_client_peer_ids[0], PILOT_ENTITY)
	parent.remove_child(_game)
	await process_frame
	parent.add_child(_game)
	await process_frame
	await physics_frame
	_craft.global_transform = frame_before
	await physics_frame
	_check(is_instance_valid(_craft) and is_instance_valid(_server_player),
		"the whole Main subtree survives re-entry with its Halyard and server player")
	_check(_server_player.global_position.distance_to(player_before) < 1.0,
		"the server's own player is unaffected by the re-entry under latency")
	var pilot_after: Dictionary = _server.get_crew_assignment(_client_peer_ids[0], PILOT_ENTITY)
	_check(not pilot_after.is_empty()
		and int(pilot_after.get("seat_generation", 0)) == int(pilot_before.get("seat_generation", 0)),
		"a whole-Main re-entry on the server does not disturb a remote seat claim")
	_frame_component = _craft.get_moving_interior_component()


func _assert_disconnect_releases_a_seat() -> void:
	var seated_peer := _client_peer_ids[0]
	_check(not _server.get_crew_assignment(seated_peer, PILOT_ENTITY).is_empty(),
		"the pilot seat is still claimed before the closing disconnect")
	_clients[0].shutdown(&"latency_sweep_close")
	await _pump(func() -> bool: return not _server._peer_generations.has(seated_peer))
	_check(_server.get_crew_assignment(seated_peer, PILOT_ENTITY).is_empty()
		and _server.get_crew_moving_interior_relationship(seated_peer, PILOT_ENTITY).is_empty()
		and _server.get_moving_interior_occupancy(PILOT_ENTITY).is_empty(),
		"a seat claim is released on disconnect, exactly as the seat authority documents")
	await _settle()
	_check(_presented(_clients[1], PILOT_ENTITY).is_empty(),
		"the other client stops drawing the pilot who disconnected")


# --- reporting and teardown -------------------------------------------------


func _report_summary() -> void:
	var worst_lag := 0.0
	var worst_reconstruction := 0.0
	var worst_extrapolation := 0.0
	var dropped := 0
	var reordered := 0
	for report_variant in _profile_reports:
		var report := report_variant as Dictionary
		worst_lag = maxf(worst_lag, float(report.max_presentation_lag_m))
		worst_reconstruction = maxf(worst_reconstruction, float(report.max_reconstruction_error_m))
		worst_extrapolation = maxf(worst_extrapolation, float(report.max_extrapolation_m))
		dropped += int(report.dropped_packets)
		reordered += int(report.reordered_arrivals)
	print("LATENCY_SUMMARY %s" % JSON.stringify({
		"profiles": _profile_reports.size(),
		"server_ticks": _server_tick,
		"worst_presentation_lag_m": snappedf(worst_lag, 0.001),
		"worst_reconstruction_error_m": snappedf(worst_reconstruction, 0.00001),
		"worst_extrapolation_m": snappedf(worst_extrapolation, 0.001),
		"dropped_packets": dropped,
		"reordered_arrivals": reordered,
		"stale_rejections": _client_stale_rejections(),
		"stall_rebaselines": _client_stall_rebaselines(),
		"replica_teleports": _client_teleports(),
	}))
	_check(int(_status_counts[1].get(&"stale_or_reordered_tick", 0))
			+ int(_status_counts[0].get(&"stale_or_reordered_tick", 0))
			+ _client_stale_rejections() > 0,
		"the sweep exercised and counted stale or reordered relationship packets")
	# One accepted sample must carry exactly one predecessor. A record that
	# embeds the previous record whole grows a new nesting level per packet, so
	# a long leg makes every arriving relationship more expensive to copy than
	# the last until the engine's duplicate-recursion limit stops the replica.
	for index in _clients.size():
		var samples: Dictionary = _clients[index]._moving_replica._samples
		for entity_variant in samples.keys():
			var previous: Dictionary = (samples[entity_variant] as Dictionary).get("previous", {}) as Dictionary
			_check(not previous.has("previous"),
				"client %d keeps one predecessor per replica sample, not a chain of them" % index)
	_check(worst_reconstruction <= RECONSTRUCTION_TOLERANCE_METRES,
		"every profile reconstructs the authoritative frame-local pose exactly")
	# Nothing the remote cabin does under latency may reach the person hosting
	# the session: their own body is simulated locally and never replicated.
	_check(is_instance_valid(_server_player)
		and _server_player.global_position.distance_to(_server_player_origin) < 1.0
		and _server_player.get_parent() != null,
		"the server's own player is untouched by the whole latency sweep")


func _settle() -> void:
	_shim.drain()
	for _frame in 6:
		await process_frame
	_shim.pump()
	for _frame in 6:
		await process_frame


func _pump(predicate: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline and not predicate.call():
		if _shim != null:
			_shim.now += TICK_SECONDS
			_shim.pump()
		await process_frame


func _finish() -> void:
	if _server != null:
		_server.set_moving_interior_transport_hook(Callable())
	for adapter in _adapters:
		adapter.shutdown()
	for branch in _branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	_branches.clear()
	_adapters.clear()
	_clients.clear()
	_server = null
	_shim = null
	if _game != null and is_instance_valid(_game):
		_game.free()
		_game = null
	await process_frame
	if _failures.is_empty():
		print("NETWORK_MOVING_INTERIOR_LATENCY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_assertions += 1
	if not _failures.has(message):
		_failures.append(message)
