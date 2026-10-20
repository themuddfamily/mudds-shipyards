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
		if OS.get_cmdline_user_args().has("--component-powers-only"):
			await _assert_remote_component_power_hud()
			await _finish_pose_suite()
			return
		if OS.get_cmdline_user_args().has("--component-hud-only"):
			await _assert_remote_component_hud()
			await _finish_pose_suite()
			return
		if OS.get_cmdline_user_args().has("--operation-hud-only"):
			_assert_remote_operation_hud()
			await _finish_pose_suite()
			return
		if OS.get_cmdline_user_args().has("--hull-hud-only"):
			_assert_remote_hull_hud()
			await _finish_pose_suite()
			return
		if OS.get_cmdline_user_args().has("--hull-instruments-only"):
			_assert_remote_hull_instruments()
			await _finish_pose_suite()
			return
		_assert_remote_throttle_instruments()
		if OS.get_cmdline_user_args().has("--throttle-instruments-only"):
			await _finish_pose_suite()
			return
		_assert_remote_hull_instruments()
		_assert_remote_hull_hud()
		_assert_remote_operation_hud()
		await _assert_remote_component_power_hud()
		await _assert_remote_component_hud()
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

## The HUD must consume the same accepted operation sample as the cockpit,
## while the observer's retained simulation remains OFFLINE with zero throttle.
func _assert_remote_operation_hud() -> void:
	var ship := _host.get_node("JovianLightFreighter") as HeroShip
	var previous_ship: HeroShip = _host.active_ship
	var previous_piloting: bool = _host._piloting
	var was_processing: bool = ship.is_physics_processing()
	var original_engine: Variant = ship.get("_engine_state")
	var original_throttle: float = float(ship.get("_throttle"))
	var original_piloted: bool = bool(ship.get("_piloted"))
	ship.set_physics_process(false)
	ship.set("_piloted", false)
	ship.set("_engine_state", HeroShip.ENGINE_ONLINE)
	ship.set("_throttle", 0.65)
	ship._update_presentation(TICK, ShipCommand.new())
	var entry: Dictionary = PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 90)
	entry["craft_epoch"] = 1
	ship.set("_engine_state", HeroShip.ENGINE_OFFLINE)
	ship.set("_throttle", 0.0)
	var solo: Dictionary = ship.get_telemetry()
	var solo_damage: Dictionary = ship.get_network_damage_presentation_snapshot()
	var source: ShipCommandSource = ship.get_command_source()
	var velocity: Vector3 = ship.velocity
	var stream := PoseStream.new()
	stream.bind_replica_craft_presentations([ship])
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 1,
		"operation HUD regression admits the existing validated ONLINE/+65 host pose")
	ship.set_network_damage_presentation_enabled(true)
	_check(ship.get_network_operation_telemetry_presentation().is_empty(),
		"enabled operation HUD projection has no override before an accepted sample")
	ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
	var operation: Dictionary = ship.get_network_operation_presentation_audit().state
	_check(operation.get("engine") == HeroShip.ENGINE_ONLINE
		and is_equal_approx(float(operation.get("throttle", 0.0)), 0.65),
		"operation HUD regression retains accepted host engine and signed throttle display facts")
	_host.active_ship = ship
	_host._piloting = true
	_host._physics_process(TICK)
	var engine_label := _host.hud.get("_engine_label") as Label
	var throttle_bar := _host.hud.get("_throttle_bar") as ProgressBar
	var throttle_label := _host.hud.get("_throttle_label") as Label
	_check(engine_label.text == "ENGINE  //  ONLINE",
		"normal GameFlow publication sets the actual HUD engine label to host ONLINE instead of observer OFFLINE")
	_check(is_equal_approx(throttle_bar.value, 65.0),
		"normal GameFlow publication sets the actual HUD throttle bar to host 65 percent instead of observer zero")
	_check(throttle_label.text == "THROTTLE  //  FORWARD",
		"normal GameFlow publication sets the actual HUD throttle direction to host FORWARD instead of observer NEUTRAL")
	_check(ship.get_telemetry() == solo and ship.get_network_damage_presentation_snapshot() == solo_damage
		and ship.get_command_source() == source and ship.velocity == velocity,
		"operation HUD projection retains all raw local telemetry, damage, velocity and command authority")
	var display: Dictionary = ship.get_network_operation_telemetry_presentation()
	_check(display.size() == 2 and display.has("engine_state") and display.has("throttle"),
		"operation HUD getter exposes only engine state and signed throttle")
	display.engine_state = HeroShip.ENGINE_OFFLINE
	display.throttle = -1.0
	_assert_published_operation_hud(HeroShip.ENGINE_ONLINE, 0.65,
		"mutating a detached operation HUD sample cannot change accepted display facts")
	var tick: int = 91
	# Existing wire validation permits retained signed throttle on a stopped or
	# destroyed sample; only a live ONLINE host may display it as active thrust.
	for transition: Dictionary in [
		{"engine": HeroShip.ENGINE_ONLINE, "throttle": -0.45, "destroyed": false},
		{"engine": HeroShip.ENGINE_STARTING, "throttle": 0.65, "destroyed": false},
		{"engine": HeroShip.ENGINE_OFFLINE, "throttle": -0.45, "destroyed": false},
		{"engine": HeroShip.ENGINE_ONLINE, "throttle": 0.65, "destroyed": true},
	]:
		var next: Dictionary = entry.duplicate(true)
		next.pose_tick = tick
		next.operation_tick = tick
		next.operation_presentation.engine = transition.engine
		next.operation_presentation.throttle = transition.throttle
		next.destroyed = transition.destroyed
		if bool(transition.destroyed):
			next.hull_presentation.health = 0.0
		_check(stream.consume_movement_section(PoseStream.pack_display_facts([next])) == 1,
			"existing compact pose admits the operation HUD lifecycle sample")
		ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
		var expected_engine: StringName = HeroShip.ENGINE_OFFLINE if bool(transition.destroyed) else transition.engine
		var expected_throttle: float = float(transition.throttle) if expected_engine == HeroShip.ENGINE_ONLINE else 0.0
		_assert_published_operation_hud(expected_engine, expected_throttle,
			"actual HUD follows host reverse/STARTING/OFFLINE/dead display facts")
		tick += 1
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 0,
		"stale compact ONLINE/+65 replay cannot replace the accepted terminal operation sample")
	ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
	_assert_published_operation_hud(HeroShip.ENGINE_OFFLINE, 0.0,
		"rejected stale ONLINE/+65 replay leaves the actual HUD OFFLINE and neutral")
	_check(ship.get_telemetry() == solo and ship.get_network_damage_presentation_snapshot() == solo_damage
		and ship.get_command_source() == source and ship.velocity == velocity,
		"operation HUD lifecycle leaves raw health, engine, controls, flight and component authority unchanged")
	ship.set("_engine_state", HeroShip.ENGINE_ONLINE)
	ship.set("_throttle", 0.23)
	ship.set("_piloted", true)
	_check(ship.get_network_operation_telemetry_presentation().is_empty(),
		"this-machine pilot refuses remote engine and throttle HUD overrides")
	_assert_published_operation_hud(HeroShip.ENGINE_ONLINE, 0.23,
		"this-machine pilot keeps predicted engine and throttle despite a dead host display sample")
	ship.set("_piloted", false)
	ship.set("_engine_state", HeroShip.ENGINE_STARTING)
	ship.clear_network_operation_presentation()
	_check(ship.get_network_operation_telemetry_presentation().is_empty(),
		"cleared operation HUD projection contains no override")
	_assert_published_operation_hud(HeroShip.ENGINE_STARTING, 0.23,
		"operation HUD clear samples the current local engine and throttle")
	ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
	ship.set_network_damage_presentation_enabled(false)
	_check(ship.get_network_operation_telemetry_presentation().is_empty(),
		"disabled operation HUD projection contains no override")
	_assert_published_operation_hud(HeroShip.ENGINE_STARTING, 0.23,
		"operation HUD disable restores the current local engine and throttle")
	ship.set("_engine_state", original_engine)
	ship.set("_throttle", original_throttle)
	ship.set("_piloted", original_piloted)
	ship._update_presentation(TICK, ShipCommand.new())
	_host.active_ship = previous_ship
	_host._piloting = previous_piloting
	ship.set_physics_process(was_processing)


func _assert_published_operation_hud(engine: StringName, throttle: float, description: String) -> void:
	var raw: Dictionary = _host.active_ship.get_telemetry()
	var returned: Dictionary = _host._publish_active_ship_telemetry_to_hud()
	var engine_label := _host.hud.get("_engine_label") as Label
	var throttle_bar := _host.hud.get("_throttle_bar") as ProgressBar
	var throttle_label := _host.hud.get("_throttle_label") as Label
	var direction: String = "REVERSE" if throttle < -0.04 else ("FORWARD" if throttle > 0.04 else "NEUTRAL")
	_check(engine_label.text == "ENGINE  //  " + String(engine)
		and is_equal_approx(throttle_bar.value, absf(throttle) * 100.0)
		and throttle_label.text == "THROTTLE  //  " + direction, description)
	_check(returned == raw and _host.active_ship.get_telemetry() == raw,
		"HUD-only operation scalars do not replace the publisher's raw gameplay telemetry result")


## Carry actual host outputs into the observer's retained HUD label.
func _assert_remote_component_power_hud() -> void:
	# This is an authority-admitted role fixture, not a physical crew-admission
	# route. Both producer and retained observer are actual production Halyards.
	var source := preload("res://scenes/ships/halyard_crew_transport.tscn").instantiate() as HalyardCrewTransport
	root.add_child(source)
	await process_frame
	source.set_physics_process(false)
	var rig := source.get_damage_presentation()
	rig.set_process(false)
	source.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var receiver := _craft
	var was_processing := receiver.is_physics_processing()
	receiver.set_physics_process(false)
	var previous_ship: HeroShip = _host.active_ship
	_host.active_ship = receiver
	var raw := receiver.get_telemetry()
	var ledger := receiver.get_component_damage().get_ledger_snapshot()
	var report := receiver.get_component_damage_display_report()
	var transform_before := receiver.global_transform
	var velocity_before := receiver.velocity
	var command_source := receiver.get_command_source()
	var model := source.get_component_damage()
	for component: Dictionary in source.get_network_damage_presentation_snapshot().components:
		var id: StringName = component.id
		if id in [ShipComponentDamage.COMPONENT_ENGINE_BAY, ShipComponentDamage.COMPONENT_CORE_SYSTEMS, ShipComponentDamage.COMPONENT_PORT_WING]:
			var amount: float = source.maximum_hull * (0.3 if id == ShipComponentDamage.COMPONENT_PORT_WING else 0.15)
			_check(bool(model.record_projectile_damage(amount, component.local_position).get("accepted", false)),
				"host component owner supplies real impaired and failed power channels")
	var before_route := source.get_telemetry()
	_check(float(before_route.engine_power) > 0.0 and float(before_route.engine_power) < 1.0
		and float(before_route.weapon_power) == 0.0 and float(before_route.targeting_power) < 1.0,
		"power producer has real impaired engine/targeting and zero weapon output")
	var authority := preload("res://scripts/ships/crew_seat_role_authority.gd").new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false))
		and bool(source.attach_crew_role_authority(authority).get("accepted", false))
		and bool(authority.claim(1, 77, &"power_engineer", &"crew_port_01", authority.ROLE_ENGINEER, 1).get("accepted", false)),
		"power route fixture admits an engineer through the existing role authority")
	var routed := source.submit_crew_intent(1, 77, &"power_engineer", authority.ACTION_ENGINEER_REPAIR,
		{"system_id": ShipComponentDamage.COMPONENT_ENGINE_BAY, "repair": 0.0, "system_generation": model.get_ledger_generation()}, 2)
	_check(bool(routed.get("consumed", false)) and float(source.get_telemetry().engine_power) > float(before_route.engine_power),
		"admitted Halyard selection changes actual live engine output")
	var host_stream := PoseStream.new()
	var stream := PoseStream.new()
	stream.bind_replica_craft_presentations([receiver])
	receiver.set_network_damage_presentation_enabled(true)
	_check(receiver.get_network_component_power_telemetry_presentation().is_empty(),
		"power projection starts empty before an accepted host sample")
	var raw_first := PoseStream.build_pose_entry(source, source.get_ship_id(), 77, 897)
	raw_first.erase("operation_presentation")
	_apply_power_hud_sample(receiver, stream, [raw_first], _component_powers(source.get_telemetry()),
		"first accepted raw row projects complete powers without previous operation facts")
	var pilots := {source.get_ship_id(): {"craft": source, "peer_id": 77}}
	var entries := host_stream.build_host_entries(pilots, 900, [source])
	var entry: Dictionary = entries[0]
	var expected := _component_powers(source.get_telemetry())
	var packed := PoseStream.pack_display_facts(entries)
	var facts: Array = bytes_to_var((packed[0].display_facts as PackedByteArray).decompress(int(packed[0].display_size), FileAccess.COMPRESSION_ZSTD))
	_check(_component_powers(entry) == expected and _component_powers(packed[0]) == expected
		and facts[0].size() == 11 and facts[0][9].size() == 10,
		"per-craft publisher carries the actual complete routed trio in optional headers with unchanged compressed row layout")
	_apply_power_hud_sample(receiver, stream, packed, expected,
		"actual retained HUD label shows host routed engine, failed weapons and impaired targeting")
	var detached := receiver.get_network_component_power_telemetry_presentation()
	detached.engine_power = 0.99
	_assert_published_power_hud(expected, "mutating detached power projection cannot change retained host output")
	# Critical hull output is time-dependent even while component integrity is
	# unchanged. Exercise the real presentation getter, not an integrity formula.
	source.set("_hull", source.maximum_hull * 0.2)
	source._sync_damage_presentation()
	rig.set("_elapsed", 0.0)
	rig._process(0.10)
	entries = host_stream.build_host_entries(pilots, 903, [source])
	entry = entries[0]
	expected = _component_powers(source.get_telemetry())
	_check(float(expected.engine_power) < float(source.get_operational_modifiers().mobility_multiplier),
		"critical hull stutter constrains actual engine telemetry below routed component performance")
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts(entries), expected,
		"actual HUD engine percentage follows critical hull output")
	var first_stutter: float = expected.engine_power
	rig._process(0.07)
	entries = host_stream.build_host_entries(pilots, 906, [source])
	entry = entries[0]
	expected = _component_powers(source.get_telemetry())
	_check(not is_equal_approx(first_stutter, float(expected.engine_power)),
		"unchanged components yield a fresh host stutter output on the next sample")
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts(entries), expected,
		"actual HUD follows the next critical hull stutter sample")
	var heard_tick: int = stream.get_audit().heard_tick
	rig._process(0.04)
	entries = host_stream.build_host_entries({}, 1512, [source])
	entry = entries[0]
	expected = _component_powers(source.get_telemetry())
	_check(not bool(entry.pose_active) and int(entry.pose_tick) == 906 and int(entry.operation_tick) == 1512,
		"settled host updates powers with a fresh operation tick and retained movement tick")
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts(entries), expected,
		"settled craft power update reaches the actual HUD")
	_check(int(stream.get_audit().heard_tick) == heard_tick,
		"settled power updates do not advance the heard motion clock")
	var accepted := stream.latest_sample(receiver.get_ship_id())
	for invalid: Variant in [NAN, INF, -0.01, 1.01, "0.5", true, null]:
		for field: String in PoseStream.COMPONENT_POWER_FIELDS:
			var malformed := entry.duplicate(true)
			malformed.operation_tick = 1515
			malformed[field] = invalid
			_check(stream.consume_movement_section(PoseStream.pack_display_facts([malformed])) == 0
				and stream.consume_movement_section([malformed]) == 0,
				"invalid primitive power is rejected in packed and unpacked rows")
	for field: String in PoseStream.COMPONENT_POWER_FIELDS:
		var partial := entry.duplicate(true)
		partial.operation_tick = 1515
		partial.erase(field)
		_check(stream.consume_movement_section(PoseStream.pack_display_facts([partial])) == 0,
			"partial power triple cannot become an accepted projection")
	_check(stream.latest_sample(receiver.get_ship_id()) == accepted,
		"rejected malformed rows retain the complete prior accepted powers")
	var legacy := entry.duplicate(true)
	legacy.operation_tick = 1515
	for field: String in PoseStream.COMPONENT_POWER_FIELDS:
		legacy.erase(field)
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts([legacy]), _component_powers(raw),
		"a newer legacy row clears stale host powers and HUD falls back to current local telemetry")
	_check(receiver.get_network_component_power_telemetry_presentation().is_empty(),
		"accepted missing trio leaves no power override")
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 0,
		"older settled powers cannot overwrite the newer missing-field fallback")
	var restored := entry.duplicate(true)
	restored.operation_tick = 1518
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts([restored]), expected,
		"later complete powers restore the host HUD projection")
	var legacy_pose := legacy.duplicate(true)
	legacy_pose.operation_tick = 1521
	legacy_pose.erase("operation_presentation")
	_apply_power_hud_sample(receiver, stream, [legacy_pose], _component_powers(raw),
		"accepted legacy pose without any operation facts also clears stale host powers")
	# A real terminal source keeps its actual component outputs; power transport
	# grants no weapon readiness or authority and cannot resurrect an old life.
	source.set("_destroyed", true)
	source.set("_hull", 0.0)
	source._sync_damage_presentation()
	entries = host_stream.build_host_entries({}, 1524, [source])
	var terminal: Dictionary = entries[0]
	var terminal_expected := _component_powers(source.get_telemetry())
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts(entries), terminal_expected,
		"terminal actual HUD powers agree with host telemetry independently of weapon readiness")
	var replay := entry.duplicate(true)
	replay.pose_tick = 1527
	replay.operation_tick = 1527
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([replay])) == 0,
		"newer pose cannot resurrect a terminal same-generation power life")
	var next_life := entry.duplicate(true)
	next_life.entity_generation = int(entry.entity_generation) + 1
	next_life.hull_presentation.component_generation = next_life.entity_generation
	next_life.pose_tick = 1
	next_life.operation_tick = 1
	for field: String in PoseStream.COMPONENT_POWER_FIELDS:
		next_life[field] = 1.0
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts([next_life]), _component_powers(next_life),
		"a new generation replaces terminal powers even with an earlier pose clock")
	var wrong_epoch := next_life.duplicate(true)
	wrong_epoch.craft_epoch = 2
	wrong_epoch.pose_tick = 1600
	wrong_epoch.operation_tick = 1600
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([terminal])) == 0
		and stream.consume_movement_section(PoseStream.pack_display_facts([wrong_epoch])) == 0,
		"old-generation and wrong-epoch powers cannot replace the new accepted life")
	_assert_published_power_hud(_component_powers(next_life), "rejected generation/epoch leaves actual HUD on accepted powers")
	receiver.set("_piloted", true)
	_check(receiver.get_network_component_power_telemetry_presentation().is_empty(),
		"local pilot excludes all remote power overrides")
	_assert_published_power_hud(_component_powers(raw), "local pilot HUD keeps actual local powers")
	receiver.set("_piloted", false)
	receiver.clear_network_operation_presentation()
	_check(receiver.get_network_component_power_telemetry_presentation().is_empty(),
		"explicit clear removes remote power projection")
	_assert_published_power_hud(_component_powers(raw), "clear restores local HUD powers")
	receiver.apply_network_operation_presentation(stream.latest_sample(receiver.get_ship_id()))
	receiver.set_network_damage_presentation_enabled(false)
	_check(receiver.get_network_component_power_telemetry_presentation().is_empty(),
		"disable removes remote power projection")
	stream.clear_replica()
	stream.bind_replica_craft_presentations([receiver])
	receiver.set_network_damage_presentation_enabled(true)
	_apply_power_hud_sample(receiver, stream, PoseStream.pack_display_facts([wrong_epoch]), _component_powers(wrong_epoch),
		"clear and re-entry accept the new epoch without stale power state")
	receiver.set_network_damage_presentation_enabled(false)
	_check(receiver.get_telemetry() == raw and receiver.get_component_damage().get_ledger_snapshot() == ledger
		and receiver.get_component_damage_display_report() == report and receiver.global_transform == transform_before
		and receiver.velocity == velocity_before and receiver.get_command_source() == command_source,
		"power display lifecycle preserves raw local telemetry, component report, repair ledger, pose, velocity and command authority")
	_host.active_ship = previous_ship
	receiver.set_physics_process(was_processing)
	source.free()


func _component_powers(telemetry: Dictionary) -> Dictionary:
	var powers: Dictionary = {}
	for field: String in PoseStream.COMPONENT_POWER_FIELDS:
		powers[field] = telemetry[field]
	return powers


func _apply_power_hud_sample(ship: HeroShip, stream: PoseStream, movement: Array, expected: Dictionary, description: String) -> void:
	_check(stream.consume_movement_section(movement) == 1, "power HUD accepts the ordered compact host sample")
	ship.apply_network_operation_presentation(stream.latest_sample(ship.get_ship_id()))
	_assert_published_power_hud(expected, description)


func _assert_published_power_hud(expected: Dictionary, description: String) -> void:
	var raw := _host.active_ship.get_telemetry()
	var returned := _host._publish_active_ship_telemetry_to_hud()
	var label := _host.hud.get("_damage_status_label") as Label
	_check(label.text.contains("ENGINE OUTPUT  %03d%%    WEAPONS  %03d%%    TARGETING  %03d%%" % [
		roundi(float(expected.engine_power) * 100.0), roundi(float(expected.weapon_power) * 100.0), roundi(float(expected.targeting_power) * 100.0)]), description)
	_check(returned == raw and _host.active_ship.get_telemetry() == raw,
		"power HUD overlay leaves the publisher's raw gameplay telemetry result unchanged")


func _assert_remote_component_hud() -> void:
	var ship := _host.get_node("JovianLightFreighter") as HeroShip
	var was_processing := ship.is_physics_processing()
	var original_piloted: bool = bool(ship.get("_piloted"))
	ship.set_physics_process(false)
	ship.set("_piloted", false)
	var raw_report := ship.get_component_damage_report()
	var entry := PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 100)
	entry["craft_epoch"] = 1
	for component: Dictionary in entry.hull_presentation.components:
		if component.id == &"port_wing":
			component.integrity = 0.35
			component.state = ShipComponentDamage.state_for_integrity(0.35)
	var stream := PoseStream.new()
	stream.bind_replica_craft_presentations([ship])
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 1,
		"component row regression admits the existing validated host port-wing damage")
	ship.set_network_damage_presentation_enabled(true)
	_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
		"component row regression applies accepted host damage to the retained silhouette")
	# Staged observer presentation: bind the existing HUD directly, without
	# claiming this fixture proves physical crew admission or travel.
	_host.hud.set_mode("piloting")
	_check(_host.hud.bind_hero_component_ship(ship), "component row regression binds the actual retained HUD")
	var row: Dictionary = _host.hud.get_hero_component_hud_snapshot()
	_check(row.get("component_id") == &"port_wing" and row.get("component_stage") == &"impaired"
		and is_equal_approx(float(row.get("integrity", -1.0)), 0.35) and row.get("wording") == &"critical",
		"actual retained component HUD row shows accepted host PORT WING 035 percent CRITICAL")
	var label := _host.hud.find_child("ComponentStatus", true, false) as Label
	_check(label != null and label.visible and label.text == "[!] DAMAGE  //  PORT WING  035%  //  CRITICAL",
		"actual retained component label paints accepted host PORT WING 035 percent CRITICAL")
	_check(ship.get_component_damage_report() == raw_report,
		"host component display leaves the raw retained local ledger report unchanged")
	var detached := ship.get_component_damage_display_report()
	(detached.components as Array).clear()
	_check(ship.get_component_damage_display_report().components.size() == raw_report.components.size()
		and not detached.has("engine_power") and not detached.has("weapon_power") and not detached.has("targeting_power")
		and not detached.has("ledger_generation") and not detached.has("repair_rate_per_second"),
		"detached host component report exposes display stages without local ledger or dynamic power facts")
	var source := ship.get_command_source()
	var velocity := ship.velocity
	var raw_telemetry := ship.get_telemetry()
	var raw_damage := ship.get_network_damage_presentation_snapshot()
	var tick := 101
	for integrity: float in [0.58, 1.0, 0.20]:
		var next := entry.duplicate(true)
		next.pose_tick = tick
		next.operation_tick = tick
		_set_host_component_integrity(next, &"port_wing", integrity)
		_apply_component_hud_sample(ship, stream, next)
		_assert_component_row(&"forward_hull" if integrity == 1.0 else &"port_wing", integrity,
			&"nominal" if integrity == 1.0 else (&"failed" if integrity == 0.20 else &"impaired"),
			&"nominal" if integrity == 1.0 else (&"failed" if integrity == 0.20 else &"degraded"),
			"same retained HUD follows host component repair, nominal recovery and failure without local repair wording")
		tick += 1
	_check(not bool(ship.apply_network_damage_presentation(entry).get("applied", false)),
		"same-life stale host component sample is rejected")
	_assert_component_row(&"port_wing", 0.20, &"failed", &"failed", "stale host sample leaves the actual failed component row intact")
	var dead := entry.duplicate(true)
	dead.pose_tick = 104
	dead.operation_tick = 104
	dead.destroyed = true
	dead.hull_presentation.health = 0.0
	_apply_component_hud_sample(ship, stream, dead)
	row = _host.hud.get_hero_component_hud_snapshot()
	_check(row.get("wording") == &"destroyed" and label.text == "[X] DESTROYED  //  HULL LOST",
		"host destruction updates the actual component row without local destruction authority")
	var same_life := entry.duplicate(true)
	same_life.pose_tick = 105
	same_life.operation_tick = 105
	_check(not bool(ship.apply_network_damage_presentation(same_life).get("applied", false))
		and _host.hud.get_hero_component_hud_snapshot().get("wording") == &"destroyed",
		"same-life healthy recovery cannot resurrect the destroyed component row")
	var revived := entry.duplicate(true)
	revived.pose_tick = 106
	revived.operation_tick = 106
	revived.entity_generation = int(entry.entity_generation) + 1
	revived.hull_presentation.component_generation = revived.entity_generation
	_set_host_component_integrity(revived, &"port_wing", 1.0)
	_set_host_component_integrity(revived, &"engine_bay", 0.55)
	_apply_component_hud_sample(ship, stream, revived)
	_assert_component_row(&"engine_bay", 0.55, &"impaired", &"degraded",
		"new host life displays its component damage without borrowing local reuse audit wording")
	_check(not bool(ship.apply_network_damage_presentation(dead).get("applied", false)),
		"old terminal life cannot overwrite the revived component row")
	_host.hud.set_mode("on_foot")
	_check(not label.visible, "component row hides when observer leaves the retained flight HUD mode")
	_host.hud.set_mode("piloting")
	_assert_component_row(&"engine_bay", 0.55, &"impaired", &"degraded",
		"mode reentry repaints the accepted host component source")
	_host.hud.set_mode("on_foot")
	ship.clear_network_damage_presentation()
	_check(bool(ship.apply_network_damage_presentation(entry).get("applied", false)),
		"hidden clear allows fresh host display ordering to begin from an earlier life")
	_host.hud.set_mode("piloting")
	_assert_component_row(&"port_wing", 0.35, &"impaired", &"critical",
		"hidden clear and readoption fence the previous host source cache before row reentry")
	_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
		"the accepted newer host life resumes after hidden source replacement")
	_check(ship.get_telemetry() == raw_telemetry and ship.get_network_damage_presentation_snapshot() == raw_damage
		and ship.get_component_damage_report() == raw_report and ship.get_command_source() == source and ship.velocity == velocity,
		"host component lifecycle leaves raw local ledger, hull, operational scalars, motion and command authority unchanged")
	# Local mutation is independent of the host display. In particular a real
	# local repair receipt cannot manufacture a host repair marker or caption.
	ship.get_component_damage().record_damage(ship.maximum_hull * 0.3)
	ship.get_component_damage().tick_repair(0.1, true)
	_assert_component_row(&"engine_bay", 0.55, &"impaired", &"degraded",
		"local repair receipt cannot repaint host components as repairing")
	var current_local := ship.get_component_damage_report()
	ship.set_piloted(true)
	_assert_local_component_row(current_local, "local pilot eligibility immediately restores the current local component row")
	ship.set_piloted(false)
	_assert_component_row(&"engine_bay", 0.55, &"impaired", &"degraded",
		"observer eligibility immediately restores accepted host components without a new network sample")
	ship.clear_network_damage_presentation()
	_assert_local_component_row(current_local,
		"clear restores today's local report despite its lower generation and revision than the host display")
	_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
		"observer can readopt accepted host display after explicit clear")
	_assert_component_row(&"engine_bay", 0.55, &"impaired", &"degraded", "readoption returns the same row to host components")
	ship.set_network_damage_presentation_enabled(false)
	_assert_local_component_row(current_local, "disable restores local components without old repair markers")
	_host.remove_child(ship)
	_check(not label.visible, "ship tree exit clears the actual bound component row")
	_host.add_child(ship)
	await process_frame
	_assert_local_component_row(current_local, "ship tree reentry refreshes current local components after host clear")
	ship.get_component_damage().tick_repair(100.0, true)
	_host.hud.bind_hero_component_ship(_host.active_ship)
	ship.set("_piloted", original_piloted)
	ship.set_physics_process(was_processing)


func _set_host_component_integrity(entry: Dictionary, id: StringName, integrity: float) -> void:
	for component: Dictionary in entry.hull_presentation.components:
		if component.id == id:
			component.integrity = integrity
			component.state = ShipComponentDamage.state_for_integrity(integrity)


func _apply_component_hud_sample(ship: HeroShip, stream: PoseStream, entry: Dictionary) -> void:
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 1,
		"existing compact pose admits the component HUD lifecycle sample")
	_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
		"accepted host component update refreshes the existing HUD binding")


func _assert_component_row(id: StringName, integrity: float, stage: StringName, wording: StringName, description: String) -> void:
	var row: Dictionary = _host.hud.get_hero_component_hud_snapshot()
	var label := _host.hud.find_child("ComponentStatus", true, false) as Label
	_check(row.get("component_id") == id and row.get("component_stage") == stage
		and is_equal_approx(float(row.get("integrity", -1.0)), integrity) and row.get("wording") == wording
		and not bool(row.get("repairing", true)) and label != null and label.visible and label.text == row.get("text"), description)


func _assert_local_component_row(report: Dictionary, description: String) -> void:
	var worst: Dictionary = {}
	for component: Dictionary in report.components:
		if worst.is_empty() or float(component.integrity) < float(worst.integrity):
			worst = component
	var integrity := float(worst.integrity)
	var wording: StringName = &"failed" if worst.state_id == &"failed" else (&"critical" if integrity <= 0.4 \
		else (&"degraded" if worst.state_id == &"impaired" else &"nominal"))
	_assert_component_row(StringName(worst.id), integrity, StringName(worst.state_id), wording, description)


## Drive the existing GameFlow publisher rather than handing crafted telemetry
## straight to the HUD: its retained solo hull must not replace host display facts.
func _assert_remote_hull_hud() -> void:
	var ship := _host.get_node("JovianLightFreighter") as HeroShip
	var previous_ship := _host.active_ship
	var previous_piloting := _host._piloting
	var was_processing := ship.is_physics_processing()
	ship.set_physics_process(false)
	_host.active_ship = ship
	_host._piloting = true
	var solo := ship.get_telemetry()
	var solo_damage := ship.get_network_damage_presentation_snapshot()
	var source := ship.get_command_source()
	var velocity := ship.velocity
	var entry := PoseStream.build_pose_entry(ship, ship.get_ship_id(), 1, 80)
	entry["craft_epoch"] = 1
	entry.hull_presentation["health"] = 50.0
	entry.hull_presentation["maximum_health"] = 200.0
	var stream := PoseStream.new()
	stream.bind_replica_craft_presentations([ship])
	_check(stream.consume_movement_section(PoseStream.pack_display_facts([entry])) == 1,
		"HUD regression admits the existing validated 50/200 host hull sample")
	ship.set_network_damage_presentation_enabled(true)
	_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
		"HUD regression applies host presentation while retaining the local full hull")
	_host._physics_process(TICK)
	var frame: Dictionary = _host.hud.get_hull_frame_damage_snapshot()
	_check(is_equal_approx(float(frame.health_ratio), 0.25) and frame.stage == &"critical",
		"normal GameFlow publication shows host 50/200 hull and critical frame instead of retained solo health")
	var bar := _host.hud.get("_hull_bar") as ProgressBar
	_check(is_equal_approx(bar.value, 25.0),
		"normal GameFlow publication sets the actual HUD hull bar to host 25 percent")
	var stale := entry.duplicate(true)
	stale.hull_presentation.health = 200.0
	_check(not bool(ship.apply_network_damage_presentation(stale).get("applied", false)),
		"an already consumed hull tick cannot overwrite HUD presentation")
	_assert_published_hull_hud(0.25, &"critical", "rejected hull tick leaves the actual HUD on the accepted host damage")
	var dead := entry.duplicate(true)
	dead.pose_tick = 81
	dead.operation_tick = 81
	dead.destroyed = true
	dead.hull_presentation.health = 0.0
	var revived := entry.duplicate(true)
	revived.pose_tick = 83
	revived.operation_tick = 83
	revived.entity_generation = int(entry.entity_generation) + 1
	revived.hull_presentation.component_generation = revived.entity_generation
	revived.hull_presentation.health = 180.0
	revived.hull_presentation.maximum_health = 240.0
	for transition: Dictionary in [dead, revived]:
		_check(stream.consume_movement_section(PoseStream.pack_display_facts([transition])) == 1,
			"the existing compact pose admits the HUD hull lifecycle transition")
		_check(bool(ship.apply_network_damage_presentation(stream.latest_sample(ship.get_ship_id())).get("applied", false)),
			"the accepted host hull life reaches the HUD projection owner")
		_assert_published_hull_hud(0.0 if bool(transition.destroyed) else 0.75,
			&"destroyed" if bool(transition.destroyed) else &"healthy",
			"normal HUD publication follows host destruction and new-generation hull/maximum")
		if bool(transition.destroyed):
			var same_life := entry.duplicate(true)
			same_life.pose_tick = 82
			same_life.operation_tick = 82
			same_life.hull_presentation.health = 200.0
			_check(not bool(ship.apply_network_damage_presentation(same_life).get("applied", false)),
				"a healthy same-life replay cannot resurrect HUD hull presentation")
			_assert_published_hull_hud(0.0, &"destroyed", "rejected same-life recovery retains the destroyed HUD frame and empty bar")
	_check(not bool(ship.apply_network_damage_presentation(dead).get("applied", false)),
		"an old terminal life cannot overwrite revived HUD hull presentation")
	_assert_published_hull_hud(0.75, &"healthy", "rejected old life leaves the revived host HUD hull and maximum intact")
	_check(ship.get_telemetry().hull == solo.hull and ship.get_telemetry().maximum_hull == solo.maximum_hull
		and ship.get_telemetry().damage_status == solo.damage_status
		and ship.get_network_damage_presentation_snapshot() == solo_damage
		and ship.get_command_source() == source and ship.velocity == velocity,
		"HUD host lifecycle retains local gameplay hull, maximum, damage status, components, velocity and command authority")
	# Clearing must sample today's local hull, rather than cache the original one.
	ship.set("_hull", ship.maximum_hull * 0.8)
	ship.clear_network_damage_presentation()
	_assert_published_hull_hud(0.8, StringName(solo.damage_status), "cleared host projection publishes the current retained local hull to the HUD")
	ship.set("_hull", solo.hull)
	ship.set_network_damage_presentation_enabled(false)
	_assert_published_hull_hud(float(solo.hull) / float(solo.maximum_hull), StringName(solo.damage_status),
		"disabled host projection restores the retained local HUD hull and status")
	_host.active_ship = previous_ship
	_host._piloting = previous_piloting
	ship.set_physics_process(was_processing)


func _assert_published_hull_hud(expected: float, stage: StringName, description: String) -> void:
	_host._physics_process(TICK)
	var frame: Dictionary = _host.hud.get_hull_frame_damage_snapshot()
	var bar := _host.hud.get("_hull_bar") as ProgressBar
	_check(is_equal_approx(float(frame.health_ratio), expected) and frame.stage == stage
		and is_equal_approx(bar.value, expected * 100.0), description)


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
