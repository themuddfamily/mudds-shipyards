extends SceneTree

## What a client actually draws when a crewmate walks the cabin of a flying
## Halyard, driven through the real ENet session in-process.
##
## The latency sweep next door (`tests/network_moving_interior_latency_test.gd`)
## measures the numbers inside the replica. This suite measures the node on
## screen: `NetworkMovingInteriorPresenter` samples the replica every rendered
## frame, composes the frame-local pose with the live `MovingInteriorFrame`
## transform, and moves one remote avatar. What is asserted here is where that
## avatar *is*, and when it stops existing.
##
## Named `network_*` for the same reason the latency sweep is: only suites under
## `tests/network/*` or `tests/network_*` take `run_test_matrix.sh`'s per-run
## flock lane, and this one opens real `ENetMultiplayerPeer` sockets.
##
## What is real here:
##   * `res://scenes/main.tscn` runs on the server side, so the moving frame is
##     the production `HalyardCrewTransport` with its own `MovingInteriorFrame`
##     and published `INTERIOR_BOUNDS`, and the server's own player is the
##     production `PlayerController`.
##   * One server and two clients each own a real `NetworkEnetSessionAdapter`
##     on its own `SceneMultiplayer` branch, connected over loopback ENet.
##   * The drawing client owns a real `NetworkMovingInteriorPresenter`, which
##     spawns the production pilot visual and drives it through the production
##     replica and binding. Nothing is stubbed.
##
## What the harness adds is the same test-only transport shim the latency sweep
## installs through `NetworkEnetSessionAdapter.set_moving_interior_transport_hook()`:
## it can only hold back or re-order a packet the server already decided to
## send, and every packet it releases goes back through the same authority RPC.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Presenter := preload("res://scripts/network/network_moving_interior_presenter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const TICK_SECONDS := 1.0 / 60.0
const PILOT_ENTITY: StringName = &"pilota"
const CREW_ENTITY: StringName = &"crewb"
const FRAME_ID: StringName = &"halyardframe"
const SHIP_ID: StringName = &"halyard"
const SEAT_ID: StringName = &"halyardpilot"
const BUDGET_TICKS_PER_ROUND := 10

## The walking crew member covers ordinary ground: 2.7 m/s, one 60 Hz step per
## published tick, so the distances asserted below are the distances a player
## would really see them cover in the cabin.
const WALK_SPEED := 2.7
const WALK_FLOOR_Y := 0.95
const AISLE_APPROACH_METRES := 6.0
const SEAT_LOCAL := Vector3(0.0, 1.05, -10.4)

## Mirrors the production replica construction in `NetworkEnetSessionAdapter._init()`.
## The timeline is real seconds, so the horizon is 0.25 s of published linear
## velocity: 0.675 m at this walk speed.
const EXTRAPOLATION_HORIZON_SECONDS := 0.25

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
var _viewer
var _crew_client
var _client_peer_ids: Array[int] = []
var _presenter_holder: Node3D = null
var _presenter: Presenter = null
var _shim: TransportShim = null

var _server_tick := 0
var _budget_tick := 0
var _tracked: Dictionary = {}
var _leg_angle := 0.0
var _leg_origin := Transform3D.IDENTITY
var _server_player_origin := Vector3.ZERO
var _bunk_local := Vector3(0.0, WALK_FLOOR_Y, 6.4)
var _sequence := 1
var _crew_generation := 1


## Test-only transport shim, the same shape the latency sweep uses: it never
## inspects or rewrites a relationship, it only decides when an already-published
## packet reaches the peer.
class TransportShim extends RefCounted:
	var server = null
	var rng := RandomNumberGenerator.new()
	var now := 0.0
	var delay := 0.0
	var jitter := 0.0
	var queue: Array = []
	var delivered := 0

	func configure(p_delay_ms: float, p_jitter_ms: float) -> void:
		delay = p_delay_ms / 1000.0
		jitter = p_jitter_ms / 1000.0

	func enqueue(peer_id: int, wire: Dictionary) -> void:
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
			if server != null:
				server.deliver_moving_interior_wire_packet(
					int(item.get("peer_id", 0)), item.get("wire", {}) as Dictionary
				)

	func drain() -> void:
		now += 60.0
		pump()

	func forget_peer(peer_id: int) -> void:
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
	_board_the_halyard()
	await _attach_presenter()
	await _assert_draws_the_walking_crewmate("direct", 60, 0.0, 0.0)
	_assert_avatar_wears_the_production_pilot_visual()
	await _assert_draws_the_walking_crewmate("lan", 120, 80.0, 20.0)
	await _assert_steady_state_costs_nothing()
	await _assert_reduced_motion_never_runs_ahead()
	await _assert_release_removes_the_avatar()
	await _assert_migration_and_reentry_leave_no_orphan()
	await _assert_disconnect_removes_the_avatar()
	await _assert_session_end_clears_everything()
	_report_summary()
	await _finish()


# --- world, session and presenter -------------------------------------------


func _build_world() -> bool:
	_game = MAIN_SCENE.instantiate()
	if _game == null:
		_fail("production scene instantiates for the presentation sweep")
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


func _resolve_bunk_pose() -> void:
	var bunk := _craft.get_node_or_null(
		"WalkableInterior/AftSystemsBay/PortSleepingBerth/ShipBunkInteraction"
	)
	if bunk == null or not bunk.has_method("get_seat_anchor"):
		return
	var anchor := bunk.get_seat_anchor() as Node3D
	if anchor == null:
		return
	var candidate := _craft.to_local(anchor.global_position)
	candidate.y = maxf(candidate.y, _interior_bounds.position.y + 0.3)
	if _interior_bounds.has_point(candidate):
		_bunk_local = candidate


func _build_session() -> bool:
	for branch_name in ["PresentationServer", "PresentationViewer", "PresentationCrew"]:
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
	_viewer = _adapters[1]
	_crew_client = _adapters[2]
	_shim = TransportShim.new()
	_shim.rng.seed = 0x9E37_79B9
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_fail("reserve a loopback UDP port for the presentation sweep")
		return false
	var port := probe.get_local_port()
	probe.stop()
	_check(bool(_server.host(port, 4).get("accepted", false)), "host a real ENet session for the sweep")
	var joined := bool(_viewer.join("127.0.0.1", port).get("accepted", false))
	joined = joined and bool(_crew_client.join("127.0.0.1", port).get("accepted", false))
	_check(joined, "the drawing client and the walking client join over loopback")
	await _pump(func() -> bool:
		if _viewer.get_server_offer().is_empty() or _crew_client.get_server_offer().is_empty():
			return false
		return _server._peer_generations.size() >= 2
	)
	_client_peer_ids = [
		_viewer.multiplayer.get_unique_id(),
		_crew_client.multiplayer.get_unique_id(),
	]
	var admitted := true
	for peer_id in _client_peer_ids:
		admitted = admitted and _server._peer_generations.has(peer_id)
	_check(admitted, "the server admits both clients before any authority call")
	_shim.server = _server
	_check(bool(_server.set_moving_interior_transport_hook(
			Callable(_shim, "enqueue")).get("installed", false)),
		"the relationship stream routes through the test transport shim")
	return admitted


func _board_the_halyard() -> void:
	_check(bool(_server.register_owned_ship(SHIP_ID, 1, _client_peer_ids[0]).get("accepted", false)),
		"the server hands the Halyard to the drawing client")
	_check(bool(_server.register_moving_interior_frame(FRAME_ID, 1).get("accepted", false)),
		"the server registers the Halyard's moving-interior frame")
	_check(bool(_server.register_crew_seat(SEAT_ID, SHIP_ID, &"pilot", FRAME_ID, 1).get("accepted", false)),
		"the server registers the Halyard pilot seat against that frame")
	_check(bool(_server.claim_crew_seat(
			_client_peer_ids[0], PILOT_ENTITY, SEAT_ID, &"pilot", 1).get("accepted", false)),
		"the drawing client is the seated pilot of the craft it is watching")
	_check(bool(_server.register_moving_interior_occupancy(
			_client_peer_ids[0], PILOT_ENTITY, 1, FRAME_ID, 1).get("accepted", false)),
		"the seated pilot is an occupant of the frame it claimed")
	_check(bool(_server.register_moving_interior_occupancy(
			_client_peer_ids[1], CREW_ENTITY, 1, FRAME_ID, 1).get("accepted", false)),
		"the second client is registered as a walking occupant of the same frame")
	_tracked = {
		PILOT_ENTITY: {"peer_id": _client_peer_ids[0], "generation": 1},
		CREW_ENTITY: {
			"peer_id": _client_peer_ids[1],
			"generation": 1,
			"local_origin": _aisle_start(),
			"walk_target": _bunk_local,
		},
	}


## The presenter lives under its own holder so the suite can take the whole
## subtree out of the tree and put it back — the client-side half of a
## whole-Main re-entry.
func _attach_presenter() -> void:
	_presenter_holder = Node3D.new()
	_presenter_holder.name = "ViewerWorld"
	_branches[1].add_child(_presenter_holder)
	_presenter = Presenter.new()
	_presenter.name = "NetworkMovingInteriorPresenter"
	_presenter_holder.add_child(_presenter)
	_check(bool(_presenter.attach(_viewer).get("accepted", false)),
		"the drawing client's presenter attaches to its own session adapter")
	_check(bool(_presenter.register_frame(FRAME_ID, 1, _craft).get("accepted", false)),
		"the presenter resolves the published frame id to the live Halyard")
	# The pilot is this peer's own body: it is simulated locally and must never
	# be drawn a second time from the server's echo of it.
	_presenter.set_local_entity_ids([PILOT_ENTITY])
	await process_frame


# --- the drawing assertions -------------------------------------------------


func _assert_draws_the_walking_crewmate(
	label: String, rounds: int, delay_ms: float, jitter_ms: float
) -> void:
	_shim.configure(delay_ms, jitter_ms)
	var max_lag := 0.0
	var max_world_travel := 0.0
	var max_local_travel := 0.0
	var first_world := Vector3.ZERO
	var first_local := Vector3.ZERO
	var have_first := false
	var drawn_rounds := 0
	var clips: Dictionary = {}
	for round_index in rounds:
		await _drive_round()
		var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
		if avatar == null:
			continue
		drawn_rounds += 1
		clips[_presenter.get_avatar_animation_clip(CREW_ENTITY)] = true
		var world_origin: Vector3 = avatar.global_position
		var local_origin: Vector3 = (_craft.global_transform.affine_inverse() * avatar.global_transform).origin
		var live_local: Vector3 = (_tracked[CREW_ENTITY] as Dictionary).get("local_origin", local_origin)
		max_lag = maxf(max_lag, local_origin.distance_to(live_local))
		if not have_first:
			first_world = world_origin
			first_local = local_origin
			have_first = true
		max_world_travel = maxf(max_world_travel, first_world.distance_to(world_origin))
		max_local_travel = maxf(max_local_travel, first_local.distance_to(local_origin))
		if not _interior_bounds.has_point(local_origin):
			_fail("%s: the drawn crew member left the cabin bounds at %s"
				% [label, str(local_origin)])
			break
		if local_origin.y < _interior_bounds.position.y:
			_fail("%s: the drawn crew member fell through the cabin floor at %s"
				% [label, str(local_origin)])
			break
		if _frame_component != null and _frame_component.has_interior_bounds() \
				and not _frame_component.contains_world_position(world_origin):
			_fail("%s: the drawn crew member resolved outside the live frame volume" % label)
			break
	_check(drawn_rounds > rounds / 2,
		"%s: the client draws the remote crew member for the whole leg (%d of %d rounds)"
			% [label, drawn_rounds, rounds])
	var bound := _presentation_bound(delay_ms, jitter_ms)
	_check(max_lag <= bound,
		"%s: the drawn body stays within the interpolation bound of the server occupant (%.3f m of %.3f m)"
			% [label, max_lag, bound])
	# The whole point of a moving interior: the body is carried by the cabin.
	# Over a turning leg it covers hundreds of metres of world space while
	# walking a few metres of aisle.
	_check(max_world_travel > 20.0 * maxf(max_local_travel, 0.001) and max_world_travel > 20.0,
		"%s: the drawn body is carried by the cabin, not left behind in world space (%.1f m world, %.2f m cabin)"
			% [label, max_world_travel, max_local_travel])
	_check(_presenter.get_avatar_node(PILOT_ENTITY) == null,
		"%s: this peer's own seated body is never drawn from the server's echo of it" % label)
	_check(_presenter.get_child_count() == _presenter.get_drawn_entity_ids().size(),
		"%s: the presenter holds exactly one node per drawn crew member" % label)
	# The clip is chosen from the pose's speed *in the cabin's* coordinates. Read
	# in world space instead, a passenger standing still in a Halyard under way
	# is crossing the sky at flight speed, and every body on board animates as
	# sprinting for the whole leg — on this profile too, which is why the
	# undelayed pass is the one that has to be clean. Under real latency a
	# delayed batch legitimately lands as a burst of catch-up movement, and a
	# body that covers that ground quickly is drawn covering it quickly.
	if delay_ms == 0.0:
		_check(not clips.has(&"run"),
			"%s: a 2.7 m/s walk animates as a walk, not a sprint (clips: %s)"
				% [label, str(clips.keys())])


## The remote crew member is not an abstract transform: they are drawn with the
## same pilot the local player wears — the imported Blender suit from
## `scenes/player/pilot_skinned_presentation.tscn`, or, if that asset cannot
## build, the same generated recovery suit `PlayerController` falls back to.
func _assert_avatar_wears_the_production_pilot_visual() -> void:
	var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	_check(avatar != null, "the crew member has an avatar node to inspect")
	if avatar == null:
		return
	_check(avatar.is_inside_tree() and avatar.is_visible_in_tree(),
		"the remote crew member's avatar is in the tree and visible")
	var imported := avatar.find_child("PilotSkinnedPresentation", true, false)
	var fallback := avatar.find_child("RefinedPilotCore", true, false)
	_check(imported != null or fallback != null,
		"the remote crew member wears the production pilot visual, not a placeholder")
	var meshes := _count_visible_meshes(avatar)
	_check(meshes > 0,
		"the remote crew member is drawn with real geometry (%d mesh instances)" % meshes)
	print("PRESENTATION_AVATAR %s" % JSON.stringify({
		"visual": "imported_pilot_suit" if imported != null else (
			"generated_recovery_suit" if fallback != null else "none"
		),
		"mesh_instances": meshes,
	}))


func _count_visible_meshes(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += 1
	for child in node.get_children():
		total += _count_visible_meshes(child)
	return total


## Steady state — the same entity drawn every frame with no arrivals or
## departures — must cost no scene-tree churn and no rebinding.
func _assert_steady_state_costs_nothing() -> void:
	var before: Dictionary = _presenter.get_presentation_audit()
	var applied_before := int(before.get("applied_count", 0))
	for _round_index in 30:
		await _drive_round()
	var after: Dictionary = _presenter.get_presentation_audit()
	_check(int(after.get("reconcile_count", 0)) == int(before.get("reconcile_count", 0)),
		"a steady leg runs no reconcile at all (%d)" % int(after.get("reconcile_count", 0)))
	_check(int(after.get("spawn_count", 0)) == int(before.get("spawn_count", 0))
		and int(after.get("release_count", 0)) == int(before.get("release_count", 0)),
		"a steady leg spawns and frees no avatar node")
	_check(int(after.get("applied_count", 0)) > applied_before,
		"the presenter is still driving the avatar every rendered frame")


## Reduced motion is an accessibility setting the presenter reads, never owns.
## With it on, the presenter samples at the newest accepted arrival instead of
## running its render clock past it, so the drawn body never speculates ahead of
## a pose the server actually sent.
func _assert_reduced_motion_never_runs_ahead() -> void:
	_shim.configure(80.0, 20.0)
	_presenter.set_reduced_motion(true)
	_check(bool(_presenter.get_presentation_audit().get("reduced_motion", false)),
		"the presenter reports the reduced-motion setting it was given")
	var max_overshoot := 0.0
	var samples := 0
	for _round_index in 60:
		await _drive_round()
		var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
		if avatar == null:
			continue
		var presented: Dictionary = _presented(_viewer, CREW_ENTITY)
		if presented.is_empty():
			continue
		samples += 1
		var accepted: Vector3 = (presented.get("local_transform", Transform3D.IDENTITY) as Transform3D).origin
		var drawn: Vector3 = (_craft.global_transform.affine_inverse() * avatar.global_transform).origin
		max_overshoot = maxf(max_overshoot, accepted.distance_to(drawn))
	_check(samples > 0, "reduced motion still draws the remote crew member")
	# One publication step of slack: which of the presenter's frames observed an
	# arrival is scheduling, not speculation. What matters is that the drawn pose
	# is an accepted pose rather than one the replica invented ahead of it.
	var accepted_pose_tolerance := WALK_SPEED * TICK_SECONDS + 0.001
	_check(max_overshoot <= accepted_pose_tolerance,
		"under reduced motion the drawn pose is an accepted pose, never an extrapolation (%.4f m of %.4f m)"
			% [max_overshoot, accepted_pose_tolerance])
	_presenter.set_reduced_motion(false)
	# Without reduced motion the same leg is allowed to run ahead, but only as
	# far as the documented horizon.
	var max_ahead := 0.0
	for _round_index in 60:
		await _drive_round()
		var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
		var presented: Dictionary = _presented(_viewer, CREW_ENTITY)
		if avatar == null or presented.is_empty():
			continue
		var accepted: Vector3 = (presented.get("local_transform", Transform3D.IDENTITY) as Transform3D).origin
		var drawn: Vector3 = (_craft.global_transform.affine_inverse() * avatar.global_transform).origin
		max_ahead = maxf(max_ahead, accepted.distance_to(drawn))
	_check(max_ahead <= EXTRAPOLATION_HORIZON_SECONDS * WALK_SPEED + 0.001,
		"the drawn pose never runs past the documented extrapolation horizon (%.3f m of %.3f m)"
			% [max_ahead, EXTRAPOLATION_HORIZON_SECONDS * WALK_SPEED])
	# ...and the setting is not decorative: with it off, the same leg at the same
	# latency really does run ahead of the newest accepted pose.
	_check(max_ahead > accepted_pose_tolerance,
		"with reduced motion off the presenter does extrapolate between arrivals (%.3f m)" % max_ahead)


func _assert_release_removes_the_avatar() -> void:
	# Flush whatever the previous 80 ms profile still has in flight first. The
	# shim is free to hand the release to the client ahead of a snapshot that was
	# published before it; the production RPC channel is reliable and ordered, so
	# that overtake is a harness artefact and is not what this beat is about.
	_shim.configure(0.0, 0.0)
	await _settle()
	await _drive_round()
	var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	_check(avatar != null, "the crew member is on screen before the seat is released")
	_check(bool(_server.retire_moving_interior_occupancy(
			CREW_ENTITY, _crew_generation).get("accepted", false)),
		"the server retires the crew member's occupancy of the cabin")
	_check(bool(_server.publish_moving_interior_release(
			CREW_ENTITY, _crew_generation).get("accepted", false)),
		"the server publishes the release tombstone for the crew member leaving the cabin")
	_check(_server.get_moving_interior_occupancy(CREW_ENTITY).is_empty(),
		"the released entity id is free for a fresh occupancy generation")
	_tracked.erase(CREW_ENTITY)
	await _settle()
	_check(_presenter.get_avatar_node(CREW_ENTITY) == null,
		"a released crew member stops being drawn")
	_check(_presenter.get_child_count() == 0,
		"the released avatar leaves no node behind (%d children)" % _presenter.get_child_count())
	await process_frame
	await process_frame
	_check(not is_instance_valid(avatar), "the released avatar node is actually freed, not orphaned")
	await _readmit_walking_crewmate(2)
	_check(_presenter.get_avatar_node(CREW_ENTITY) != null,
		"a crew member who steps back into the cabin is drawn again")


func _assert_migration_and_reentry_leave_no_orphan() -> void:
	var before: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	_check(before != null, "the crew member is on screen before the migration")
	var rotated: Dictionary = _server.rotate_session_migration()
	_check(bool(rotated.get("accepted", false)), "the server rotates the session migration generation")
	var generation := int(_server.get_migration_snapshot().get("migration_generation", 1))
	_check(generation > 1, "the migration generation actually advanced")
	for client in [_viewer, _crew_client]:
		_check(bool(client.reset_snapshot_jitter(generation).get("accepted", false)),
			"each client resets its presentation cursors onto the new generation")
	await _settle()
	_check(_presenter.get_avatar_node(CREW_ENTITY) == null
		and _presenter.get_child_count() == 0,
		"a migration drops every drawn crew member instead of stranding one mid-cabin")
	await process_frame
	_check(not is_instance_valid(before), "the pre-migration avatar node is freed by the migration")
	for _round_index in 20:
		await _drive_round()
	_check(_presenter.get_avatar_node(CREW_ENTITY) != null,
		"the crew member is drawn again once the new generation is publishing")
	_check(int(_presenter.get_presentation_audit().get("migration_generation", 0)) == generation,
		"the presenter tracks the live migration generation")

	# Whole-Main re-entry: the server's world subtree and the drawing client's
	# own presentation subtree both leave the tree and come back.
	var frame_before := _craft.global_transform
	var player_before := _server_player.global_position
	var drawn_before: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	var game_parent := _game.get_parent()
	var holder_parent := _presenter_holder.get_parent()
	game_parent.remove_child(_game)
	holder_parent.remove_child(_presenter_holder)
	await process_frame
	_check(_presenter.get_child_count() == 0,
		"leaving the tree releases every avatar rather than carrying one out with the subtree")
	_check(not is_instance_valid(drawn_before),
		"no avatar node survives the detach as an orphan")
	game_parent.add_child(_game)
	holder_parent.add_child(_presenter_holder)
	await process_frame
	await physics_frame
	_craft.global_transform = frame_before
	await physics_frame
	_check(is_instance_valid(_craft) and is_instance_valid(_server_player),
		"the whole Main subtree survives re-entry with its Halyard and server player")
	_check(_server_player.global_position.distance_to(player_before) < 1.0,
		"the server's own player is unaffected by the re-entry")
	_frame_component = _craft.get_moving_interior_component()
	for _round_index in 20:
		await _drive_round()
	var after: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	_check(after != null, "the crew member is drawn again after the re-entry")
	if after != null:
		var local_origin: Vector3 = (_craft.global_transform.affine_inverse() * after.global_transform).origin
		_check(_interior_bounds.has_point(local_origin),
			"the re-entered presentation puts the crew member back inside the cabin")
	_check(_presenter.get_child_count() == _presenter.get_drawn_entity_ids().size(),
		"the re-entered presenter holds exactly one node per drawn crew member")


func _assert_disconnect_removes_the_avatar() -> void:
	var avatar: Node3D = _presenter.get_avatar_node(CREW_ENTITY)
	_check(avatar != null, "the crew member is on screen before they drop")
	var dropped_peer := _client_peer_ids[1]
	_crew_client.shutdown(&"presentation_sweep_drop")
	await _pump(func() -> bool: return not _server._peer_generations.has(dropped_peer))
	_shim.forget_peer(dropped_peer)
	_check(not _server._peer_generations.has(dropped_peer),
		"the server observes the walking client dropping mid-leg")
	_tracked.erase(CREW_ENTITY)
	await _settle()
	_check(_presenter.get_avatar_node(CREW_ENTITY) == null,
		"the crew member who disconnected stops being drawn instead of standing there forever")
	_check(_presenter.get_child_count() == 0,
		"the disconnected crew member leaves no node behind")
	await process_frame
	_check(not is_instance_valid(avatar), "the disconnected crew member's avatar node is freed")


func _assert_session_end_clears_everything() -> void:
	# Put one body back on screen, then end the drawing client's own session.
	await _readmit_walking_crewmate(3)
	_check(_presenter.get_avatar_node(CREW_ENTITY) != null,
		"a rejoining crew member is drawn before the session closes")
	_viewer.shutdown(&"presentation_sweep_close")
	await process_frame
	await process_frame
	_check(_presenter.get_child_count() == 0
		and _presenter.get_drawn_entity_ids().is_empty(),
		"closing the session clears every remote body this peer was drawing")
	var audit: Dictionary = _presenter.get_presentation_audit()
	_check(not bool(audit.get("owns_physics_authority", true))
		and not bool(audit.get("owns_seat_authority", true))
		and not bool(audit.get("owns_movement_authority", true)),
		"the presenter claims no physics, seat or movement authority at any point")


# --- driving ----------------------------------------------------------------


func _drive_round() -> void:
	_shim.now += TICK_SECONDS
	_server_tick += 1
	_budget_tick += BUDGET_TICKS_PER_ROUND
	_advance_turning_leg()
	_server.set_moving_interior_server_tick(_server_tick)
	var recipients: Array = []
	for peer_id in _client_peer_ids:
		if _server._peer_generations.has(peer_id):
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
		_server.publish_moving_interior_snapshot(
			relationship.get_snapshot(), recipients, _budget_tick
		)
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


## One continuous walk along the cabin aisle at 2.7 m/s. No beat in this suite
## snaps the pose: a snap would be a teleport inside the cabin rather than a
## presentation measurement.
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
	else:
		record["walk_target"] = _bunk_local if target.is_equal_approx(_aisle_start()) else _aisle_start()
	record["local_origin"] = here
	_tracked[entity_id] = record
	return {"transform": Transform3D(Basis.IDENTITY, here), "velocity": velocity}


func _aisle_start() -> Vector3:
	return Vector3(0.0, WALK_FLOOR_Y, _bunk_local.z - AISLE_APPROACH_METRES)


## What a client draws trails the live pose by the time the pose spent in
## flight: one delay, the jitter window on both sides, a few ticks of frame
## scheduling, and the extrapolation horizon it may speculate across.
func _presentation_bound(delay_ms: float, jitter_ms: float) -> float:
	var seconds := delay_ms / 1000.0
	seconds += 2.0 * jitter_ms / 1000.0
	seconds += 6.0 * TICK_SECONDS
	seconds += EXTRAPOLATION_HORIZON_SECONDS
	return seconds * WALK_SPEED + 0.3


func _readmit_walking_crewmate(generation: int) -> void:
	if not _server._peer_generations.has(_client_peer_ids[1]):
		var port: int = _server.get_local_port()
		_check(bool(_crew_client.join("127.0.0.1", port).get("accepted", false)),
			"the dropped client reconnects to the same session")
		await _pump(func() -> bool: return not _crew_client.get_server_offer().is_empty())
		_client_peer_ids[1] = _crew_client.multiplayer.get_unique_id()
	_crew_generation = generation
	_check(bool(_server.register_moving_interior_occupancy(
			_client_peer_ids[1], CREW_ENTITY, generation, FRAME_ID, 1).get("accepted", false)),
		"the crew member is re-registered as an occupant under entity generation %d" % generation)
	_tracked[CREW_ENTITY] = {
		"peer_id": _client_peer_ids[1],
		"generation": generation,
		"local_origin": _aisle_start(),
		"walk_target": _bunk_local,
	}
	for _round_index in 16:
		await _drive_round()


func _presented(client, entity_id: StringName) -> Dictionary:
	return (client._moving_replica_samples.get(entity_id, {}) as Dictionary).duplicate(true)


# --- reporting and teardown -------------------------------------------------


func _report_summary() -> void:
	var audit: Dictionary = _presenter.get_presentation_audit()
	print("PRESENTATION_SUMMARY %s" % JSON.stringify({
		"server_ticks": _server_tick,
		"delivered_packets": _shim.delivered,
		"reconciles": int(audit.get("reconcile_count", 0)),
		"avatars_spawned": int(audit.get("spawn_count", 0)),
		"avatars_released": int(audit.get("release_count", 0)),
		"frames_applied": int(audit.get("applied_count", 0)),
		"drawn_entities": int(audit.get("drawn_entities", 0)),
	}))
	_check(int(audit.get("spawn_count", 0)) == int(audit.get("release_count", 0)),
		"every avatar the sweep spawned was released again (%d spawned, %d released)"
			% [int(audit.get("spawn_count", 0)), int(audit.get("release_count", 0))])
	# Nothing the remote cabin does may reach the person hosting the session:
	# their own body is simulated locally and never replicated.
	_check(is_instance_valid(_server_player)
		and _server_player.global_position.distance_to(_server_player_origin) < 1.0
		and _server_player.get_parent() != null,
		"the server's own player is untouched by the whole presentation sweep")


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
	if _presenter != null and is_instance_valid(_presenter):
		_presenter.detach(&"suite_finished")
	if _server != null:
		_server.set_moving_interior_transport_hook(Callable())
	for adapter in _adapters:
		adapter.shutdown()
	if _presenter_holder != null and is_instance_valid(_presenter_holder):
		if _presenter_holder.get_parent() != null:
			_presenter_holder.get_parent().remove_child(_presenter_holder)
		_presenter_holder.free()
	_presenter_holder = null
	_presenter = null
	for branch in _branches:
		var path := branch.get_path()
		branch.free()
		set_multiplayer(null, path)
	_branches.clear()
	_adapters.clear()
	_server = null
	_viewer = null
	_crew_client = null
	_shim = null
	if _game != null and is_instance_valid(_game):
		if _game.get_parent() != null:
			_game.get_parent().remove_child(_game)
		_game.free()
		_game = null
	await process_frame
	if _failures.is_empty():
		print("NETWORK_MOVING_INTERIOR_PRESENTATION_TEST_OK (%d assertions)" % _assertions)
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
