## test-matrix-display: input-only
extends "res://tests/network/halyard_network_passenger_route_test.gd"

## The ordinary matrix runs the same real-peer shared journey harness.
func _run() -> void:
	_rime_arrival = "--rime-shared-arrival" in OS.get_cmdline_user_args()
	_home_return = not _rime_arrival and "--aurora-shared-home-return" in OS.get_cmdline_user_args()
	_surface_arrival = _rime_arrival or _home_return or "--aurora-shared-arrival" in OS.get_cmdline_user_args()
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


func _initial_crew_roles() -> Array[String]:
	return ["client", "client_b"] if _rime_arrival else super._initial_crew_roles()


func _check(condition: bool, description: String) -> void:
	super._check(condition, description)
	if _rime_arrival and not condition:
		# The external owner aborts every private peer on the first failure.
		print("FAIL: " + description)


func _orchestrate() -> void:
	if _surface_arrival:
		# Aurora retains the separate staged solo-admission regression. Rime's
		# qualification begins directly at the ordinary real-peer Mudds route.
		if not _rime_arrival:
			await _verify_solo_shared_admission_rejection()
		_ember_surface = true
		_shared_cruise = false
	await super._orchestrate()
	if _failures.is_empty():
		if _home_return:
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
var _admission_flight_ticks := 0
var _rime_crew: Dictionary = {}
var _rime_pilot_source: Object
const RIME_ADMISSION_FLIGHT_TICKS := 48_000


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
	if _rime_arrival:
		_rime_crew["client"] = {"peer": peer, "avatar": avatar, "body": body, "body_id": body_id,
			"generation": simulation.get_body_record(avatar).entity_generation}
		if not await _wait_file("client_b.cabin", 60.0):
			return
		var companion_peer := int(_read("client_b.cabin").peer_id)
		var companion_avatar := _game.network_client_boarding_avatar_id(companion_peer)
		var companion := simulation.get_body(companion_avatar) as PlayerController
		_check(is_instance_valid(companion) and companion != body, "second independent Rime peer owns its distinct real authoritative cabin body")
		if not is_instance_valid(companion):
			return
		_rime_crew["client_b"] = {"peer": companion_peer, "avatar": companion_avatar, "body": companion,
			"body_id": companion.get_instance_id(), "generation": simulation.get_body_record(companion_avatar).entity_generation}
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._piloting and _player.is_seated_at(pilot) and not _game._transition_busy, 12.0), "ordinary cockpit owns actual host pilot")
	if not _game._piloting:
		return
	if _rime_arrival:
		_rime_pilot_source = _craft.get_command_source()
	# Physical departure, rather than the fixture's later starting envelope,
	# must release the dock before the normal Destination Board admits travel.
	var launch_source := _craft.get_local_input_source()
	launch_source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	var home_position := _craft.global_position
	if _rime_arrival:
		# This marker starts ordinary departure, not cruise admission. Its
		# original 20 s client cap excludes the real flight inside the 2400 s leg.
		_write("host.flight_started", {})
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
	if _rime_arrival:
		if not await _rime_fly_admission_envelope(destination):
			return
	else:
		# Retain the existing Aurora fixture envelope unchanged.
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
	if _rime_arrival:
		var ready := _game.get_network_planetary_journey_snapshot().get("ready_peers", []) as Array
		_check(ready.has(peer) and ready.has(int(_rime_crew.client_b.peer)), "both independent Rime clients acknowledge the correct world before canonical cruise")
	else:
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
	_write("host.landed", {})
	# The existing arrival-support boundary retains its total sixty-second cap.
	var support_deadline := Time.get_ticks_msec() + 60_000
	if _rime_arrival:
		if not await _rime_arrival_crew_host(owner, berth, source, support_deadline):
			return
	else:
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
	if not _rime_arrival and not await _wait_file("client.arrival_supported", maxf(0.0, float(support_deadline - Time.get_ticks_msec()) / 1000.0)):
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
	for role in _initial_crew_roles():
		if not await _wait_file(role + ".disconnected", 30.0):
			return
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(not bool(owner.get("_shared_arrival")) and _game.get_network_planetary_journey_snapshot().get("journey_epoch", 0) == 0, "actual session stop retires shared arrival and resets visit flag through ordinary recovery")
	if _home_return:
		_check(not _game._network_session_is_live() and not owner.is_active()
			and _craft.get_command_source() == source and _player.is_on_floor() and _player.is_control_enabled()
			and not _game._planetary_journey.is_aurora_visit_active(), "home session shutdown hands the same usable pilot and craft back to solo play")


## The same two host-owned cabin bodies must survive every sampled flight tick.
func _rime_crew_are_current() -> bool:
	var simulation := _game.get_network_remote_body_simulation()
	for held: Dictionary in _rime_crew.values():
		var body := simulation.get_body(held.avatar) as PlayerController
		var record := simulation.get_body_record(held.avatar)
		if not is_instance_valid(body) or body != held.body or body.get_instance_id() != int(held.body_id) \
				or int(record.get("entity_generation", 0)) != int(held.generation) \
				or int(record.get("owner_peer_id", 0)) != int(held.peer):
			return false
	return _rime_crew.size() == 2


## Fly the old Mudds-side admission envelope with actual controls. There are no
## actor/phase/velocity writes after the disclosed pre-route hatch approach.
func _rime_fly_admission_envelope(destination: Vector3) -> bool:
	var source := _craft.get_command_source()
	var target := Vector3(0.0, 5000.0, -8640.0).normalized() * 9995.0
	var outward := (-_craft.global_basis.z).slide(Vector3.UP).normalized()
	var climb := (outward * 0.5 + Vector3.UP * 0.866).normalized()
	var collision := _craft.get_landing_collision_report()
	var bounds := collision.get("local_bounds", AABB()) as AABB
	var valid_hull := bool(collision.get("valid", false)) and bounds.has_volume()
	_check(valid_hull, "physical Rime departure uses the actual full-hull collision bounds for station clearance")
	if not valid_hull:
		return false
	var corner := Vector3(maxf(absf(bounds.position.x), absf(bounds.end.x)),
		maxf(absf(bounds.position.y), absf(bounds.end.y)), maxf(absf(bounds.position.z), absf(bounds.end.z)))
	var clearance_y := AbandonedStationHulk.HULK_ANCHOR.y + AbandonedStationHulk.HULL_BOUNDING_RADIUS + corner.length() + 5.0
	var cleared := false
	var reached := false
	var aligned := false
	var fault := ""
	var deadline := Time.get_ticks_msec() + int(_ember_surface_seconds_remaining() * 1000.0)
	while Time.get_ticks_msec() < deadline and _admission_flight_ticks < RIME_ADMISSION_FLIGHT_TICKS:
		_home_release_controls()
		if _craft.is_destroyed() or _craft.get_command_source() != source \
				or not _game._piloting or not _player.is_seated_at(_craft.get_pilot_seat_anchor()) \
				or not _rime_crew_are_current():
			fault = "original pilot, source or crew lost during physical Mudds departure"
			break
		cleared = cleared or _craft.global_position.y >= clearance_y
		var offset := target - _craft.global_position
		reached = reached or (cleared and offset.length() < 25.0 and _craft.velocity.length() < 0.1)
		var direction := (destination - _craft.global_position).normalized() if reached else (offset.normalized() if cleared else climb)
		var local := _craft.global_basis.inverse() * direction
		var yaw := atan2(local.x, -local.z)
		var pitch := atan2(local.y, Vector2(local.x, local.z).length())
		_home_signed_action(&"move_right", &"move_left", yaw * 3.0)
		_home_signed_action(&"pitch_up", &"pitch_down", pitch * 3.0)
		var speed := minf(_craft.maximum_speed * 0.9, sqrt(maxf(0.0, offset.length() - 5.0) * _craft.brake_acceleration) * 0.6)
		if reached:
			Input.action_press(&"brake")
			aligned = (-_craft.global_basis.z.normalized()).dot(direction) >= PlanetaryCruisePolicy.ENGAGE_ALIGNMENT_DOT \
				and _craft.velocity.length() < 0.1
			if aligned:
				break
		else:
			Input.action_press(&"move_forward" if absf(yaw) < 0.12 and absf(pitch) < 0.12 \
				and _craft.velocity.length() < speed else &"brake")
		await physics_frame
		_admission_flight_ticks += 1
	_home_release_controls()
	_check(aligned and reached and fault.is_empty() and _game._sortie_departed_berth \
		and _game.phase == GameFlow.Phase.FREE_FLIGHT and not bool(_craft.get_telemetry().get("landed", true)),
		"ordinary pitch/yaw/thrust/brake reaches and faces Rime from the same 9995m admission envelope: " + fault)
	if not aligned:
		print("RIME_SHARED_PREFLIGHT_DEBUG: position=", _craft.global_position, " velocity=", _craft.velocity,
			" target=", target, " cleared=", cleared, " reached=", reached, " ticks=", _admission_flight_ticks,
			" telemetry=", _craft.get_telemetry())
	return aligned and reached and fault.is_empty()


func _rime_host_crew_support(role: String, exterior: bool) -> bool:
	var held := _rime_crew[role] as Dictionary
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(held.avatar) as PlayerController
	if not _rime_crew_are_current() or not is_instance_valid(body):
		return false
	if exterior:
		return simulation.is_surface_walking(held.avatar) and body.is_on_floor() \
			and not body.is_cabin_containment_active() \
			and _game._network_ember_passenger_surface_is_current(held.avatar) \
			and not (_craft.get_in_flight_cabin_report().local_bounds as AABB).has_point(_craft.to_local(body.global_position))
	return not simulation.is_surface_walking(held.avatar) and body.is_cabin_containment_active() \
		and body.is_on_floor() and not body.is_seated() \
		and (_game.network_session.get_boarding_snapshot().get("occupancies", []) as Array).any(
			func(occupancy: Dictionary): return int(occupancy.get("peer_id", 0)) == int(held.peer) \
				and occupancy.get("avatar_id") == held.avatar and occupancy.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE)


func _rime_host_return_blocked(owner: RefCounted, berth: ShipBerth, source: Object) -> bool:
	var pose := _craft.global_transform
	var velocity := _craft.velocity
	var blocked: Dictionary = _game._planetary_journey.begin_aurora_return()
	var refused := not owner.request() and not bool(blocked.get("accepted", true)) \
		and blocked.get("reason") == &"shared_rime_return_requires_reboarded_crew" \
		and owner.state == &"landed" and _craft.global_transform == pose and _craft.velocity == velocity \
		and berth.get_occupant() == _craft and _game._piloting and _craft.get_command_source() == source
	_check(refused, "actual exterior Rime crew refuses visible and direct return without moving the craft or changing host helm")
	_check(not bool(owner.runtime_state().get("action_enabled", true)) \
		and owner.runtime_state().get("status_text") == "BOARD ALL CREW TO RETURN" \
		and owner.board_action_text() == "BOARD ALL CREW TO RETURN",
		"visible Rime return names the actual all-crew reboard requirement")
	return refused and _failures.is_empty()


## First only client outside, then both outside, then only client_b outside,
## then both confirmed in the cabin.
## The original single sixty-second arrival-support deadline owns every barrier.
func _rime_arrival_crew_host(owner: RefCounted, berth: ShipBerth, source: Object, deadline: int) -> bool:
	if not await _wait_file("client.rime_terrain", maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)):
		return false
	_check(_rime_host_crew_support("client", true) and _rime_host_crew_support("client_b", false),
		"first Rime egress retains the original supported exterior body while its companion remains in the actual cabin")
	if not _rime_host_return_blocked(owner, berth, source):
		return false
	_write("host.rime_first_exterior_checked", {})
	if not await _wait_file("client_b.rime_terrain", maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)):
		return false
	_check(_rime_host_crew_support("client", true) and _rime_host_crew_support("client_b", true),
		"both ordinary Rime egresses retain the original supported authoritative exterior bodies")
	if not _rime_host_return_blocked(owner, berth, source):
		return false
	_write("host.rime_both_exterior_checked", {})
	if not await _wait_file("client.arrival_supported", maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)):
		return false
	_check(_rime_host_crew_support("client", false) and _rime_host_crew_support("client_b", true),
		"first Rime reboard restores its original supported cabin body while the companion remains supported outside")
	if not _rime_host_return_blocked(owner, berth, source):
		return false
	_write("host.rime_first_reboard_checked", {})
	if not await _wait_file("client_b.arrival_supported", maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)):
		return false
	_check(_rime_host_crew_support("client", false) and _rime_host_crew_support("client_b", false),
		"both ordinary Rime hatch reboards retain original supported authoritative cabin bodies and authenticated crew identities")
	_check(_game._network_planetary_journey.shared_surface_return_gate_reason(_arrival_world_id).is_empty() \
		and bool(owner.runtime_state().get("action_enabled", false)) and owner.board_action_text() == "RETURN TO MUDDS" \
		and owner.state == &"landed" and berth.get_occupant() == _craft \
		and _game._piloting and _craft.get_command_source() == source \
		and _game.get_network_planetary_journey_snapshot().get("phase") == &"landed",
		"both confirmed Rime reboards clear return admission while keeping the host helm and occupied pad without starting home")
	return _failures.is_empty()


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
		if _rime_arrival:
			# The expedition retains its existing 48,000 outbound tick cap;
			# this sampler additionally follows both original bodies and helm.
			if not _rime_crew_are_current() or _craft.get_command_source() != _rime_pilot_source:
				fault = "original Rime pilot source or authoritative crew identity lost"
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
	if _rime_arrival and _role == "client_b" and not await _wait_file("client.cabin", 60.0):
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
	var initial_source := source.get_audit()
	await _walk(Vector3(1.3 if _rime_arrival and _role == "client_b" else -1.3, 0.52, -5.8))
	_write(_role + ".cabin", {"peer_id": _game.network_session.multiplayer.get_unique_id()})
	if _rime_arrival and _role == "client" and not await _wait_file("client_b.cabin", 60.0):
		return
	if not await _wait_file("host.flight_started", 20.0) \
			or not await _wait_file("host.approaching", _ember_surface_seconds_remaining()) \
			or not await _wait_file("host.landed", 120.0):
		return
	_check(await _until(func(): return _game.get_network_planetary_journey_snapshot().get("phase") == &"landed" \
		and is_instance_valid((_game.rime_streaming_bootstrap if _rime_arrival else _game.aurora_streaming_bootstrap).get_loaded_instance()), 12.0), "authenticated surface arrival and actual client terrain agree")
	_check(_game.get_network_planetary_journey_snapshot().get("world_id") == _arrival_world_id
		and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true))
		and _player.get_instance_id() == body_id and source == _game.get_network_remote_body_intent_source()
		and source.is_bound() and source.get_audit().stream_id == initial_source.stream_id
		and source.get_audit().entity_generation == initial_source.entity_generation,
		"client remains same real crew body/source and never owns a cruise attachment")
	var previous := _craft.to_local(_player.global_position)
	await _walk(Vector3(-1.0 if _rime_arrival and _role == "client_b" else 1.0, 0.52, -5.8))
	_check(_craft.to_local(_player.global_position).distance_to(previous) > 0.6 and _player.is_on_floor(), "ordinary landed cabin walk stays supported on actual hull")
	if _rime_arrival and _role == "client_b":
		# The companion waits clear of the single passenger chair/airstair.
		if not await _wait_file("host.rime_first_exterior_checked", 20.0):
			return
	else:
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
	if not await _aurora_crew_surface_walk(source, body_id, hatch):
		return
	if _rime_arrival:
		_check(source == _game.get_network_remote_body_intent_source() and source.is_bound()
			and source.get_audit().stream_id == initial_source.stream_id
			and source.get_audit().entity_generation == initial_source.entity_generation,
			"entire Rime departure, canonical arrival, surface walk and reboard retain the original client intent source and generation")
	_write(_role + ".arrival_supported", {})
	if _home_return:
		if not await _aurora_home_client(source, body_id, hatch):
			return
	if not await _wait_file("host.finish", 60.0):
		return
	_game.shutdown_network_session(&"surface_arrival_test_done")
	_check(_player.is_control_enabled(), "actual surface crew disconnect retains usable controls")
	_write(_role + ".disconnected", {})


## No actor transform is written here: ordinary Input crosses the authored
## Halyard airstair onto the selected world's real pad and back into the cabin.
func _aurora_crew_surface_walk(source: NetworkRemoteBodyIntentSource, body_id: int, hatch: ShipCabinHatch) -> bool:
	var world_name := "Rime" if _rime_arrival else "Aurora"
	var confirmed := await _until(func(): return _game._network_client_ember_passenger_surface_is_current(), 12.0)
	_check(confirmed, "ordinary %s hatch waits for authenticated retained-body surface departure" % world_name)
	if not confirmed:
		print("AURORA_CREW_DEPARTURE_DEBUG: ", _game.get_network_client_boarding_audit(), " answer=", _game.network_session.get_boarding_intent_result_replica(), " surface=", _game.get_network_planetary_journey_snapshot())
		return false
	var departure := _game.network_session.get_boarding_intent_result_replica()
	var before := source.get_audit()
	var stale_predictor := Callable(_game, "_network_local_ember_passenger_prediction_is_current").bind(_game._network_client_ember_passenger_surface)
	var policy := _game._network_client_ember_passenger_surface.policy as PlanetarySurfaceGravityPolicy
	var expected_gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) if _rime_arrival else 9.8
	_check(policy.get_snapshot().get("world_id") == _arrival_world_id
		and policy.get_snapshot().get("reference_surface_gravity_mps2") == expected_gravity,
		"%s exterior uses its selected terrestrial gravity" % world_name)
	await _walk(Vector3(-8.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	_check(_player.is_on_floor() and _craft.to_local(_player.global_position).x < -5.0
		and _game._network_client_ember_passenger_surface_is_current()
		and _player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and source.get_audit().sequence > before.sequence and not _player.is_cabin_containment_active(),
		"ordinary Input walks unchanged crew body down airstair onto real %s terrain" % world_name)
	if _rime_arrival:
		# Clear the airstair for the second physical body, retaining real Input.
		await _walk(Vector3(-9.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z + (-2.0 if _role == "client" else 2.0)))
		_write(_role + ".rime_terrain", {})
		if not await _wait_file("host.rime_both_exterior_checked", 20.0):
			return false
		if _role == "client_b" and not await _wait_file("host.rime_first_reboard_checked", 20.0):
			return false
	else:
		_write("client.aurora_terrain", {})
		if not await _wait_file("host.aurora_terrain_checked", 20.0):
			return false
	var seat_id := StringName(departure.get("seat_id", &""))
	if not _rime_arrival:
		await _aurora_surface_refused_request(source, seat_id, {}, &"surface_return_requires_cabin_entry")
		await _aurora_surface_refused_request(source, seat_id, {"avatar_id": &"foreign_aurora_crew"}, &"surface_return_requires_retained_body")
		await _aurora_surface_refused_request(source, seat_id, {"action": &"swap"}, &"surface_passenger_requires_hatch_return")
	if _rime_arrival:
		await _walk(Vector3(-8.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	if not _rime_arrival:
		await _aurora_surface_refused_request(source, seat_id, {"frame_generation": 2}, &"stale_frame_generation")
		await _aurora_surface_refused_request(source, seat_id, {"client_tick": 0}, &"client_tick_too_old")
	before = source.get_audit()
	await _look(hatch.global_position)
	await _press(&"interact")
	var returned := await _until(func(): return _game._network_client_boarding_holds(_craft) \
		and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _player.is_cabin_containment_active(), 12.0)
	_check(returned, "ordinary %s hatch reclaims cabin berth on same walking body" % world_name)
	if not returned:
		print("AURORA_CREW_RETURN_DEBUG: ", _game.get_network_client_boarding_audit(), " answer=", _game.network_session.get_boarding_intent_result_replica(), " pose=", _craft.to_local(_player.global_position))
		return false
	_check(_player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and not _player.is_seated() and not _game._piloting and not bool(stale_predictor.call()),
		"%s reboard restores containment without body readmission, predictor reset or helm" % world_name)
	var pose := _player.global_transform
	_game.network_session.boarding_intent_result.emit(departure.duplicate(true))
	_check(_player.global_transform == pose and _game._network_client_ember_passenger_surface.is_empty()
		and _game._network_client_boarding_holds(_craft), "old accepted departure cannot reopen returned %s exterior prediction" % world_name)
	if _rime_arrival:
		await _walk(Vector3(-1.3 if _role == "client" else 1.3, 0.52, -5.8))
		_check(_player.is_on_floor() and _player.is_control_enabled() and _player.is_cabin_containment_active()
			and _player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
			and source.is_bound(), "reboarded Rime crew retains ordinary supported cabin walking and its original intent source")
		return _failures.is_empty()
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0), "returned %s crew can ordinarily reclaim actual passenger role chair" % world_name)
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not _game._transition_busy, 8.0), "returned %s crew can stand to supported cabin walking" % world_name)
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
	var world_name := "Rime" if _rime_arrival else "Aurora"
	_check(_game.network_session.send_boarding_intent(payload).accepted, "actual secure %s negative boarding request sends" % world_name)
	var answered := await _until(func(): return int(_game.network_session.get_boarding_intent_result_replica().get("sequence", -1)) == sequence, 4.0)
	var answer := _game.network_session.get_boarding_intent_result_replica()
	_check(answered and not bool(answer.get("accepted", true)) and answer.get("status") == expected_status
		and _game._network_client_ember_passenger_surface_is_current() and source.is_bound()
		and not _game._network_client_boarding_holds(_craft), "authenticated %s refuses %s without granting cabin or retiring body" % [world_name, expected_status])


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
