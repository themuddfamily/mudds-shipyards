## test-matrix-display: input-only
extends "res://tests/network/halyard_network_passenger_route_test.gd"

## The ordinary matrix runs the same real-peer shared journey harness.
# Presentation unit only: discovery/current-exterior qualification are staged.
# Progress still comes from the real authenticated recipient, and the exercised
# HUD method is production GameFlow. This grants no remote body or interaction.
class PassiveSurveyPresentation extends GameFlow:
	var recipient: GameFlow
	var exterior_current := true
	var interaction: Node3D
	func _refresh_interaction_targets() -> void:
		station_interaction_candidate = interaction
	func _network_client_ember_passenger_surface_is_current() -> bool:
		return exterior_current
	func get_network_ember_survey_snapshot() -> Dictionary:
		return recipient.get_network_ember_survey_snapshot()


var _ember_passive_progress := false


func _run() -> void:
	_ember_passive_progress = "--ember-passive-progress" in OS.get_cmdline_user_args()
	_rime_arrival = "--rime-shared-arrival" in OS.get_cmdline_user_args()
	_home_return = not _rime_arrival and "--aurora-shared-home-return" in OS.get_cmdline_user_args()
	_surface_arrival = _rime_arrival or _home_return or "--aurora-shared-arrival" in OS.get_cmdline_user_args()
	_arrival_world_id = &"rime_glacial_world" if _rime_arrival else &"aurora_temperate_world"
	_shared_cruise = not _surface_arrival and not _ember_passive_progress
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
		if _ember_passive_progress:
			print("HALYARD_NETWORK_EMBER_PASSIVE_PROGRESS_OK")
		elif _home_return:
			print("HALYARD_NETWORK_SHARED_AURORA_HOME_RETURN_OK")
		elif _surface_arrival:
			print("HALYARD_NETWORK_SHARED_RIME_ARRIVAL_OK" if _rime_arrival else "HALYARD_NETWORK_SHARED_AURORA_ARRIVAL_OK")
		else:
			print("HALYARD_NETWORK_SHARED_PLANETARY_CRUISE_TEST_OK")


# Opt-in actual canonical Aurora or Rime arrival. The inherited terrain harness retains
# its original 2400-second total deadline and every ordinary stage cap. Default
# invocation still runs the existing two-crew Ember readiness/rebase route.
var _surface_arrival := false
var _home_return := false
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
	if _ember_passive_progress:
		args.append("--ember-passive-progress")
	if _surface_arrival:
		args.append("--rime-shared-arrival" if _rime_arrival else "--aurora-shared-arrival")
	if _home_return:
		args.append("--aurora-shared-home-return")
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
	# Physical departure, rather than the fixture's later starting envelope,
	# must release the dock before the normal Destination Board admits travel.
	var launch_source := _craft.get_local_input_source()
	launch_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	var home_position := _craft.global_position
	Input.action_press(&"move_forward")
	var departed := await _until(func(): return not bool(_craft.get_telemetry().get("landed", true)) \
		and _craft.global_position.distance_to(home_position) > 5.0, 12.0)
	Input.action_release(&"move_forward")
	_check(departed, "ordinary host throttle physically departs Mudds before shared surface admission")
	if not departed:
		print("SHARED_ARRIVAL_DEPARTURE_DEBUG: ", _craft.get_telemetry(), " command=", _craft.get_last_ship_command(), " gate=", (_game._rime_expedition if _rime_arrival else _game._aurora_expedition).runtime_state())
		return
	# Ordinary departure can start the selected activity. Reset through its
	# existing persisted public lifecycle, retaining pending-reward refusals.
	if _game._selected_activity_is_running():
		var reset := _game.reset_active_activity()
		_check(reset and not _game._selected_activity_is_running(), "existing public activity reset clears the completed preflight setup before shared travel")
		if not reset or _game._selected_activity_is_running():
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
	var admission_owner: RefCounted = _game._rime_expedition if _rime_arrival else _game._aurora_expedition
	var admission := admission_owner.runtime_state() as Dictionary
	_check(_game._shared_planetary_host_eligible() and bool(admission.get("action_enabled", false)),
		"real host pilot, departed craft, idle activity, lane, home berth and manoeuvre gates admit selected surface")
	if not bool(admission.get("action_enabled", false)):
		print("SHARED_ARRIVAL_ADMISSION_DEBUG: ", admission, " activity=", _game.get_active_activity_snapshot(), " combat=", _game._planetary_cruise_combat_active())
		return
	_game.hud.open_planetary_destination_board()
	var button := _game.hud.find_child("PlanetaryDestinationAction_" + String(_arrival_world_id), true, false) as Button
	_check(button != null and not button.disabled, "ordinary Destination Board offers host-selected surface destination")
	if button == null or button.disabled:
		print("SHARED_ARRIVAL_BOARD_DEBUG: ", (_game._rime_expedition if _rime_arrival else _game._aurora_expedition).runtime_state(), " telemetry=", _craft.get_telemetry())
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
		print("SHARED_ARRIVAL_LANDING_FAILED: ", owner.get_visit_snapshot(), " bridge=", _game.get_network_planetary_journey_snapshot(), " cruise=", _game.planetary_cruise_binding.get_snapshot(), " telemetry=", _craft.get_telemetry(), " landing=", _craft.get_landing_contract_report(), " command=", _craft.get_last_ship_command().to_dictionary(), " source_unchanged=", _craft.get_command_source() == source)
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
	_check(owner.capture_interrupted_visit().is_empty(), "shared arrival cannot create solo visit persistence")
	if _rime_arrival:
		_check(not owner.request() and owner.state == &"landed", "partial Rime arrival refuses unsupported return")
	_write("host.landed", {})
	# The existing arrival-support boundary retains its total sixty-second cap.
	var support_deadline := Time.get_ticks_msec() + 60_000
	if not _rime_arrival:
		if not await _wait_file("client.aurora_terrain", 60.0):
			return
		_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id
			and simulation.is_surface_walking(avatar) and body.is_on_floor()
			and not body.is_cabin_containment_active()
			and _game._network_ember_passenger_surface_is_current(avatar)
			and not (_craft.get_in_flight_cabin_report().local_bounds as AABB).has_point(_craft.to_local(body.global_position)),
			"ordinary Aurora egress retains same authoritative body grounded outside the cabin")
		_check(berth.get_occupant() == _craft and _game._piloting and _craft.get_command_source() == source,
			"crew surface walking preserves actual Aurora lease and existing host helm")
		var pose := _craft.global_transform
		var blocked: Dictionary = _game._planetary_journey.begin_aurora_return()
		_check(not owner.request() and not bool(blocked.get("accepted", true))
			and blocked.get("reason") == &"shared_aurora_return_requires_reboarded_crew"
			and owner.state == &"landed" and _craft.global_transform == pose and berth.get_occupant() == _craft,
			"actual exterior Aurora crew refuses both visible and direct home admission without movement")
		_check(owner.runtime_state().get("status_text") == "BOARD ALL CREW TO RETURN"
			and owner.board_action_text() == "BOARD ALL CREW TO RETURN", "visible Aurora return action names the actual crew reboard requirement")
		_write("host.aurora_terrain_checked", {})
	if not await _wait_file("client.arrival_supported", maxf(0.0, float(support_deadline - Time.get_ticks_msec()) / 1000.0)):
		return
	if not _rime_arrival:
		_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id
			and not simulation.is_surface_walking(avatar) and body.is_cabin_containment_active()
			and body.is_on_floor() and not body.is_seated()
			and (_game.network_session.get_boarding_snapshot().get("occupancies", []) as Array).any(
				func(held: Dictionary): return int(held.get("peer_id", 0)) == peer and held.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE),
			"ordinary Aurora reboard restores supported same-body cabin berth without helm")
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not _player.is_seated() \
		and _player.is_on_floor() and _player.is_control_enabled() and not _game._transition_busy, 8.0), "landed host ordinary Exit restores supported cabin standing")
	_check(berth.get_occupant() == _craft and _game.get_network_planetary_journey_snapshot().get("phase") == &"landed", "host cabin standing preserves ordinary berth and shared arrival owner")
	if _home_return:
		if not await _aurora_home_host(owner, avatar, body_id, source):
			return
	_write("host.finish", {})
	await _wait_file("client.disconnected", 30.0)
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(not bool(owner.get("_shared_arrival")) and _game.get_network_planetary_journey_snapshot().get("journey_epoch", 0) == 0, "actual session stop retires shared arrival and resets visit flag through ordinary recovery")
	if _home_return:
		_check(not _game._network_session_is_live() and not owner.is_active()
			and _craft.get_command_source() == source and _player.is_on_floor() and _player.is_control_enabled()
			and not _game._planetary_journey.is_aurora_visit_active(), "home session shutdown hands the same usable pilot and craft back to solo play")


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
	if _rime_arrival:
		_check(await _until(func(): return _game._network_client_boarding_audit.get("last_status") == &"shared_rime_surface_unavailable", 4.0), "actual authenticated Rime hatch explicitly refuses unsupported exterior")
		_check(_game._network_client_boarding_holds(_craft) and source.is_bound()
			and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _player.is_on_floor(), "Rime refusal preserves supported ordinary cabin controls")
	else:
		if not await _aurora_crew_surface_walk(source, body_id, hatch):
			return
	_write("client.arrival_supported", {})
	if _home_return:
		if not await _aurora_home_client(source, body_id, hatch):
			return
	if not await _wait_file("host.finish", 60.0):
		return
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(_player.is_control_enabled(), "actual surface crew disconnect retains usable controls")
	_write("client.disconnected", {})


## No actor transform is written here: ordinary Input crosses the authored
## Halyard airstair onto the selected world's real pad and back into the cabin.
func _aurora_crew_surface_walk(source: NetworkRemoteBodyIntentSource, body_id: int, hatch: ShipCabinHatch) -> bool:
	var confirmed := await _until(func(): return _game._network_client_ember_passenger_surface_is_current(), 12.0)
	_check(confirmed, "ordinary Aurora hatch waits for authenticated retained-body surface departure")
	if not confirmed:
		print("AURORA_CREW_DEPARTURE_DEBUG: ", _game.get_network_client_boarding_audit(), " answer=", _game.network_session.get_boarding_intent_result_replica(), " surface=", _game.get_network_planetary_journey_snapshot())
		return false
	var departure := _game.network_session.get_boarding_intent_result_replica()
	var before := source.get_audit()
	var stale_predictor := Callable(_game, "_network_local_ember_passenger_prediction_is_current").bind(_game._network_client_ember_passenger_surface)
	var policy := _game._network_client_ember_passenger_surface.policy as PlanetarySurfaceGravityPolicy
	_check(policy.get_snapshot().get("world_id") == &"aurora_temperate_world"
		and policy.get_snapshot().get("reference_surface_gravity_mps2") == 9.8,
		"Aurora exterior uses selected terrestrial gravity rather than Ember gravity")
	await _walk(Vector3(-8.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	_check(_player.is_on_floor() and _craft.to_local(_player.global_position).x < -5.0
		and _game._network_client_ember_passenger_surface_is_current()
		and _player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and source.get_audit().sequence > before.sequence and not _player.is_cabin_containment_active(),
		"ordinary Input walks unchanged crew body down airstair onto real Aurora terrain")
	_write("client.aurora_terrain", {})
	if not await _wait_file("host.aurora_terrain_checked", 20.0):
		return false
	var seat_id := StringName(departure.get("seat_id", &""))
	await _aurora_surface_refused_request(source, seat_id, {}, &"surface_return_requires_cabin_entry")
	await _aurora_surface_refused_request(source, seat_id, {"avatar_id": &"foreign_aurora_crew"}, &"surface_return_requires_retained_body")
	await _aurora_surface_refused_request(source, seat_id, {"action": &"swap"}, &"surface_passenger_requires_hatch_return")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _aurora_surface_refused_request(source, seat_id, {"frame_generation": 2}, &"stale_frame_generation")
	await _aurora_surface_refused_request(source, seat_id, {"client_tick": 0}, &"client_tick_too_old")
	before = source.get_audit()
	await _look(hatch.global_position)
	await _press(&"interact")
	var returned := await _until(func(): return _game._network_client_boarding_holds(_craft) \
		and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _player.is_cabin_containment_active(), 12.0)
	_check(returned, "ordinary Aurora hatch reclaims cabin berth on same walking body")
	if not returned:
		print("AURORA_CREW_RETURN_DEBUG: ", _game.get_network_client_boarding_audit(), " answer=", _game.network_session.get_boarding_intent_result_replica(), " pose=", _craft.to_local(_player.global_position))
		return false
	_check(_player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and not _player.is_seated() and not _game._piloting and not bool(stale_predictor.call()),
		"Aurora reboard restores containment without body readmission, predictor reset or helm")
	var pose := _player.global_transform
	_game.network_session.boarding_intent_result.emit(departure.duplicate(true))
	_check(_player.global_transform == pose and _game._network_client_ember_passenger_surface.is_empty()
		and _game._network_client_boarding_holds(_craft), "old accepted departure cannot reopen returned Aurora exterior prediction")
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0), "returned Aurora crew can ordinarily reclaim actual passenger role chair")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not _game._transition_busy, 8.0), "returned Aurora crew can stand to supported cabin walking")
	return _failures.is_empty()


func _aurora_surface_refused_request(source: NetworkRemoteBodyIntentSource, seat_id: StringName,
		changes: Dictionary, expected_status: StringName) -> void:
	_game._network_client_boarding_sequence += 1
	var sequence := _game._network_client_boarding_sequence
	var peer := _game.network_session.multiplayer.get_unique_id()
	var payload: Dictionary = NetworkBoardingIntent.create(peer, source.get_entity_id(), _craft.get_ship_id(),
		1, StringName("frame_%s" % _craft.get_ship_id()), 1, seat_id, 1,
		GameFlow.NETWORK_CABIN_BERTH_ROLE, sequence, _game._network_client_boarding_tick_stamp(),
		NetworkBoardingIntent.ACTION_BOARD).to_dictionary()
	payload.merge(changes, true)
	_check(_game.network_session.send_boarding_intent(payload).accepted, "actual secure Aurora negative boarding request sends")
	var answered := await _until(func(): return int(_game.network_session.get_boarding_intent_result_replica().get("sequence", -1)) == sequence, 4.0)
	var answer := _game.network_session.get_boarding_intent_result_replica()
	_check(answered and not bool(answer.get("accepted", true)) and answer.get("status") == expected_status
		and _game._network_client_ember_passenger_surface_is_current() and source.is_bound()
		and not _game._network_client_boarding_holds(_craft), "authenticated Aurora refuses %s without granting cabin or retiring body" % expected_status)


## Full return is opt-in; the original arrival-only route and all its caps
## remain intact. These legs use the existing 2400-second overall deadline.
func _aurora_home_host(owner: RefCounted, avatar: StringName, body_id: int, pilot_source: Object) -> bool:
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._piloting and _player.is_seated_at(pilot) \
		and not _game._transition_busy, 12.0), "ordinary host cabin re-seat restores return pilot")
	if not _game._piloting or not await _wait_file("client.return_seated", 20.0):
		return false
	var pose := _craft.global_transform
	var velocity := _craft.velocity
	var berth := owner.get("_berth") as ShipBerth
	var token := StringName(owner.get("_surface_token"))
	# A stale real lease cannot authorize a return even with seated crew.
	owner.set("_surface_token", &"retired_aurora_lease")
	var refused: Dictionary = _game._planetary_journey.begin_aurora_return()
	owner.set("_surface_token", token)
	_check(not bool(refused.get("accepted", true)) and owner.state == &"landed"
		and _craft.global_transform == pose and berth.get_reservation_token(_craft) == token,
		"stale Aurora berth grant refuses direct home return without changing actors")
	_game.hud.open_planetary_destination_board()
	var button := _game.hud.find_child("PlanetaryDestinationAction_aurora_temperate_world", true, false) as Button
	_check(button != null and not button.disabled, "current reboarded seated crew enables ordinary Aurora return row")
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	_check(owner.state == &"return_cruise" and _craft.global_transform == pose and _craft.velocity == velocity
		and berth.get_occupant() == _craft and berth.get_reservation_token(_craft) == token,
		"ordinary return admission retains exact physical pose and occupied surface lease")
	if owner.state != &"return_cruise":
		return false
	var sampler := SharedHomeSampler.new()
	sampler.game = _game
	sampler.avatar = avatar
	sampler.body_id = body_id
	sampler.pilot_source = pilot_source
	_game.add_child(sampler)
	_write("host.return_started", {})
	var pad_basis := _craft.global_basis
	var climb := (pad_basis.y * 0.85 - pad_basis.z * 0.5).normalized()
	var height := 0.0
	Input.action_press(&"move_forward")
	for _tick in 1800:
		var local := _craft.global_basis.inverse() * climb
		_home_signed_action(&"move_right", &"move_left", atan2(local.x, -local.z) * 3.0)
		_home_signed_action(&"pitch_up", &"pitch_down", atan2(local.y, Vector2(local.x, local.z).length()) * 3.0)
		await _ticks(1)
		height = (_craft.global_position - (owner.call("_landing_region_origin") as Vector3)).dot(pad_basis.y)
		if height >= 1200.0:
			break
	_home_release_controls()
	_check(height >= 1200.0 and not bool(_craft.get_telemetry().get("landed", true))
		and not is_instance_valid(owner.get("_berth")), "ordinary host pitch/thrust physically clears Aurora and releases its lease")
	var handed_back := await _until(func(): return not owner.is_active(), minf(700.0, _ember_surface_seconds_remaining()))
	var visit := _game._planetary_journey.get_aurora_visit_snapshot()
	_check(handed_back and bool(visit.get("return_handoff_ready", false))
		and not bool(visit.get("active", true)) and _game.phase == GameFlow.Phase.FREE_FLIGHT
		and _game.get_network_planetary_journey_snapshot().get("phase") == &"returning"
		and not is_instance_valid(_game.aurora_streaming_bootstrap.get_loaded_instance()),
		"typed Mudds shell handoff ends Aurora lane while retaining shared return and real cabin crew")
	_write("host.home_handoff", {})
	var docked := handed_back and await _aurora_home_dock()
	await _ticks(2)
	_check(docked and not _game._network_planetary_journey.is_active()
		and _game.get_network_remote_body_simulation().get_body(avatar).get_instance_id() == body_id
		and sampler.failures == 0 and sampler.max_ship_step < 335.0 and sampler.max_body_step < 335.0
		and _game.phase == GameFlow.Phase.SHUT_DOWN and _game._return_registered
		and sampler.rebases > 1100 and sampler.distance > 11_800_000.0
		and _craft.get_command_source() == pilot_source and int(owner.get_visit_snapshot().get("staging_events", -1)) == 0,
		"physical canonical home flight/dock retains exact crew body and helm across every sampled tick without placements")
	sampler.queue_free()
	if not docked:
		return false
	_write("host.home_docked", {})
	if not await _wait_file("client.home_walked", 30.0):
		return false
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() \
		and _player.is_control_enabled() and not _game._transition_busy, 12.0), "ordinary home pilot exit restores supported controls")
	return _failures.is_empty()


func _aurora_home_client(source: NetworkRemoteBodyIntentSource, body_id: int, hatch: ShipCabinHatch) -> bool:
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0),
		"reboarded crew keeps supported passenger chair through physical home return")
	_write("client.return_seated", {})
	if not await _wait_file("host.return_started", 20.0) \
			or not await _wait_file("host.home_handoff", minf(700.0, _ember_surface_seconds_remaining())) \
			or not await _wait_file("host.home_docked", minf(700.0, _ember_surface_seconds_remaining())):
		return false
	_check(await _until(func(): return not _game._network_planetary_journey.is_active(), 12.0) \
		and _player.get_instance_id() == body_id and source == _game.get_network_remote_body_intent_source()
		and source.is_bound() and _player.is_seated_at(_station_anchor()),
		"successful home retirement retains the client's same seated body and predictor without recall")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not _game._transition_busy, 8.0),
		"home passenger chair stand restores supported cabin walking")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return not _game._network_client_boarding_holds(_craft) \
		and _player.is_on_floor() and _player.is_control_enabled() and not _game._transition_busy, 12.0)
		and _player.get_instance_id() == body_id, "ordinary Mudds hatch disembark retains supported client body")
	var start := _player.global_position
	Input.action_press(&"move_right")
	await _ticks(20)
	Input.action_release(&"move_right")
	_check(_player.is_on_floor() and _player.is_control_enabled()
		and _player.global_position.distance_to(start) > 0.25, "returned crew physically walks on the home apron")
	_write("client.home_walked", {})
	return _failures.is_empty()


func _aurora_home_dock() -> bool:
	var home := _game.world.get_berth_node(_craft.get_home_berth_id()) as ShipBerth
	var approach_leg := 0
	var requested := false
	var deadline := Time.get_ticks_msec() + int(minf(700.0, _ember_surface_seconds_remaining()) * 1000.0)
	while Time.get_ticks_msec() < deadline and not _craft.is_destroyed():
		_home_release_controls()
		var report := _game._get_active_landing_assist_report()
		if not requested and report.get("selected_berth_id") == home.get_berth_id() \
				and bool(report.get("assist_capture_accepted", false)):
			Input.action_press(&"landing_assist")
			requested = true
		elif not requested:
			var waypoint := home.get_dock_transform() * Vector3(0.0, 120.0, -200.0) \
				if approach_leg == 0 else home.get_assist_capture_transform().origin
			var offset := waypoint - _craft.global_position
			if approach_leg == 0 and offset.length() < 12.0 and _craft.velocity.length() < 10.0:
				approach_leg = 1
			var local := _craft.global_basis.inverse() * offset.normalized()
			var yaw := atan2(local.x, -local.z)
			var pitch := atan2(local.y, Vector2(local.x, local.z).length())
			_home_signed_action(&"move_right", &"move_left", yaw * 3.0)
			_home_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
			var up := home.global_basis.y.normalized()
			_home_signed_action(&"roll_right", &"roll_left", atan2(up.dot(_craft.global_basis.x), up.dot(_craft.global_basis.y)) * 3.0)
			var speed := minf(_craft.maximum_speed * 0.9, sqrt(maxf(0.0, offset.length() - 5.0) * _craft.brake_acceleration) * 0.6)
			Input.action_press(&"move_forward" if absf(yaw) < 0.08 and absf(pitch) < 0.08 \
				and _craft.velocity.length() < speed else &"brake")
		await _ticks(1)
		if bool(_craft.get_telemetry().get("landed", false)) and not _craft.is_landing_active() and home.get_occupant() == _craft:
			_home_release_controls()
			if _game.phase == GameFlow.Phase.SHUT_DOWN and _game._return_registered:
				return _game._ship_owns_exact_occupied_berth(_craft, home.get_berth_id())
		if requested and not _craft.is_landing_active() and not bool(_craft.get_telemetry().get("landed", false)):
			requested = false
	_home_release_controls()
	return false


func _home_signed_action(positive: StringName, negative: StringName, strength: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if absf(strength) > 0.005:
		Input.action_press(positive if strength > 0.0 else negative, minf(absf(strength), 1.0))


func _home_release_controls() -> void:
	for action in [&"move_forward", &"move_left", &"move_right", &"pitch_up", &"pitch_down", &"roll_left", &"roll_right", &"brake", &"landing_assist"]:
		Input.action_release(action)


class SharedHomeSampler extends Node:
	var game: GameFlow
	var avatar: StringName
	var body_id: int
	var pilot_source: Object
	var failures := 0
	var rebases := 0
	var distance := 0.0
	var max_ship_step := 0.0
	var max_body_step := 0.0
	var _ship_position := Vector3.INF
	var _body_position := Vector3.INF
	var _translation := Vector3.ZERO

	func _ready() -> void:
		process_physics_priority = 1000
		game.common_world_origin_rebase_owner.rebase_committed.connect(_on_rebase)

	func _exit_tree() -> void:
		game.common_world_origin_rebase_owner.rebase_committed.disconnect(_on_rebase)

	func _on_rebase(receipt: Dictionary) -> void:
		_translation += receipt.get("world_translation_delta", Vector3.ZERO) as Vector3
		rebases += 1

	func _physics_process(_delta: float) -> void:
		var craft := game.active_ship
		var body := game.get_network_remote_body_simulation().get_body(avatar) as PlayerController
		if not is_instance_valid(body) or body.get_instance_id() != body_id:
			failures += 1
			return
		if _ship_position.is_finite():
			var step := craft.global_position.distance_to(_ship_position + _translation)
			distance += step
			max_ship_step = maxf(max_ship_step, step)
			max_body_step = maxf(max_body_step, body.global_position.distance_to(_body_position + _translation))
		_ship_position = craft.global_position
		_body_position = body.global_position
		_translation = Vector3.ZERO
		failures += int(craft.is_destroyed() or not craft.is_piloted()
			or craft.get_command_source() != pilot_source or not game.player.is_seated_at(craft.get_pilot_seat_anchor())
			or not body.is_cabin_containment_active())


# One existing owned-peer profile. This is deliberately a staged production
# current-state probe, not an outbound journey or late cabin-admission claim.
# Both peers retain the inherited 300-second whole and 120/60-second stage caps.
func _peer_profile() -> Dictionary:
	if _ember_passive_progress:
		return {"client_roles": ["client"], "private_environment": true,
			"total_seconds": 300.0, "abort_exit_grace_seconds": 10.0}
	return super._peer_profile()


func _host() -> void:
	if not _ember_passive_progress:
		await super._host()
		return
	await _passive_ember_host()


func _client() -> void:
	if not _ember_passive_progress:
		await super._client()
		return
	await _passive_ember_client()


func _passive_operands() -> Dictionary:
	return {"journey": _game.get_network_planetary_journey_snapshot(),
		"survey": _game.get_network_ember_survey_snapshot(),
		"director": _game.activity_director.get_activity_snapshot(&"ember_beacon_survey"),
		"host": _game.ember_surface_loop_host.get_return_status_snapshot(),
		"surface": _game.ember_surface_loop_production_binding.get_planetary_surface_snapshot(),
		"save_generation": _game._runtime_settings_user_data_store.get_generation(),
		"body_source": _game.get_network_remote_body_intent_source(), "phase": _game.phase}


func _passive_require(condition: bool, description: String, operands: Dictionary = {}) -> bool:
	if not condition:
		print("EMBER_PASSIVE_PROGRESS_OPERANDS: ", description, " actual=", operands if not operands.is_empty() else _passive_operands())
	_check(condition, description)
	return condition


func _passive_stage_surface(point: Vector3) -> bool:
	# Fixture placement uses the actual scene's solid support. The production
	# Host/binding still observe the actor and advance their normal lifecycle.
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 64.0, point - Vector3.UP * 64.0, 1)
	query.exclude = [_player.get_rid()]
	var floor := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not _passive_require(not floor.is_empty(), "staged survey actor has actual authored support", {"point": point, "floor": floor}):
		return false
	_player.teleport_to(Transform3D(Basis.IDENTITY, (floor.position as Vector3) + Vector3.UP * 0.06))
	await _ticks(12)
	return true


func _passive_ember_host() -> void:
	if not _passive_require(bool(_game.host_network_session(_port).get("accepted", false)), "passive progress host starts actual authenticated ENet"):
		return
	# Boot the future observer now, but it will not connect until index one.
	_write("host.ready", {})
	_player.teleport_to(_craft.get_boarding_entry_transform())
	_game._board_ship(_craft)
	if not _passive_require(await _until(func(): return _game._piloting and not _game._transition_busy, 15.0), "actual production boarding retains host pilot"):
		return
	_game._sortie_departed_berth = true
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	var claimed := _game._claim_network_host_pilot_seat(_craft)
	if not _passive_require(bool(claimed.get("accepted", false)), "ordinary boarding ledger confirms host pilot", {"claim": claimed}):
		return
	var frame := _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := _game.planetary_cruise_binding.get_snapshot().canonical_destination_orbital as Dictionary
	var decoded := frame.orbital_to_world_streaming_position(canonical, frame.get_generation())
	var destination: Vector3 = decoded.position
	# Established shared-surface fixture: stage only the initial flight
	# envelope; typed approach, supported touchdown and disembark remain real.
	_craft.global_position = destination + Vector3.BACK * 500.0
	_craft.global_basis = Basis.looking_at((destination - _craft.global_position).normalized(), Vector3.UP)
	_craft.velocity = Vector3.ZERO
	var admitted := _game.engage_planetary_cruise()
	if not _passive_require(bool(admitted.get("accepted", false)), "shared admission owns the real Ember approach", {"admission": admitted, "state": _passive_operands()}):
		return
	if not _passive_require(await _until(func(): return _game._planetary_journey.shared_ember_surface_is_current(), 120.0), "physical typed landing composes actual shared production surface"):
		return
	var host := _game.ember_surface_loop_host
	if not _passive_require(await _until(func(): return host.get_phase() == EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 20.0), "production Host disembarks to the actual authored surface"):
		return
	var anchors := host.get_return_status_snapshot().surface_route as Dictionary
	if not await _passive_stage_surface(anchors.egress_anchor) or not await _passive_stage_surface(anchors.staging_anchor):
		return
	if not _passive_require(await _until(func(): return _game.ember_surface_loop_production_binding.get_planetary_surface_snapshot().adapter.activity_reward.state == &"active", 4.0), "supported staged outbound anchors start actual mandatory survey"):
		return
	var landing := _game.ember_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	if not await _passive_stage_surface(landing.to_global(Vector3(160.0, 0.0, -30.0))):
		return
	if not _passive_require(await _until(func(): return int(_game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get("next_checkpoint_index", -1)) == 1, 4.0), "actual production position observation advances genuine Director to checkpoint one"):
		return
	_game._network_planetary_journey._publish(true)
	var progress := _passive_survey_fields(_game.get_network_ember_survey_snapshot())
	if not _passive_require(progress.get("state") == &"active" and int(progress.get("next_checkpoint_index", -1)) == 1
		and int(progress.get("checkpoint_count", -1)) == 2 and not bool(progress.get("reward_committed", true))
		and progress.get("next_objective_id") == &"ember_return_beacon", "published host readback matches genuine ACTIVE/index1/count2/unpaid", {"progress": progress, "production": _passive_operands()}):
		return
	# Keep the ordinary host clock running at this stationary real checkpoint.
	# Compare logical progress/payment operands independently of presentation time.
	var retained := _passive_operands()
	_write("host.progress", {"survey": progress})
	if not await _wait_file("client.progress", 60.0):
		return
	var received := _read("client.progress")
	var peer := int(received.peer_id)
	var accepted := bytes_to_var(Marshalls.base64_to_raw(str(received.packet_bytes))) as Dictionary
	# Actual authority RPCs exercise the adapter's authenticated envelope.
	# The source remains the same host; each malformed identity is explicit.
	for field in ["recipient_peer_id", "peer_generation", "session_generation", "migration_generation"]:
		var bad := accepted.duplicate(true)
		bad[field] = int(bad[field]) + 1
		bad["revision"] = int(_game.network_session.get("_planetary_journey_revision")) + 100
		# A valid different logical view makes accidental acceptance visible;
		# normal publications cannot erase its higher activity generation.
		(bad.ember_survey as Dictionary)["activity_generation"] = int((bad.ember_survey as Dictionary).activity_generation) + 10
		(bad.ember_survey as Dictionary)["next_checkpoint_index"] = 0
		(bad.ember_survey as Dictionary)["next_objective_id"] = &"ember_relay_tower"
		_game.network_session.rpc_id(peer, &"_broadcast_planetary_journey_bootstrap", bad)
	_game.network_session.rpc_id(peer, &"_broadcast_planetary_journey_bootstrap", accepted)
	var old := accepted.duplicate(true)
	old["revision"] = int(accepted.revision) - 1
	_game.network_session.rpc_id(peer, &"_broadcast_planetary_journey_bootstrap", old)
	_write("host.replayed", {})
	if not await _wait_file("client.fenced", 60.0):
		return
	var after := _passive_operands()
	if not _passive_require(after.director == retained.director and after.surface.adapter.activity_reward == retained.surface.adapter.activity_reward
		and after.surface.relay_survey.mandatory_route == retained.surface.relay_survey.mandatory_route
		and after.save_generation == retained.save_generation and after.survey == retained.survey,
		"fresh observer and replay fences mutate no production checkpoint, save or payment", {"before": retained, "after": after}):
		return
	# Retire through the existing production visit owner; this probe claims no
	# physical return or late cabin admission.
	_game._network_planetary_journey.cancel(&"passive_progress_test_complete")
	_write("host.retired", {})
	await _wait_file("client.retired", 60.0)


func _passive_ember_client() -> void:
	if not await _wait_file("host.progress", 120.0):
		return
	var local_director := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
	var pre_join_generation := _game._runtime_settings_user_data_store.get_generation()
	var pre_join_payload := _game._runtime_settings_user_data_store.get_snapshot()
	if not _passive_require(bool(_game.join_network_session("127.0.0.1", _port).get("accepted", false)), "fresh observer connects only after host checkpoint one"):
		return
	# Accepted join synchronously withdraws the old solo recovery context.
	# Establish the passive-reception baseline after that expected setup write,
	# before any yield can deliver authenticated progress packets.
	var local_save := _game._runtime_settings_user_data_store.get_generation()
	var local_payload := _game._runtime_settings_user_data_store.get_snapshot()
	var expected_join_payload := pre_join_payload.duplicate(true)
	expected_join_payload[GameFlow.SOLO_SAFE_RECOVERY_SLOT] = {"mode": "unavailable"}
	_write("client.join_setup", {"generation_before": pre_join_generation, "generation_after": local_save,
		"payload_before": pre_join_payload, "payload_after": local_payload})
	if not _passive_require(local_save == pre_join_generation + 1 and local_payload == expected_join_payload,
		"accepted join changes only solo recovery before passive packet reception",
		{"generation_before": pre_join_generation, "generation_after": local_save,
		"expected_payload": expected_join_payload, "actual_payload": local_payload}):
		return
	if not _passive_require(await _until(func(): return _admitted_session_ready() and not _game.get_network_ember_survey_snapshot().is_empty(), 12.0), "fresh authenticated recipient consumes current real Ember progress"):
		return
	var expected := _passive_survey_fields(_read("host.progress").survey as Dictionary)
	var survey := _passive_survey_fields(_game.get_network_ember_survey_snapshot())
	var packet := _game.get_network_planetary_journey_snapshot()
	if not _passive_require(survey == expected and survey.get("state") == &"active"
		and int(survey.get("next_checkpoint_index", -1)) == 1 and int(survey.get("checkpoint_count", -1)) == 2
		and not bool(survey.get("reward_committed", true)) and survey.get("next_objective_id") == &"ember_return_beacon",
		"fresh current envelope delivers actual host progress without local defaults", {"expected": expected, "survey": survey, "packet": packet}):
		return
	_write("client.progress", {"survey": survey, "packet_bytes": Marshalls.raw_to_base64(var_to_bytes(packet)), "peer_id": _game.network_session.multiplayer.get_unique_id()})
	if not await _wait_file("host.replayed", 60.0):
		return
	await _ticks(12)
	if not _passive_require(_passive_survey_fields(_game.get_network_ember_survey_snapshot()) == survey,
		"actual authenticated duplicate, old and foreign session envelopes preserve accepted view", {"before": packet, "after": _game.get_network_planetary_journey_snapshot()}):
		return
	# The consumer also fences same-epoch world/ship substitution and stale
	# production generations even after the transport authenticated a sender.
	for field in ["world_id", "ship_id", "journey_epoch", "host_generation", "host_attachment_generation", "composition_generation", "activity_generation"]:
		var bad := _game.get_network_planetary_journey_snapshot()
		bad["revision"] = int(bad.revision) + 1
		if field == "world_id":
			bad[field] = &"aurora_temperate_world"
		elif field == "ship_id":
			bad[field] = &"foreign_ship"
		elif field == "journey_epoch":
			bad[field] = 0
		else:
			(bad.ember_survey as Dictionary)[field] = int((bad.ember_survey as Dictionary)[field]) - 1
		_game._network_planetary_journey.consume_state(bad)
		if not _passive_require(_passive_survey_fields(_game.get_network_ember_survey_snapshot()) == survey, "bridge refuses stale or substituted " + field,
			{"candidate": bad, "expected": survey, "actual": _game.get_network_ember_survey_snapshot()}):
			return
	var session_epoch := _game._network_hud_session_epoch
	_game._network_hud_session_epoch += 1
	var detached_view := _game.get_network_ember_survey_snapshot()
	_game._network_hud_session_epoch = session_epoch
	if not _passive_require(detached_view.is_empty() and _passive_survey_fields(_game.get_network_ember_survey_snapshot()) == survey,
		"passive getter requires the accepting local session lifetime", {"detached": detached_view, "restored": _game.get_network_ember_survey_snapshot(), "expected": survey}):
		return
	var after_director := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
	var after_save := _game._runtime_settings_user_data_store.get_generation()
	var after_payload := _game._runtime_settings_user_data_store.get_snapshot()
	if not _passive_require(after_director == local_director and after_save == local_save and after_payload == local_payload
		and _game.get_network_remote_body_intent_source() == null and not _player.is_seated()
		and not _game.ember_surface_loop_production_binding.has_planetary_surface_composition(),
		"passive current progress creates no local Director, save, reward or cabin authority",
		{"director_before": local_director, "director_after": after_director, "save_before": local_save, "save_after": after_save,
			"payload_before": local_payload, "payload_after": after_payload, "actual": _passive_operands()}):
		return
	if not _passive_verify_hud():
		return
	_write("client.fenced", {})
	if not await _wait_file("host.retired", 60.0):
		return
	if not _passive_require(await _until(func(): return _game.get_network_ember_survey_snapshot().is_empty(), 5.0), "authenticated retirement clears passive current Ember view"):
		return
	var delayed := packet.duplicate(true)
	delayed["revision"] = int(packet.revision) + 100
	_game._network_planetary_journey.consume_state(delayed)
	if not _passive_require(_game.get_network_ember_survey_snapshot().is_empty() and not _game._network_planetary_journey.is_active(),
		"retired epoch cannot be revived by delayed higher revision progress", {"delayed": delayed, "current": _game.get_network_planetary_journey_snapshot(), "survey": _game.get_network_ember_survey_snapshot()}):
		return
	_write("client.retired", {})


func _passive_survey_fields(survey: Dictionary) -> Dictionary:
	if survey.is_empty():
		return {}
	return {"activity_id": str(survey.get("activity_id", "")), "state": str(survey.get("state", "")),
		"next_objective_id": str(survey.get("next_objective_id", "")),
		"activity_generation": int(survey.get("activity_generation", -1)),
		"next_checkpoint_index": int(survey.get("next_checkpoint_index", -1)),
		"checkpoint_count": int(survey.get("checkpoint_count", -1)),
		"reward_committed": bool(survey.get("reward_committed", false)),
		"host_generation": int(survey.get("host_generation", -1)),
		"host_attachment_generation": int(survey.get("host_attachment_generation", -1)),
		"composition_generation": int(survey.get("composition_generation", -1))}


func _passive_verify_hud() -> bool:
	var fixture := PassiveSurveyPresentation.new()
	fixture.recipient = _game
	fixture.hud = _game.hud
	fixture.phase = GameFlow.Phase.BOARDING
	fixture._network_client_ember_passenger_surface = {"world_id": &"ember_moon"}
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	fixture.interaction = hatch
	fixture._update_on_foot_flow()
	var objective: String = _game.hud.get("_objective_source_text")
	var prompt: String = _game.hud.get("_interaction_source_text")
	var expected_prompt := hatch.get_interaction_prompt()
	var passed := _passive_require(objective == "HOST SURVEY 1 / 2 — RETURN BEACON"
		and not expected_prompt.is_empty() and prompt == expected_prompt,
		"staged presentation unit renders actual recipient objective and preserves real hatch prompt",
		{"objective": objective, "prompt": prompt, "hatch_prompt": expected_prompt,
		"recipient": _game.get_network_ember_survey_snapshot(), "qualification": "exterior predicate and discovery staged; no physical admission"})
	fixture.exterior_current = false
	fixture._update_on_foot_flow()
	passed = _passive_require(str(_game.hud.get("_objective_source_text")).is_empty()
		and fixture._network_client_aurora_survey_presentation.is_empty(),
		"staged presentation context loss clears its owned passive Ember objective",
		{"objective": _game.hud.get("_objective_source_text"), "owned": fixture._network_client_aurora_survey_presentation}) and passed
	fixture.exterior_current = true
	fixture.interaction = null
	fixture._update_on_foot_flow()
	_game.hud.set_objective("replacement objective", "REPLACEMENT")
	_game.hud.set_interaction("replacement prompt")
	fixture._clear_network_client_aurora_survey_presentation()
	passed = _passive_require(_game.hud.get("_objective_source_text") == "replacement objective"
		and _game.hud.get("_interaction_source_text") == "replacement prompt",
		"owned passive Ember cleanup preserves newer HUD producers",
		{"objective": _game.hud.get("_objective_source_text"), "prompt": _game.hud.get("_interaction_source_text")}) and passed
	fixture.hud = null
	fixture.recipient = null
	fixture.free()
	return passed
