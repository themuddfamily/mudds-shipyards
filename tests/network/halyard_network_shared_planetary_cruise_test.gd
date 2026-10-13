## test-matrix-display: input-only
extends "res://tests/network/halyard_network_passenger_route_test.gd"

## The ordinary matrix runs the same real-peer shared journey harness.
func _run() -> void:
	_rime_arrival = "--rime-shared-arrival" in OS.get_cmdline_user_args()
	_surface_arrival = _rime_arrival or "--aurora-shared-arrival" in OS.get_cmdline_user_args()
	_arrival_world_id = &"rime_glacial_world" if _rime_arrival else &"aurora_temperate_world"
	_shared_cruise = not _surface_arrival
	await super._run()


# The second crew member's turn starts after the first member has completed
# the shared chair operation. Waiting from its earlier walked marker charges
# observer readiness and the first turn against its own admission deadline.
# The observer likewise follows both serial turns before waiting for finish.
# Keep each existing start/operation barrier at the original sixty-second cap.
func _wait_file(name: String, seconds: float) -> bool:
	if _shared_cruise and _role == "client_b" and name == "client_b.chair_go":
		if not await super._wait_file("client.chair_go", seconds):
			return false
		if not await super._wait_file("client.chair_done", seconds):
			return false
	if _shared_cruise and _role == "observer" and name == "host.finish":
		for stage in ["client.chair_go", "client.chair_done", "client_b.chair_go", "client_b.chair_done"]:
			if not await super._wait_file(stage, seconds):
				return false
	return await super._wait_file(name, seconds)


func _orchestrate() -> void:
	if _surface_arrival:
		await _verify_solo_shared_admission_rejection()
		_ember_surface = true
		_shared_cruise = false
	await super._orchestrate()
	if _failures.is_empty():
		if _surface_arrival:
			print("HALYARD_NETWORK_SHARED_RIME_ARRIVAL_OK" if _rime_arrival else "HALYARD_NETWORK_SHARED_AURORA_ARRIVAL_OK")
		else:
			print("HALYARD_NETWORK_SHARED_PLANETARY_CRUISE_TEST_OK")


# Opt-in actual canonical Aurora or Rime arrival. The inherited terrain harness retains
# its original 2400-second total deadline and every ordinary stage cap. Default
# invocation still runs the existing two-crew Ember readiness/rebase route.
var _surface_arrival := false
var _rime_arrival := false
var _arrival_world_id: StringName = &"aurora_temperate_world"
var _arrival_distance := 0.0
var _arrival_rebases := 0


## Exercise the public admission boundary against actual solo production
## visits before the independent peer route starts. The same existing twelve-
## second pilot-seat cap and Mudds-side flight envelope remain in force.
func _verify_solo_shared_admission_rejection() -> void:
	_game = Main.instantiate() as GameFlow
	root.add_child(_game)
	await _ticks(4)
	_game.start_shift()
	await _ticks(3)
	_craft = _game.get_node("HalyardCrewTransport") as HeroShip
	_player = _game.get_node("Player") as PlayerController
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position()))
	_game._board_ship(_craft)
	var seated := await _until(func(): return _game._piloting and _player.is_seated_at(_craft.get_pilot_seat_anchor()) \
		and not _game._transition_busy, 12.0)
	_check(seated, "solo admission regression holds an actual production pilot seat")
	if seated:
		Input.action_press(&"hover")
		Input.action_press(&"move_forward")
		for _tick in 180:
			await physics_frame
		Input.action_release(&"hover")
		Input.action_release(&"move_forward")
		await _ticks(4)
		_check(_game._sortie_departed_berth and not bool(_craft.get_telemetry().get("landed", true)),
			"solo admission regression physically departs through ordinary pilot controls")
		if _game._selected_activity_is_running():
			_game._fail_active_activity(&"admission_guard_fixture_activity_ended")
		_craft.global_position = Vector3(0.0, 5000.0, -8640.0).normalized() * 9995.0
		_craft.velocity = Vector3.ZERO
		_game._sortie_departed_berth = true
		_game.phase = GameFlow.Phase.FREE_FLIGHT
		for owner: RefCounted in [_game._aurora_expedition, _game._rime_expedition]:
			_check(not owner.request(true) and not owner.is_active() and not bool(owner.get("_shared_arrival")),
				"shared admission rejects an idle valid solo flight for " + String(owner.profile.world_id))
			var admitted: bool = owner.request()
			_check(admitted, "ordinary solo visit still admits " + String(owner.profile.world_id))
			if not admitted:
				continue
			var before: Dictionary = owner.get_visit_snapshot()
			var cruise := _game.planetary_cruise_binding.get_snapshot()
			var source := _craft.get_command_source()
			_check(not owner.request(true) and owner.get_visit_snapshot() == before
				and _game.planetary_cruise_binding.get_snapshot() == cruise
				and _craft.get_command_source() == source and not bool(owner.get("_shared_arrival")),
				"rejected shared admission preserves the actual active solo visit, cruise and source for " + String(owner.profile.world_id))
			owner.cancel(true)
	_game._aurora_expedition.cancel(true)
	_game._rime_expedition.cancel(true)
	root.remove_child(_game)
	_game.free()
	_game = null
	_craft = null
	_player = null
	await _ticks(2)


func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var args := super._peer_arguments(role, display)
	# Source peers must use this child so its shared-route barriers run in
	# every process. Packed peers retain the external wrapper selected by
	# the base harness because test scripts are excluded from the pack.
	if _package_under_test.is_empty():
		var script_index := args.find("--script")
		args[script_index + 1] = "res://tests/network/halyard_network_shared_planetary_cruise_test.gd"
	if _surface_arrival:
		args.append("--rime-shared-arrival" if _rime_arrival else "--aurora-shared-arrival")
	return args


func _ember_surface_host() -> void:
	if not _surface_arrival:
		await super._ember_surface_host()
		return
	_check(_game.host_network_session(_port).accepted, "surface host starts actual authenticated ENet")
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.to_global(Vector3(-3.10, 0.0, HalyardCrewTransport.AIRSTAIR_Z))))
	await _ticks(15)
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _craft.is_canopy_open(), 5.0), "ordinary host hatch opens actual cabin")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	_write("host.ready", {})
	if not await _wait_file("client.cabin", 60.0):
		return
	var peer := int(_read("client.cabin").peer_id)
	var avatar := _game.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	_check(is_instance_valid(body), "surface crew begins as same real authoritative cabin body")
	if not is_instance_valid(body):
		return
	var body_id := body.get_instance_id()
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._piloting and _player.is_seated_at(pilot) and not _game._transition_busy, 12.0), "ordinary cockpit owns actual host pilot")
	if not _game._piloting:
		return
	var bootstrap: PlanetaryStreamingBootstrap = _game.rime_streaming_bootstrap if _rime_arrival else _game.aurora_streaming_bootstrap
	var frame := bootstrap.get_coordinate_frame_for_session()
	var encoded := frame.body_local_to_orbital_position(bootstrap.get_navigation_destination().body_local_position_meters, frame.get_generation())
	var destination: Vector3 = frame.orbital_to_world_streaming_position(encoded.coordinate, frame.get_generation()).position
	# Only the same inherited Mudds-side flight envelope is staged. The entire
	# selected world's full canonical cruise and physical approach remain live.
	_craft.global_position = Vector3(0.0, 5000.0, -8640.0).normalized() * 9995.0
	_craft.global_basis = Basis.looking_at((destination - _craft.global_position).normalized(), Vector3.UP)
	_craft.velocity = Vector3.ZERO
	_game._sortie_departed_berth = true
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	await _ticks(12)
	var source := _craft.get_command_source()
	var crew_tick := _game._network_moving_interior_server_tick
	_game.hud.open_planetary_destination_board()
	var button := _game.hud.find_child("PlanetaryDestinationAction_" + String(_arrival_world_id), true, false) as Button
	_check(button != null and not button.disabled, "ordinary Destination Board offers host-selected surface destination")
	if button == null or button.disabled:
		return
	button.pressed.emit()
	var preparation := _game.get_network_planetary_journey_snapshot()
	_check(preparation.get("world_id") == _arrival_world_id and preparation.get("phase") == &"preparing"
		and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)), "surface admission waits for authenticated world-specific readiness before physical cruise")
	_game._network_planetary_journey.consume_ready(peer, {"journey_epoch": preparation.journey_epoch,
		"origin_revision": preparation.origin_revision, "world_id": &"ember_moon", "ship_id": _craft.get_ship_id()})
	_check(_game.get_network_planetary_journey_snapshot().get("ready_peers", []).is_empty(), "Ember readiness cannot acknowledge the selected surface departure")
	_game._network_planetary_journey.consume_ready(peer, {"journey_epoch": preparation.journey_epoch,
		"origin_revision": preparation.origin_revision,
		"world_id": &"aurora_temperate_world" if _rime_arrival else &"rime_glacial_world", "ship_id": _craft.get_ship_id()})
	_check(_game.get_network_planetary_journey_snapshot().get("ready_peers", []).is_empty(), "the other surface world cannot acknowledge the selected departure")
	_check(await _until(func(): return _game.get_network_planetary_journey_snapshot().get("phase") == &"cruising", 12.0), "actual crew acknowledges selected surface streaming and starts host-owned canonical cruise")
	_write("host.flight_started", {})
	var owner: RefCounted = _game._rime_expedition if _rime_arrival else _game._aurora_expedition
	var reached := await _observe_surface_approach(owner, &"corridor", _ember_surface_seconds_remaining())
	_check(reached, "real canonical cruise reaches selected authored surface approach within original runtime budgets")
	if not reached:
		print("SHARED_ARRIVAL_INCOMPLETE: ", _arrival_world_id, " ", owner.get_visit_snapshot(), " bridge=", _game.get_network_planetary_journey_snapshot())
		return
	_write("host.approaching", {})
	_check(await _observe_surface_approach(owner, &"landed", 120.0), "ordinary surface source handoff and berth assist physically land shared craft")
	if owner.state != &"landed":
		return
	var berth := owner.get("_berth") as ShipBerth
	_check(owner.profile.world_id == _arrival_world_id
		and _game._planetary_journey.get_visit_world_id() == _arrival_world_id
		and is_instance_valid(berth) and berth.get_berth_id() == owner.profile.berth_id and berth.get_occupant() == _craft
		and _craft.get_landing_contract_report().get("phase") == HeroShip.LANDING_PHASE_DOCKED
		and bool(_craft.get_telemetry().get("landed", false)), "real occupied surface lease and docked physical landing agree")
	_check(_arrival_distance > (9_800_000.0 if _rime_arrival else 11_800_000.0) and _arrival_rebases > (900 if _rime_arrival else 1100), "shared selected surface physically crosses canonical distance with unchanged ten-kilometre rebases")
	_check(int(owner.get_visit_snapshot().get("staging_events", -1)) == 0
		and _craft.get_command_source() == source and simulation.get_body(avatar).get_instance_id() == body_id
		and _game._network_moving_interior_server_tick > crew_tick, "cruise/landing preserves exact pilot source and same published real crew body without travel placement")
	_check(is_equal_approx(float(_craft.get_telemetry().get("hull", 0)), float(_craft.get_telemetry().get("maximum_hull", -1))), "physical shared arrival retains full hull health")
	_check(not owner.request() and owner.state == &"landed" and owner.capture_interrupted_visit().is_empty(), "partial shared arrival refuses surface return and solo persistence")
	_write("host.landed", {})
	if not await _wait_file("client.arrival_supported", 60.0):
		return
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not _player.is_seated() \
		and _player.is_on_floor() and _player.is_control_enabled() and not _game._transition_busy, 8.0), "landed host ordinary Exit restores supported cabin standing")
	_check(berth.get_occupant() == _craft and _game.get_network_planetary_journey_snapshot().get("phase") == &"landed", "host cabin standing preserves ordinary berth and shared arrival owner")
	_write("host.finish", {})
	await _wait_file("client.disconnected", 30.0)
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(not bool(owner.get("_shared_arrival")) and _game.get_network_planetary_journey_snapshot().get("journey_epoch", 0) == 0, "actual session stop retires shared arrival and resets visit flag through ordinary recovery")


func _observe_surface_approach(owner: RefCounted, target: StringName, seconds: float) -> bool:
	var translation := [Vector3.ZERO]
	var origin := _game.common_world_origin_rebase_owner
	var receiver := func(receipt: Dictionary) -> void:
		translation[0] += receipt.get("world_translation_delta", Vector3.ZERO) as Vector3
		_arrival_rebases += 1
	origin.rebase_committed.connect(receiver)
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	var fault := ""
	while Time.get_ticks_msec() < deadline and owner.state != target and owner.state in [&"outbound", &"corridor", &"landing"]:
		var previous := _craft.global_position
		var previous_player := _player.global_position
		var previous_basis := _craft.global_basis
		var previous_speed := _craft.velocity.length()
		var previous_tick := Engine.get_physics_frames()
		translation[0] = Vector3.ZERO
		await physics_frame
		var elapsed := float(Engine.get_physics_frames() - previous_tick) / float(Engine.physics_ticks_per_second)
		var step := _craft.global_position.distance_to(previous + translation[0])
		_arrival_distance += step
		var motion_bound := maxf(previous_speed, _craft.velocity.length()) * elapsed + 0.25
		var seat_radius := _craft.get_pilot_seat_anchor().global_position.distance_to(_craft.global_position)
		var rotation_allowance := Quaternion(previous_basis).angle_to(Quaternion(_craft.global_basis)) * seat_radius
		if step > motion_bound or _player.global_position.distance_to(previous_player + translation[0]) > motion_bound + rotation_allowance:
			fault = "craft stepped beyond real physical velocity"
		if not _craft.is_piloted() or not _player.is_seated_at(_craft.get_pilot_seat_anchor()):
			fault = "exact host pilot lost during canonical cruise"
		if not fault.is_empty():
			break
	origin.rebase_committed.disconnect(receiver)
	_check(fault.is_empty(), "every outbound physics step retains ordinary movement and pilot authority: " + fault)
	return fault.is_empty() and owner.state == target


func _ember_surface_client() -> void:
	if not _surface_arrival:
		await super._ember_surface_client()
		return
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "surface crew joins independent authenticated peer")
	if not await _until(_admitted_session_ready, 60.0):
		_check(false, "surface crew receives authenticated admission")
		return
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN \
		and _game.get_network_remote_body_intent_source() != null and not _game._transition_busy, 12.0), "ordinary surface peer hatch owns actual host-simulated cabin body")
	var source := _game.get_network_remote_body_intent_source()
	if source == null:
		return
	var body_id := _player.get_instance_id()
	await _walk(Vector3(-1.3, 0.52, -5.8))
	_write("client.cabin", {"peer_id": _game.network_session.multiplayer.get_unique_id()})
	if not await _wait_file("host.flight_started", 20.0) \
			or not await _wait_file("host.approaching", _ember_surface_seconds_remaining()) \
			or not await _wait_file("host.landed", 120.0):
		return
	_check(await _until(func(): return _game.get_network_planetary_journey_snapshot().get("phase") == &"landed" \
		and is_instance_valid((_game.rime_streaming_bootstrap if _rime_arrival else _game.aurora_streaming_bootstrap).get_loaded_instance()), 12.0), "authenticated surface arrival and actual client terrain agree")
	_check(_game.get_network_planetary_journey_snapshot().get("world_id") == _arrival_world_id
		and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true))
		and _player.get_instance_id() == body_id and source == _game.get_network_remote_body_intent_source()
		and source.is_bound(), "client remains same real crew body/source and never owns a cruise attachment")
	var previous := _craft.to_local(_player.global_position)
	await _walk(Vector3(1.0, 0.52, -5.8))
	_check(_craft.to_local(_player.global_position).distance_to(previous) > 0.6 and _player.is_on_floor(), "ordinary landed cabin walk stays supported on actual hull")
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0), "ordinary landed passenger chair remains usable")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not _game._transition_busy, 8.0), "ordinary landed chair stand restores same supported walking body")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._network_client_boarding_audit.get("last_status") == (&"shared_rime_surface_unavailable" if _rime_arrival else &"shared_aurora_surface_unavailable"), 4.0), "actual authenticated hatch request receives explicit host refusal for unsupported selected surface exterior")
	_check(_game._network_client_boarding_holds(_craft) and source.is_bound()
		and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _player.is_on_floor(), "unsupported shared exterior hatch explicitly refuses while preserving supported ordinary cabin controls")
	_write("client.arrival_supported", {})
	if not await _wait_file("host.finish", 60.0):
		return
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(_player.is_control_enabled(), "actual surface crew disconnect retains usable controls")
	_write("client.disconnected", {})
