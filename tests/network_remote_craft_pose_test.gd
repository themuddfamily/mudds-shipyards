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
	var last_ship_command: ShipCommand = null
	var command_source: ShipCommandSource = null
	var barrel_roll_active := false

	func get_ship_id() -> StringName:
		return proxy_ship_id

	func get_last_ship_command() -> ShipCommand:
		return last_ship_command

	func get_command_source() -> ShipCommandSource:
		return command_source

	func is_barrel_roll_active() -> bool:
		return barrel_roll_active


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
		if OS.get_cmdline_user_args().has("--hull-instruments-only"):
			_assert_remote_hull_instruments()
			await _finish_pose_suite()
			return
		_assert_remote_throttle_instruments()
		if OS.get_cmdline_user_args().has("--throttle-instruments-only"):
			await _finish_pose_suite()
			return
		_assert_remote_hull_instruments()
		await _assert_a_grant_claims_ownership()
		await _assert_b_host_publishes_the_pose()
		await _assert_c_the_pilot_copy_is_reconciled()
		_assert_c_neutral_pilot_rotation_settles()
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


## Exercise the physical Jovian repeater after the same local presentation pass
## that used to overwrite a remote host's throttle with the observer's zero.
func _assert_remote_throttle_instruments() -> void:
	var ship := _host.get_node("JovianLightFreighter") as HeroShip
	var was_processing := ship.is_physics_processing()
	ship.set_physics_process(false)
	var engine: Variant = ship.get("_engine_state")
	var throttle := float(ship.get("_throttle"))
	var piloted := bool(ship.get("_piloted"))
	var velocity := ship.velocity
	var source := ship.get_command_source()
	ship.set("_piloted", false)
	var readout := ship.get("_cockpit_readout") as Label3D
	var physical := readout.get_node("LiveFlightInstruments/LiveStatusRepeaters/ThrottleReadout") as Label3D
	for host_throttle: float in [0.65, -0.45]:
		ship.set("_engine_state", HeroShip.ENGINE_ONLINE)
		ship.set("_throttle", host_throttle)
		ship._update_presentation(TICK, ShipCommand.new())
		var entry := PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 60)
		entry["craft_epoch"] = 1
		ship.set("_engine_state", engine)
		ship.set("_throttle", throttle)
		ship.set_network_damage_presentation_enabled(true)
		for compact: bool in [false, true]:
			var stream := PoseStream.new()
			stream.bind_replica_craft_presentations([ship])
			var wire := PoseStream.pack_display_facts([entry]) if compact else [entry]
			_check(stream.consume_movement_section(wire) == 1,
				"the existing %s pose admits a signed-throttle source sample" % ("compact" if compact else "unpacked"))
			ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
			ship._update_presentation(TICK, ShipCommand.new())
			_check(physical.text == "%+03d\nTHR %%" % roundi(host_throttle * 100.0),
				"%s host throttle %+03d reaches the physical Jovian THR readout after local presentation" % ["compact" if compact else "unpacked", roundi(host_throttle * 100.0)])
			_check(ship.get("_engine_state") == engine and float(ship.get("_throttle")) == throttle
				and ship.velocity == velocity and ship.get_command_source() == source,
				"remote instrument readings retain local engine, throttle, velocity and command authority")
			ship.set("_piloted", true)
			ship._update_presentation(TICK, ShipCommand.new())
			_check(physical.text == "%+03d\nTHR %%" % roundi(throttle * 100.0),
				"this-machine pilot retains its predicted throttle instrument during host projection")
			ship.set("_piloted", false)
			ship.set("_throttle", 0.23)
			ship.clear_network_operation_presentation()
			_check(physical.text == "+23\nTHR %" and float(ship.get("_throttle")) == 0.23,
				"projection clear immediately restores the current solo throttle instrument")
			ship.set("_throttle", throttle)
		if host_throttle < 0.0:
			_assert_throttle_wire_compatibility(ship, entry, physical)
			ship.set("_engine_state", HeroShip.ENGINE_OFFLINE)
			ship.set("_throttle", host_throttle)
			ship._update_presentation(TICK, ShipCommand.new())
			var stopped := PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 63)
			stopped["craft_epoch"] = 1
			_check(float((stopped.operation_presentation as Dictionary).get("throttle", INF)) == 0.0,
				"stopped host publishes neutral throttle even if a prior signed throttle remains")
			ship.set("_engine_state", engine)
			ship.set("_throttle", throttle)
			var stopped_stream := PoseStream.new()
			stopped_stream.bind_replica_craft_presentations([ship])
			_check(stopped_stream.consume_movement_section(PoseStream.pack_display_facts([stopped])) == 1,
				"compact stopped host operation reaches the physical instrument fixture")
			ship.apply_network_operation_presentation(stopped_stream.latest_sample(ship.get_ship_id()))
			ship._update_presentation(TICK, ShipCommand.new())
			_check(physical.text == "+00\nTHR %", "host ONLINE to OFFLINE transition neutralizes the physical throttle instrument")
			ship.clear_network_operation_presentation()
	ship.set_network_damage_presentation_enabled(false)
	ship.set("_piloted", piloted)
	ship._update_presentation(TICK, ShipCommand.new())
	ship.set_physics_process(was_processing)


## The physical hull readout must present the published health/maximum pair,
## even while the retained client simulation keeps its own healthy hull.
func _assert_remote_hull_instruments() -> void:
	var ship := _host.get_node("JovianLightFreighter") as HeroShip
	var was_processing := ship.is_physics_processing()
	ship.set_physics_process(false)
	var solo := ship.get_network_damage_presentation_snapshot()
	var velocity := ship.velocity
	var source := ship.get_command_source()
	var engine: Variant = ship.get("_engine_state")
	var throttle := float(ship.get("_throttle"))
	var piloted := bool(ship.get("_piloted"))
	var readout := ship.get("_cockpit_readout") as Label3D
	var physical := readout.get_node("LiveFlightInstruments/LiveStatusRepeaters/HullReadout") as Label3D
	var entry := PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 70)
	entry["craft_epoch"] = 1
	entry.hull_presentation["health"] = 50.0
	entry.hull_presentation["maximum_health"] = 200.0
	ship.set_network_damage_presentation_enabled(true)
	for compact: bool in [false, true]:
		var stream := PoseStream.new()
		stream.bind_replica_craft_presentations([ship])
		var wire := PoseStream.pack_display_facts([entry]) if compact else [entry]
		_check(stream.consume_movement_section(wire) == 1,
			"the existing %s pose admits an authoritative hull source sample" % ("compact" if compact else "unpacked"))
		_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
			"the existing hull presentation accepts the %s host sample" % ("compact" if compact else "unpacked"))
		_assert_hull_instrument(ship, 0.25, "host hull reaches physical text, arc and critical color immediately")
		ship._update_presentation(TICK, ShipCommand.new())
		_check(physical.text == "025\nHULL %",
			"%s host hull 025 reaches the physical Jovian HULL readout after local presentation" % ("compact" if compact else "unpacked"))
		ship.set("_piloted", true)
		ship._update_presentation(TICK, ShipCommand.new())
		_assert_hull_instrument(ship, 0.25, "eligible remote-owned pilot reads host hull while keeping predicted throttle")
		var dead := entry.duplicate(true)
		dead.pose_tick = 71
		dead.operation_tick = 71
		dead.destroyed = true
		dead.hull_presentation.health = 0.0
		var revived := entry.duplicate(true)
		revived.pose_tick = 72
		revived.operation_tick = 72
		revived.entity_generation = int(entry.entity_generation) + 1
		revived.hull_presentation.component_generation = revived.entity_generation
		revived.hull_presentation.health = 180.0
		revived.hull_presentation.maximum_health = 240.0
		for transition: Dictionary in [dead, revived]:
			var transition_wire := PoseStream.pack_display_facts([transition]) if compact else [transition]
			_check(stream.consume_movement_section(transition_wire) == 1,
				"existing pose admits hull destruction or next-generation revival")
			_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
				"validated hull lifecycle transition reaches the physical instrument owner")
			ship._update_presentation(TICK, ShipCommand.new())
			_assert_hull_instrument(ship, 0.0 if bool(transition.destroyed) else 0.75,
				"physical hull text, arc and color follow destruction and new-generation revival")
		_check(not bool(ship.apply_network_damage_presentation(dead).get("applied", false)),
			"old terminal life cannot overwrite the revived instrument")
		_assert_hull_instrument(ship, 0.75, "rejected old terminal life retains the revived physical hull gauge")
		_check(ship.get_network_damage_presentation_snapshot() == solo
			and ship.velocity == velocity and ship.get_command_source() == source
			and ship.get("_engine_state") == engine and float(ship.get("_throttle")) == throttle,
			"remote hull lifecycle retains local hull, components, engine, throttle, velocity and command authority")
		# A local change during projection must be read when the display clears.
		ship.set("_hull", ship.maximum_hull * 0.8)
		ship.clear_network_damage_presentation()
		_assert_hull_instrument(ship, 0.8, "hull clear immediately restores current local text, arc and healthy color")
		ship.set("_hull", solo.health)
		ship.set("_piloted", piloted)
	ship.set_network_damage_presentation_enabled(false)
	ship._update_presentation(TICK, ShipCommand.new())
	ship.set_physics_process(was_processing)


func _assert_hull_instrument(ship: HeroShip, expected: float, description: String) -> void:
	var readout := ship.get("_cockpit_readout") as Label3D
	var physical := readout.get_node("LiveFlightInstruments/LiveStatusRepeaters/HullReadout") as Label3D
	var dial := readout.get_node("LiveFlightInstruments/LiveStatusRepeaters/HullGauge") as MeshInstance3D
	var color := Color("ff6b5f") if expected <= 0.3 else Color("8de8e4")
	_check(physical.text == "%03d\nHULL %%" % roundi(expected * 100.0)
		and is_equal_approx(float(dial.get_instance_shader_parameter(&"fill")), expected)
		and physical.modulate == color and dial.get_instance_shader_parameter(&"ink") == color, description)


func _assert_throttle_wire_compatibility(ship: HeroShip, entry: Dictionary, physical: Label3D) -> void:
	var wire := PoseStream.pack_display_facts([entry])
	var facts: Array = bytes_to_var(wire[0].display_facts.decompress(int(wire[0].display_size), FileAccess.COMPRESSION_ZSTD))
	ship.apply_network_operation_presentation(entry)
	ship._update_presentation(TICK, ShipCommand.new())
	_check(facts[0][9].size() == 10 and wire[0].get("operation_throttle") == entry.operation_presentation.throttle,
		"signed throttle uses an optional primitive header while preserving the original ten-field packed row")
	var legacy := wire.duplicate(true)
	legacy[0].erase("operation_throttle")
	var receiver := PoseStream.new()
	receiver.bind_replica_craft_presentations([ship])
	_check(receiver.consume_movement_section(legacy) == 1,
		"legacy ten-field compact operation rows remain accepted")
	ship.apply_network_operation_presentation(receiver.latest_sample(ship.get_ship_id()))
	ship._update_presentation(TICK, ShipCommand.new())
	_check(physical.text == "+00\nTHR %", "legacy compact rows use neutral display instead of stale host throttle")
	ship.clear_network_operation_presentation()
	var unpacked_legacy := entry.duplicate(true)
	unpacked_legacy.operation_presentation.erase("throttle")
	var unpacked_receiver := PoseStream.new()
	unpacked_receiver.bind_replica_craft_presentations([ship])
	_check(unpacked_receiver.consume_movement_section([unpacked_legacy]) == 1,
		"legacy unpacked operation facts remain accepted")
	ship.apply_network_operation_presentation(entry)
	ship.apply_network_operation_presentation(unpacked_receiver.latest_sample(ship.get_ship_id()))
	ship._update_presentation(TICK, ShipCommand.new())
	_check(physical.text == "+00\nTHR %", "legacy unpacked facts replace stale host throttle with neutral display")
	ship.clear_network_operation_presentation()
	var refused := true
	for invalid: Variant in [NAN, INF, -INF, 1.01, -1.01, "0.5", true]:
		var unpacked := entry.duplicate(true)
		unpacked.operation_presentation["throttle"] = invalid
		var packed := wire.duplicate(true)
		packed[0]["operation_throttle"] = invalid
		for rows: Array in [[unpacked], packed]:
			var probe := PoseStream.new()
			probe.bind_replica_craft_presentations([ship])
			refused = probe.consume_movement_section(rows) == 0 and refused
	_check(refused, "unpacked and compact operation facts reject nonfinite, out-of-range and nonnumeric throttle")


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
	_print_pilot_pose_diagnostic("initial", proxy, {}, _craft.global_position, Engine.get_physics_frames(), proxy.global_position)
	for frame in 120:
		var host_before := _craft.global_position
		var physics_before := Engine.get_physics_frames()
		_fly_frame(frame)
		await physics_frame
		await process_frame
		var before := proxy.global_position
		# A perfect local simulation: the copy flies exactly as the host's
		# craft does, and carries only the initial offset as its error.
		proxy.velocity = _craft.velocity
		proxy.global_position += proxy.velocity * TICK
		var pre_reconcile_position := proxy.global_position
		var replica_verdict := _pilot_stream.advance_replica(
			[proxy], proxy, null, float(_pilot.get_round_trip_milliseconds()), TICK
		)
		worst_step = maxf(worst_step, (proxy.global_position - before - proxy.velocity * TICK).length())
		if frame in [0, 29, 59, 89, 119]:
			_print_pilot_pose_diagnostic("frame_%d" % frame, proxy, replica_verdict, host_before, physics_before, pre_reconcile_position)
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


func _assert_c_neutral_pilot_rotation_settles() -> void:
	var proxy := _spawn_proxy("NeutralPilotCopy")
	var stream := PoseStream.new()
	var pose := PoseStream.build_pose_entry(proxy, SHIP_ID, _pilot_id(), 0)
	_check(stream.consume_movement_section([pose]) == 1, "neutral rotation fixture accepts the authoritative pose")
	var target: Quaternion = pose.rotation
	var residual := Basis(Quaternion(Vector3.UP, deg_to_rad(2.7722)))
	proxy.global_basis = residual
	var verdict := stream.reconcile_pilot(proxy, SHIP_ID, 0.0, TICK)
	_check(verdict.status == &"within_deadband" and proxy.global_basis.is_equal_approx(residual),
		"a proxy without a current command retains the rotation deadband")
	var source := ShipCommandSource.new()
	proxy.add_child(source)
	proxy.command_source = source
	for axis: String in ["yaw", "pitch", "roll", "look_yaw_delta", "look_pitch_delta", "barrel_roll", "hover"]:
		var values := source.next_command().to_dictionary()
		values[axis] = true if axis in ["barrel_roll", "hover"] else 0.5
		proxy.last_ship_command = ShipCommand.from_dictionary(values)
		proxy.global_basis = residual
		verdict = stream.reconcile_pilot(proxy, SHIP_ID, 0.0, TICK)
		_check(verdict.status == &"within_deadband" and proxy.global_basis.is_equal_approx(residual),
			"active %s retains the existing below-deadband prediction policy" % axis)
	# Above the deadband, steering still uses the existing exponential blend.
	var active_rotation := Quaternion(Vector3.UP, 0.1)
	proxy.global_basis = Basis(active_rotation)
	verdict = stream.reconcile_pilot(proxy, SHIP_ID, 0.0, TICK)
	var expected := active_rotation.slerp(target, 1.0 - exp(-PoseStream.ROTATION_CORRECTION_RATE * TICK))
	_check(verdict.status == &"corrected" and proxy.global_basis.is_equal_approx(Basis(expected)),
		"active steering above the rotation deadband keeps the same correction rate")
	proxy.last_ship_command = source.next_command()
	proxy.barrel_roll_active = true
	proxy.global_basis = residual
	verdict = stream.reconcile_pilot(proxy, SHIP_ID, 0.0, TICK)
	_check(verdict.status == &"within_deadband" and proxy.global_basis.is_equal_approx(residual),
		"an ongoing barrel roll retains the rotation deadband after its command edge is released")
	proxy.barrel_roll_active = false
	# A neutral snapshot must still belong to the current enabled owner source.
	for boundary: String in ["invalid_command", "disabled_source", "non_owner", "revoked_stream"]:
		proxy.last_ship_command = source.next_command()
		match boundary:
			"invalid_command": proxy.last_ship_command = ShipCommand.from_dictionary({})
			"disabled_source": source.enabled = false
			"non_owner": source.set_local_peer_id_override(2)
			"revoked_stream": source.invalidate_pending_commands()
		proxy.global_basis = residual
		verdict = stream.reconcile_pilot(proxy, SHIP_ID, 0.0, TICK)
		_check(verdict.status == &"within_deadband" and proxy.global_basis.is_equal_approx(residual),
			"%s cannot enable neutral rotation correction" % boundary)
		source.enabled = true
		source.set_local_peer_id_override(0)
	# Both a released helm and straight-ahead powered flight must converge.
	for throttle: float in [0.0, 1.0]:
		proxy.global_basis = residual
		var previous_angle := proxy.global_basis.get_rotation_quaternion().angle_to(target)
		var initial_angle := previous_angle
		var worst_step := 0.0
		var monotonic := true
		var first_step_corrected := false
		for frame in 120:
			if frame % PoseStream.PUBLISH_INTERVAL_TICKS == 0:
				pose["pose_tick"] = frame + 3 + int(throttle) * 120
				stream.consume_movement_section([pose])
			var values := source.next_command().to_dictionary()
			values["throttle"] = throttle
			proxy.last_ship_command = ShipCommand.from_dictionary(values)
			var report := stream.advance_replica([proxy], proxy, null, 0.0, TICK)
			var angle := proxy.global_basis.orthonormalized().get_rotation_quaternion().angle_to(target)
			if frame == 0:
				first_step_corrected = int(report.corrected) == 1 and angle < previous_angle
			monotonic = monotonic and angle <= previous_angle + 0.00001
			worst_step = maxf(worst_step, absf(previous_angle - angle))
			previous_angle = angle
		_check(first_step_corrected and worst_step < deg_to_rad(0.25) and monotonic,
			"neutral rotation at throttle %.0f blends smoothly from its first tick" % throttle)
		_check(previous_angle < deg_to_rad(2.0) and previous_angle < initial_angle,
			"neutral rotation at throttle %.0f settles below two degrees within two seconds (%.4f degrees)"
			% [throttle, rad_to_deg(previous_angle)])
	proxy.queue_free()


func _print_pilot_pose_diagnostic(label: String, proxy: CraftProxy, replica_verdict: Dictionary, host_before: Vector3, physics_before: int, pre_reconcile_position: Vector3) -> void:
	var sample := _pilot_stream.latest_sample(SHIP_ID)
	var clock := _pilot_stream.get_clock()
	var rtt_ms := _pilot.get_round_trip_milliseconds()
	var lead_ticks := clampf(maxf(0.0, clock - float(sample.get("pose_tick", 0)))
		+ maxf(0.0, float(rtt_ms)) / 1000.0 / PoseStream.TICK_SECONDS
		+ PoseStream.HELM_QUANTIZATION_TICKS, 0.0, PoseStream.MAX_LEAD_TICKS)
	var sample_position: Vector3 = sample.get("position", Vector3.ZERO)
	var sample_velocity: Vector3 = sample.get("velocity_world", Vector3.ZERO)
	var target := sample_position + sample_velocity * lead_ticks * PoseStream.TICK_SECONDS
	var offset := proxy.global_position - _craft.global_position
	var direction := _craft.velocity.normalized()
	var along := offset.dot(direction)
	print("PILOT_POSE_DIAGNOSTIC: ", {
		"point": label, "physics_frame": Engine.get_physics_frames(),
		"physics_frames_elapsed": Engine.get_physics_frames() - physics_before,
		"rtt_ms": rtt_ms, "pose_tick": sample.get("pose_tick", -1),
		"stream_clock": clock, "stream_audit": _pilot_stream.get_audit(),
		"lead_ticks": lead_ticks, "sample_position": sample_position,
		"sample_velocity": sample_velocity, "target_position": target,
		"advance_verdict": replica_verdict,
		"host_position": _craft.global_position, "host_velocity": _craft.velocity,
		"host_actual_step": _craft.global_position - host_before,
		"proxy_position": proxy.global_position, "proxy_velocity": proxy.velocity,
		"proxy_simulated_step": _craft.velocity * TICK,
		"pre_reconcile_position": pre_reconcile_position,
		"correction_applied": proxy.global_position - pre_reconcile_position,
		"target_error_before": target - pre_reconcile_position,
		"host_offset": offset, "along_track_offset": along,
		"cross_track_offset": (offset - direction * along).length(),
		"target_error": target - proxy.global_position,
	})


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
	var source_before := _craft.get_command_source()
	var owner_before: Dictionary = _server.get_owned_ship(SHIP_ID).duplicate(true)
	var claim_before: Array = _server.get_boarding_snapshot().get("occupancies", []).duplicate(true)
	var unsafe := await _board(BoardingIntent.ACTION_DISEMBARK)
	print("POSE_AIRBORNE_DEPARTURE: ", {"result": unsafe, "telemetry": _craft.get_telemetry(),
		"same_owner": _server.get_owned_ship(SHIP_ID) == owner_before,
		"same_claim": _server.get_boarding_snapshot().get("occupancies", []) == claim_before,
		"same_source": _craft.get_command_source() == source_before})
	_check(not bool(unsafe.get("accepted", true)) and unsafe.get("status") == &"propulsion_not_offline"
		and not bool(_craft.get_telemetry().get("landed", true)),
		"airborne powered pilot departure is refused by its actual propulsion safety guard")
	_check(_server.get_owned_ship(SHIP_ID) == owner_before
		and _server.get_boarding_snapshot().get("occupancies", []) == claim_before
		and _craft.get_command_source() == source_before,
		"unsafe departure retains the exact pilot claim, ownership record and authority source")
	if not await _dock_remote_pilot_for_departure(): return
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


func _dock_remote_pilot_for_departure() -> bool:
	var berth := _host._resolve_berth_node(_craft.get_home_berth_id())
	_check(berth != null, "pilot departure resolves the registered physical home berth")
	if berth == null: return false
	# Approach setup only. A real helm landing edge must reserve, capture and
	# commit the craft; no landed flag, owner, lease or completion is assigned.
	_craft.global_transform = berth.get_dock_transform().translated_local(Vector3(0, 3, 0))
	_craft.velocity = Vector3.ZERO
	_helm_stamp = maxi(_pilot.get_boarding_server_tick_estimate(), _helm_stamp + 1)
	var sent := _pilot.send_movement_intent(RemotePilotSource.build_helm_intent(
		_pilot_id(), SHIP_ID, 1, _helm_sequence, _helm_stamp, ShipCommand.neutral(), 0, 0, 1))
	_helm_sequence += 1
	_check(bool(sent.get("accepted", false)), "pilot sends a neutral helm with a fresh landing edge")
	_check(await _wait_until(func() -> bool: return _craft.is_landing_active(), 2.0),
		"validated remote helm starts the host craft's physical landing controller")
	var docked := await _wait_until(func() -> bool: return berth.get_occupant() == _craft \
		and bool(_craft.get_telemetry().get("landed", false)), 6.0)
	_check(docked and _host._ship_owns_exact_occupied_berth(_craft, _craft.get_home_berth_id())
		and bool(_craft.get_landing_contract_report().get("strict_dock_acceptance", false))
		and _craft.global_transform.is_equal_approx(berth.get_dock_transform()),
		"real landing captures and occupies the exact physical berth before pilot departure")
	var offline := await _wait_until(func() -> bool:
		return _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_OFFLINE, 6.0)
	_check(offline, "the physically docked remote craft automatically idles OFFLINE before departure")
	return docked and offline


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
