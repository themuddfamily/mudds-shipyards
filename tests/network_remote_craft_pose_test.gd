extends "res://tests/in_flight_cabin_integration_test.gd"

## Host-authoritative craft pose, the remote pilot drawn in the seat, and ship
## ownership for a pilot grant -- over a real loopback ENet session.
##
## The host is the whole production `Main` subtree. Two bare client adapters
## join it: a pilot that claims the Halyard's pilot seat through the ledger and
## streams its helm, and a crewmate that only watches. Each client runs its own
## `NetworkRemoteCraftPoseStream` off its adapter's `snapshot_applied`, exactly
## the way a client `GameFlow` does, and drives a stand-in craft body with it.
##
## What is asserted:
##   A. (ownership) every production craft is registered unowned when the host
##      starts, and the ledger pilot grant names the pilot peer the Halyard's
##      owner through `claim_ship_for_peer()`; the owner record reaches the
##      clients in the canonical snapshot;
##   B. (pose, host half) the host publishes the Halyard's pose -- position,
##      rotation, velocity, owner = pilot peer -- on the authoritative snapshot
##      path, and both clients receive it close to where the host's craft is;
##   C. (pose, pilot half) a local copy started 3 m off the host's pose is
##      pulled onto it smoothly, and one 40 m off is snapped in a single tick;
##   D. (pose, observer half) a crewmate's copy follows the host's craft by
##      interpolation while it flies;
##   E. (seat) the crewmate is sent the remote pilot as a SEATED occupant under
##      the pilot's avatar id; the pilot itself is not sent its own echo;
##   F. (ownership release) the ledger disembark releases the owner record,
##      a fresh grant claims it again, and the pilot's disconnect releases it.
##
## Named `network_*` so the matrix gives it the per-run flock lane: it opens
## real `ENetMultiplayerPeer` sockets.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const BoardingIntent := preload("res://scripts/network/network_boarding_intent.gd")
const RemotePilotSource := preload("res://scripts/network/network_remote_pilot_command_source.gd")
const PoseStream := preload("res://scripts/network/network_remote_craft_pose_stream.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

const SHIP_ID: StringName = &"halyard_new_design"
const FRAME_ID: StringName = &"frame_halyard_new_design"
const PILOT_SEAT: StringName = &"halyard_new_design_pilot"
const TICK := 1.0 / 60.0


## A stand-in for a client's local copy of the craft: the stream only needs a
## `CharacterBody3D` that answers `get_ship_id()`.
class CraftProxy extends CharacterBody3D:
	var proxy_ship_id: StringName = &""

	func get_ship_id() -> StringName:
		return proxy_ship_id


var _host: GameFlow = null
var _craft: HeroShip = null
var _server = null
var _pilot: Adapter = null
var _crewmate: Adapter = null
var _pilot_stream := PoseStream.new()
var _crew_stream := PoseStream.new()
var _crew_snapshots: Array = []
var _boarding_results: Array = []
var _boarding_sequence := -1
var _helm_sequence := 0
var _helm_stamp := -1
var _full_throttle: ShipCommand = null


func _run() -> void:
	if await _build():
		await _assert_a_grant_claims_ownership()
		await _assert_b_host_publishes_the_pose()
		await _assert_c_the_pilot_copy_is_reconciled()
		await _assert_d_the_crewmate_copy_interpolates()
		await _assert_e_the_remote_pilot_is_seated()
		await _assert_f_ownership_is_released()
	await _finish_pose_suite()


func _build() -> bool:
	Engine.max_physics_steps_per_frame = 1
	_full_throttle = ShipCommand.from_dictionary({
		"schema_version": ShipCommand.SCHEMA_VERSION, "sequence": 0, "timestamp_usec": 0,
		"stream_id": 0, "throttle": 1.0,
	})
	_host = MAIN_SCENE.instantiate() as GameFlow
	if _host == null:
		_check(false, "the production scene instantiates as the session host")
		return false
	_host.name = "PoseHostMain"
	root.add_child(_host)
	await process_frame
	await physics_frame
	_host.start_shift()
	await process_frame
	await physics_frame
	_craft = _host.get_node_or_null("HalyardCrewTransport") as HeroShip
	_check(_craft != null and _craft.get_ship_id() == SHIP_ID,
		"the host's subtree supplies the Halyard a remote pilot will fly")
	if _craft == null:
		return false
	# Offline pool construction must not create a network presentation service.
	var offline_pool := _host._ensure_player_bolt_pool()
	_check(_host.get_network_remote_projectile_replicator() == null,
		"solo hauler pool construction does not create a replicator")
	offline_pool.free()
	_check(_host.get_player_bolt_pool() == null, "hosting starts without a player bolt pool")
	set_multiplayer(SceneMultiplayer.new(), _host.get_path())
	var adapters: Array = []
	for index in 2:
		var branch := SubViewport.new()
		branch.name = "PosePeer%d" % index
		root.add_child(branch)
		set_multiplayer(SceneMultiplayer.new(), branch.get_path())
		var adapter := Adapter.new()
		adapter.name = GameFlow.NETWORK_SESSION_NODE_NAME
		branch.add_child(adapter)
		adapters.append(adapter)
	_pilot = adapters[0]
	_crewmate = adapters[1]
	_pilot_stream.bind_replica_craft_presentations(_host.ships)
	_crew_stream.bind_replica_craft_presentations(_host.ships)
	_pilot.snapshot_applied.connect(func(result: Dictionary) -> void:
		_pilot_stream.consume_movement_section(_movement_of(result)))
	_crewmate.snapshot_applied.connect(func(result: Dictionary) -> void:
		_crew_snapshots.append(result.duplicate(true))
		_crew_stream.consume_movement_section(_movement_of(result)))
	var probe := UDPServer.new()
	if probe.listen(0, "127.0.0.1") != OK:
		_check(false, "reserve a loopback port")
		return false
	var port := probe.get_local_port()
	probe.stop()
	_host._ensure_lan_discovery().discovery_port = 0
	_check(bool(_host.host_network_session(port, 4).get("accepted", false)),
		"the host GameFlow opens the authoritative session")
	_server = _host.get_network_session()
	if _server == null:
		return false
	_assert_first_host_slug_is_published()
	_server.boarding_intent_result.connect(func(result: Dictionary) -> void:
		_boarding_results.append(result.duplicate(true)))
	_pilot.join("127.0.0.1", port)
	_crewmate.join("127.0.0.1", port)
	var offered := await _wait_until(
		func() -> bool: return not _pilot.get_server_offer().is_empty() \
			and not _crewmate.get_server_offer().is_empty(), 10.0
	)
	_check(offered, "both peers are admitted and hold the host's offer")
	return offered


## No await or network advance may occur between hosting, launch and these
## checks: that is the first-shot window the production pool used to miss.
func _assert_first_host_slug_is_published() -> void:
	var hauler: HeroShip = null
	for fleet_ship in _host.ships:
		if is_instance_valid(fleet_ship) and fleet_ship.get_ship_id() == GameFlow.CINDER_CARGO_SHIP_ID:
			hauler = fleet_ship
			break
	_check(hauler != null, "the host supplies the production Cinder hauler")
	if hauler == null:
		return
	var weapon_id := _host._get_player_combat_weapon_id(hauler)
	_check(_host._player_weapon_is_travelling(hauler, weapon_id),
		"the production hauler weapon uses travelling bolts")
	_check(_host.get_player_bolt_pool() == null, "the first host slug creates its pool lazily")
	var launch := _host._launch_player_travelling_bolt(
		hauler, weapon_id, hauler.global_position - hauler.global_basis.z * 7.0,
		-hauler.global_basis.z
	)
	_check(bool(launch.get("accepted", false)), "the host accepts its first hauler slug")
	var replicator := _host.get_network_remote_projectile_replicator()
	_check(replicator != null, "the first launch already has a network observer")
	if replicator == null:
		return
	var audit := replicator.get_audit()
	_check(int(audit.get("published", 0)) == 1 and int(audit.get("active_flights", 0)) == 1,
		"the first slug publishes one launch before any physics tick")
	# A source retirement is a real terminal, without waiting for world collision.
	_host.get_player_bolt_pool().abandon_all(&"test_source_retired")
	audit = replicator.get_audit()
	_check(int(audit.get("published", 0)) == 2 and int(audit.get("active_flights", -1)) == 0
		and int(audit.get("publish_failures", -1)) == 0,
		"the first slug also publishes its terminal and retires the replicated flight")


# --- A ------------------------------------------------------------------------


func _assert_a_grant_claims_ownership() -> void:
	var registered := 0
	for fleet_ship in _host.ships:
		if is_instance_valid(fleet_ship) and not (_server.get_owned_ship(fleet_ship.get_ship_id()) as Dictionary).is_empty():
			registered += 1
	_check(registered == _host.ships.size() and registered > 0,
		"every production craft has an ownership record from the first tick (%d/%d)"
			% [registered, _host.ships.size()])
	_check(int(_server.get_owned_ship(SHIP_ID).get("owner_peer_id", -1)) == 0,
		"the Halyard starts unowned")
	var granted := await _board(BoardingIntent.ACTION_BOARD)
	_check(granted.get("status") == &"boarded", "the ledger seats the pilot at the Halyard's helm")
	await _drive(2)
	_check(_craft.get_command_source() is RemotePilotSource,
		"the grant bound the helm (ownership did not refuse it)")
	_check(int(_server.get_owned_ship(SHIP_ID).get("owner_peer_id", 0)) == _pilot_id(),
		"the pilot grant is a claim_ship_for_peer(): the pilot owns the Halyard")
	var replicated := await _wait_until(func() -> bool:
		for record in _latest_crew_section(&"ownership"):
			if StringName((record as Dictionary).get("ship_id", &"")) == SHIP_ID \
					and int((record as Dictionary).get("owner_peer_id", 0)) == _pilot_id():
				return true
		return false, 4.0)
	_check(replicated, "the owner record reaches the crewmate in the canonical snapshot")


# --- B ------------------------------------------------------------------------


func _assert_b_host_publishes_the_pose() -> void:
	# Pose reconciliation below models unobstructed flight. Lift the real craft
	# clear of berth/station collision before comparing it with shapeless proxies.
	_craft.global_position += Vector3.UP * 200.0
	_craft.reset_physics_interpolation()
	var flight_origin := _craft.global_position
	for frame in 90:
		_fly_frame(frame)
		await physics_frame
		await process_frame
	_check(_craft.global_position.distance_to(flight_origin) > 5.0,
		"the pose fixture flies through clear space before replica checks")
	var pose_id := PoseStream.pose_entity_id(SHIP_ID)
	# Poses go out on every third authority tick, so the newest snapshot need
	# not carry one; the newest one that does is the record under test.
	var entry: Dictionary = {}
	for index in range(_crew_snapshots.size() - 1, -1, -1):
		var result := _crew_snapshots[index] as Dictionary
		if not bool(result.get("accepted", false)):
			continue
		for record in _movement_of(result):
			if StringName((record as Dictionary).get("entity_id", &"")) == pose_id:
				entry = record as Dictionary
		if not entry.is_empty():
			break
	_check(not entry.is_empty() and StringName(entry.get("mode", &"")) == PoseStream.MODE,
		"the host's authoritative snapshot carries the Halyard's pose record")
	_check(int(entry.get("owner_peer_id", 0)) == _pilot_id(),
		"the pose record names the remote pilot as the craft's pilot")
	var validated := _crew_stream.latest_sample(SHIP_ID)
	_check(validated.get("rotation") is Quaternion and validated.get("velocity_world") is Vector3,
		"the pose carries rotation and velocity, not only a position")
	for stream in [_pilot_stream, _crew_stream]:
		var latest: Dictionary = (stream as PoseStream).latest_sample(SHIP_ID)
		var error := _craft.global_position.distance_to(latest.get("position", Vector3.INF) as Vector3) \
			if not latest.is_empty() else INF
		var slack := 1.5 + _craft.velocity.length() * 0.35
		_check(error <= slack,
			"a client's newest pose sample is where the host's craft is (%.2f m, allowed %.2f m)"
				% [error, slack])


# --- C ------------------------------------------------------------------------


func _assert_c_the_pilot_copy_is_reconciled() -> void:
	var proxy := _spawn_proxy("PilotCopy")
	proxy.global_transform = Transform3D(_craft.global_basis, _craft.global_position + Vector3(3.0, 0.0, 0.0))
	var initial := proxy.global_position.distance_to(_craft.global_position)
	var worst_step := 0.0
	for frame in 120:
		_fly_frame(frame)
		await physics_frame
		await process_frame
		var before := proxy.global_position
		# A perfect local simulation: the copy flies exactly as the host's
		# craft does, and carries only the initial offset as its error.
		proxy.velocity = _craft.velocity
		proxy.global_position += proxy.velocity * TICK
		_pilot_stream.advance_replica(
			[proxy], proxy, null, float(_pilot.get_round_trip_milliseconds()), TICK
		)
		worst_step = maxf(worst_step, (proxy.global_position - before - proxy.velocity * TICK).length())
	var settled := proxy.global_position.distance_to(_craft.global_position)
	# The pilot's copy is meant to lead the host's by the helm's send
	# quantisation, so a fast craft settles a little ahead of it.
	var settle_slack := 1.5 + _craft.velocity.length() * 0.1
	_check(settled < settle_slack and settled < initial,
		"a local copy 3 m off the host's pose is pulled onto it (%.2f m -> %.2f m)" % [initial, settled])
	_check(worst_step < 1.0,
		"the correction is smooth, never a jump inside the snap threshold (worst %.2f m/tick)" % worst_step)
	proxy.global_position = _craft.global_position + Vector3(0.0, 40.0, 0.0)
	await physics_frame
	var snap: Dictionary = _pilot_stream.reconcile_pilot(
		proxy, SHIP_ID, float(_pilot.get_round_trip_milliseconds()), TICK
	)
	_check(snap.get("status") == &"snapped"
		and proxy.global_position.distance_to(_craft.global_position) < 3.0 + _craft.velocity.length() * 0.5,
		"a copy 40 m off is snapped onto the host's pose in one tick (%s)" % String(snap.get("status", &"")))
	proxy.queue_free()


# --- D ------------------------------------------------------------------------


func _assert_d_the_crewmate_copy_interpolates() -> void:
	var proxy := _spawn_proxy("CrewmateCopy")
	proxy.global_position = _craft.global_position + Vector3(0.0, -25.0, 0.0)
	var origin := proxy.global_position
	var worst := 0.0
	for frame in 90:
		_fly_frame(frame)
		await physics_frame
		await process_frame
		_crew_stream.advance_replica([proxy], null, null, 0.0, TICK)
		if frame >= 30:
			worst = maxf(worst, proxy.global_position.distance_to(_craft.global_position))
	var slack := 2.0 + _craft.velocity.length() * 0.4
	_check(proxy.global_position.distance_to(origin) > 5.0,
		"the crewmate's copy of the Halyard left where it was parked")
	_check(worst <= slack,
		"the crewmate's copy follows the host's craft by interpolation (worst %.2f m, allowed %.2f m)"
			% [worst, slack])
	proxy.queue_free()


# --- E ------------------------------------------------------------------------


func _assert_e_the_remote_pilot_is_seated() -> void:
	var avatar := GameFlow.network_client_boarding_avatar_id(_pilot_id())
	var seated := await _wait_until(
		func() -> bool: return _crewmate.get_moving_interior_occupancy_state(avatar) == Relationship.STATE_SEATED,
		4.0
	)
	_check(seated, "the crewmate is sent the remote pilot sitting in the Halyard's pilot seat")
	var relationship: Dictionary = _crewmate.get_moving_interior_latest_relationship(avatar)
	_check(StringName(relationship.get("parent_frame_id", &"")) == FRAME_ID,
		"the seated pilot is expressed in the Halyard's own moving frame")
	_check(_pilot.get_moving_interior_latest_relationship(avatar).is_empty(),
		"the pilot is not sent its own echo in the seat")


# --- F ------------------------------------------------------------------------


func _assert_f_ownership_is_released() -> void:
	var left := await _board(BoardingIntent.ACTION_DISEMBARK)
	_check(left.get("status") == &"disembarked", "the remote pilot leaves the seat through the ledger")
	await _drive(2)
	_check(int(_server.get_owned_ship(SHIP_ID).get("owner_peer_id", -1)) == 0,
		"the ledger disembark releases the pilot's ownership of the Halyard")
	var again := await _board(BoardingIntent.ACTION_BOARD)
	await _drive(2)
	_check(again.get("status") == &"boarded"
		and int(_server.get_owned_ship(SHIP_ID).get("owner_peer_id", 0)) == _pilot_id(),
		"a fresh grant claims the Halyard again")
	var pilot_id := _pilot_id()
	_pilot.shutdown(&"pilot_dropped")
	var released := await _wait_until(
		func() -> bool: return int(_server.get_owned_ship(SHIP_ID).get("owner_peer_id", -1)) == 0, 12.0
	)
	_check(released and pilot_id > 1, "the pilot's disconnect releases its ownership of the Halyard")


# --- helpers ------------------------------------------------------------------


func _pilot_id() -> int:
	return _pilot.multiplayer.get_unique_id() if is_instance_valid(_pilot) and _pilot.is_inside_tree() else 0


func _movement_of(result: Dictionary) -> Array:
	var sections := (result.get("snapshot", {}) as Dictionary).get("sections", {}) as Dictionary
	return sections.get(&"movement", sections.get("movement", [])) as Array


func _latest_crew_section(section: StringName) -> Array:
	for index in range(_crew_snapshots.size() - 1, -1, -1):
		var result := _crew_snapshots[index] as Dictionary
		if not bool(result.get("accepted", false)):
			continue
		var sections := (result.get("snapshot", {}) as Dictionary).get("sections", {}) as Dictionary
		return sections.get(section, sections.get(String(section), [])) as Array
	return []


func _spawn_proxy(proxy_name: String) -> CraftProxy:
	var proxy := CraftProxy.new()
	proxy.name = proxy_name
	proxy.proxy_ship_id = SHIP_ID
	root.add_child(proxy)
	return proxy


func _fly_frame(frame: int) -> void:
	if frame % RemotePilotSource.SEND_INTERVAL_TICKS != 0 or not is_instance_valid(_pilot):
		return
	_helm_stamp = maxi(_pilot.get_boarding_server_tick_estimate(), _helm_stamp + 1)
	_pilot.send_movement_intent(RemotePilotSource.build_helm_intent(
		_pilot_id(), SHIP_ID, 1, _helm_sequence, _helm_stamp, _full_throttle
	))
	_helm_sequence += 1


func _board(action: StringName) -> Dictionary:
	_boarding_results.clear()
	_boarding_sequence += 1
	var intent = BoardingIntent.create(
		_pilot_id(), GameFlow.network_client_boarding_avatar_id(_pilot_id()), SHIP_ID, 1, FRAME_ID, 1,
		PILOT_SEAT, 1, &"pilot", _boarding_sequence,
		_pilot.get_boarding_server_tick_estimate(), action
	)
	_pilot.send_boarding_intent(intent.to_dictionary())
	await _wait_until(func() -> bool: return not _boarding_results.is_empty(), 4.0)
	if action == BoardingIntent.ACTION_BOARD:
		# A new helm binding starts a new command stream on the host.
		_helm_sequence = 0
	return {} if _boarding_results.is_empty() else _boarding_results[0] as Dictionary


func _drive(rounds: int) -> void:
	for _round in maxi(1, rounds):
		await physics_frame
		await process_frame


func _finish_pose_suite() -> void:
	if is_instance_valid(_host):
		_host.shutdown_network_session(&"suite_complete")
		await process_frame
	for adapter in [_pilot, _crewmate]:
		if is_instance_valid(adapter):
			adapter.shutdown(&"suite_complete")
	await process_frame
	if _failures.is_empty():
		print("NETWORK_REMOTE_CRAFT_POSE_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
		return
	print("NETWORK_REMOTE_CRAFT_POSE_TEST_FAILED: %d/%d assertions failed: %s"
		% [_failures.size(), _assertion_count, ", ".join(_failures)])
	quit(1)
