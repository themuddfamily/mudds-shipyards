extends SceneTree

const ROUTE := preload("res://tests/titan_transport_berth_test.gd").ROUTE
const OLD_TRANSFORMS := preload("res://tests/station_route_registry_integration_test.gd").EXPECTED_BERTH_TRANSFORMS
var _failures: Array[String] = []
var _frames := 0
var _supported := 0
var _clear := 0
var _game: GameFlow
var _ship: HeroShip
var _player: PlayerController
var _engine_edges: Array[Dictionary] = []
var _damaged_hull := -1.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var boot := (load("res://scenes/boot.tscn") as PackedScene).instantiate() as StartupLoader
	root.add_child(boot)
	_game = await boot.startup_completed as GameFlow
	await _wait_frames(3)
	_check(StartupLoader.is_title_menu_ready(_game), "ordinary Boot reaches Begin Shift")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _wait_frames(2)
	event = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _wait_frames(45)
	_player = _game.player
	_ship = _game.get_node("TitanMediumTransport") as HeroShip
	_ship.engine_state_changed.connect(_on_engine_edge)
	var identity := _player.get_instance_id()
	var world := _game.world
	var berth := world.get_berth_node(&"titan_home_berth") as ShipBerth
	var dock := berth.get_dock_transform()
	_check(_game.phase == GameFlow.Phase.APPROACH_SHIP and _player.is_control_enabled()
		and _player.global_position.distance_to(world.get_player_spawn().origin) < 0.25,
		"normal Begin Shift keeps actual Player at ordinary spawn")
	_check(_game.get_flyable_ships().size() == 10 and berth.get_occupant() == _ship
		and berth.get_reservation_owner() == _ship, "one real Titan joins fleet with own occupied lease")
	_check_panel_solids()
	var cargo_before := _game._runtime_settings_user_data_store.get_snapshot()
	_check(not _game.titan_cargo.request_transfer(_player, _game._titan_locker_panel, true, 1).accepted
		and not _game.titan_cargo.request_transfer(_ship, _game._titan_locker_panel, true, 1).accepted
		and _game.titan_cargo.snapshot().locker == 4 and _game.titan_cargo.snapshot().titan == 0
		and _game._runtime_settings_user_data_store.get_snapshot() == cargo_before,
		"remote station-range and wrong-actor transfer refuse with unchanged actual pair/store")
	var old_unchanged := true
	for id in OLD_TRANSFORMS:
		old_unchanged = old_unchanged and world.get_berth_transform(id).is_equal_approx(OLD_TRANSFORMS[id])
	_check(old_unchanged, "all original nine berth transforms remain unchanged")
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index], index):
			await _fail_exit("production station route failed")
			return
	var locker_panel := _game._titan_locker_panel
	_check(is_instance_valid(locker_panel) and "LOCKER 4 / 4" in locker_panel._label.text,
		"physical stern supply screen shows actual finite four-parcel stock")
	if not await _walk_to(_ship.to_global(Vector3(1.9, 0, 14.3)), 22):
		await _fail_exit("physical locker walk failed")
		return
	await _aim(locker_panel.global_position)
	_check(_game.station_interaction_candidate == locker_panel, "normal look selects actual supply panel")
	await _tap(&"interact")
	await _tap(&"interact")
	_check(_game.titan_cargo.snapshot().locker == 2 and _game.titan_cargo.snapshot().titan == 2
		and "LOCKER 2 / 4" in locker_panel._label.text,
		"two physical E loads show actual locker2/Titan2 after durable acknowledgments")
	_check(int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].locker) == 2
		and int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].titan) == 2
		and _game._runtime_settings_user_data_store.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT) == TitanCargoCustody.SAFE_CONTEXT,
		"same actual store commit contains loaded pair and safe on-foot recovery")
	# Retain a real-process seed for the independent cold Main probe, without
	# changing production persistence or shortening this complete ordinary loop.
	if OS.get_environment("TITAN_COLD_SEED_PATH") != "":
		var seed := FileAccess.open(OS.get_environment("TITAN_COLD_SEED_PATH"), FileAccess.WRITE)
		seed.store_string(JSON.stringify(_game._runtime_settings_user_data_store.get_snapshot()))
		seed.close()
		var envelope := FileAccess.open(OS.get_environment("TITAN_COLD_SEED_PATH") + ".envelope.json", FileAccess.WRITE)
		envelope.store_buffer(FileAccess.get_file_as_bytes("user://mudds_user_data.json"))
		envelope.close()
	if not _failures.is_empty():
		await _fail_exit("physical load contract failed")
		return
	if not await _walk_to(ROUTE[-1], 23):
		await _fail_exit("physical locker to hatch return failed")
		return
	var hatch := _ship.get_node("TitanOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	_check(_ship.is_canopy_open(), "normal E at physical stern control opens actual hatch/ramp")
	# Follow the supported apron around the moving leaves, up both leaves and
	# along the actual cabin aisle. No pose/velocity writes or board-method calls.
	var local_route := [Vector3(1.9, 0, 14.5), Vector3(0, 0, 14.5),
		Vector3(0, 0, 13), Vector3(0, 0.4, 10.5), Vector3(0, 0.8, 8),
		Vector3(0, 0.8, 6.5), Vector3(0, 0.8, 5.2), Vector3(0, 0.8, 1.8)]
	for point in local_route:
		if not await _walk_to(_ship.to_global(point), 30):
			await _fail_exit("physical stern/cabin walk failed")
			return
		if point == Vector3(0, 0.8, 5.2):
			await _aim(_game._titan_hold_panel.global_position)
			_check(_game.station_interaction_candidate == _game._titan_hold_panel
				and "LOCKER 2 / 4" in _game._titan_hold_panel._label.text
				and "TITAN 2 / 4" in _game._titan_hold_panel._label.text,
				"ordinary supported hold approach inspects actual visible loaded2/2 before passenger chairs")
	for seat_id: StringName in [&"passenger_port_01", &"passenger_starboard_01", &"passenger_port_01"]:
		if not await _passenger_round_trip(seat_id, identity):
			await _fail_exit("physical passenger contract failed")
			return
	if not await _post_chair_cargo_round_trip(identity):
		await _fail_exit("grounded passenger cargo/exit/reload contract failed")
		return
	if not await _walk_to(_ship.to_global(Vector3(0, 0.8, 1.8)), 32) \
			or not await _walk_to(_ship.to_global(Vector3(0, 0.8, -4.2)), 33):
		await _fail_exit("physical passenger to helm walk failed")
		return
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	_check(_game.active_ship == _ship and _game._piloting and not _game._transition_busy
		and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and area.get_reservation_token() == _player and _player.get_instance_id() == identity,
		"normal helm interaction completes actual pilot anchor/reservation with same Player")
	_check(not _ship.is_canopy_open(), "pilot boarding seals physical access")
	if not _failures.is_empty():
		await _fail_exit("boarding contract failed")
		return
	_check(_hull_leg_clear(Vector3.UP * 5), "whole real hull clears 5m departure leg")
	_engine_edges.clear()
	Input.action_press(&"move_forward")
	for frame in 500:
		var telemetry := _ship.get_telemetry()
		if not bool(telemetry.landed) and not _ship._departure_lift_active: break
		await _wait_frames(1)
	_release_inputs()
	var starting_ticks := -1
	var exact_timer := false
	if _engine_edges.size() == 2 and _engine_edges[0].state == HeroShip.ENGINE_STARTING \
			and _engine_edges[1].state == HeroShip.ENGINE_ONLINE:
		starting_ticks = int(_engine_edges[1].tick) - int(_engine_edges[0].tick)
		exact_timer = is_equal_approx(float(_engine_edges[0].remaining), 3.4) and is_zero_approx(float(_engine_edges[1].remaining))
	_check(exact_timer and starting_ticks >= 203 and starting_ticks <= 205,
		"normal thrust runs real 3.4s inherited engine clock: %d actual physics ticks, edges=%s" % [starting_ticks, _engine_edges])
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE,
		"completed timed startup reaches actual ONLINE propulsion")
	_check((_ship.global_position - dock.origin).dot(dock.basis.y) >= 4.99
		and berth.get_occupant() == null and berth.get_reservation_owner() == null,
		"actual five metre departure lift releases own lease")
	var target := dock * Vector3(0, 10, -31.2)
	_check(_hull_leg_clear(target - _ship.global_position), "whole real hull clears commanded flight leg")
	var arrived := false
	for frame in 1800:
		var offset := target - _ship.global_position
		var distance := offset.length()
		_release_inputs()
		if distance < 0.6 and _ship.velocity.length() <= 0.35:
			arrived = true
			break
		var local_direction := _ship.global_basis.inverse() * offset.normalized()
		var pitch_error := atan2(local_direction.y, -local_direction.z)
		if absf(pitch_error) > 0.003:
			Input.action_press(&"pitch_up" if pitch_error > 0 else &"pitch_down", clampf(absf(pitch_error) * 3, 0.08, 1))
		var desired_speed := minf(6.0, distance * 0.9)
		if _ship.velocity.length() > desired_speed + 0.1:
			Input.action_press(&"brake")
		elif distance > 0.45:
			Input.action_press(&"move_forward", clampf((desired_speed - _ship.velocity.length()) * 0.3 + 0.13, 0.12, 0.8))
		await _wait_frames(1)
		if frame % 180 == 0: print("TITAN_FLIGHT: frame=", frame, " local=", dock.affine_inverse() * _ship.global_position, " speed=", _ship.velocity.length(), " distance=", distance)
	_release_inputs()
	var local_flight := dock.affine_inverse() * _ship.global_position
	_check(arrived and _game.phase == GameFlow.Phase.FREE_FLIGHT
		and local_flight.distance_to(Vector3(0, 10, -30)) <= 2
		and -local_flight.z >= 30 and _ship.velocity.length() <= 0.5
		and not berth.contains_oriented_bounds(_ship.global_transform, _ship.get_landing_collision_report().local_bounds)
		and is_equal_approx(_ship.get_telemetry().hull, 220),
		"actual healthy FREE_FLIGHT reaches frozen home-local goal: %s speed=%s" % [local_flight, _ship.velocity.length()])
	if not _failures.is_empty():
		await _fail_exit("flight endpoint failed")
		return
	await _test_pilot_cannon()
	if not _failures.is_empty():
		await _fail_exit("ordinary cannon contract failed")
		return
	if "--lifecycle" in OS.get_cmdline_user_args():
		await _test_lifecycle(identity, berth, dock)
		if not _failures.is_empty():
			await _fail_exit("ordinary destruction/regeneration contract failed")
			return
		await _quit_normally()
		return
	await _test_incoming_damage_and_seat_cycle(identity)
	if not _failures.is_empty():
		await _fail_exit("ordinary damaged flight/seat contract failed")
		return
	var capture := _game._get_active_landing_assist_report()
	print("TITAN_CAPTURE_BEFORE_L: ", capture)
	_check(bool(capture.get("assist_capture_accepted", false))
		and StringName(capture.get("selected_berth_id", &"")) == &"titan_home_berth",
		"unchanged real capture gate accepts own berth before normal L")
	await _tap(&"landing_assist")
	for frame in 600:
		if _game.phase == GameFlow.Phase.SHUT_DOWN: break
		await _wait_frames(1)
	_check(_game.phase == GameFlow.Phase.SHUT_DOWN and berth.get_occupant() == _ship
		and berth.get_reservation_owner() == _ship and _ship.global_position.distance_to(dock.origin) <= 0.05
		and _ship.velocity.length() <= 0.05 and _ship.global_basis.is_equal_approx(dock.basis), "normal L restores exact own occupied dock lease")
	await _wait_frames(90)
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and _ship.global_position.distance_to(dock.origin) <= 0.05 and _ship.velocity.length() <= 0.05,
		"ninety neutral physics ticks retain stable OFFLINE dock")
	var model := _ship.get_component_damage()
	print("TITAN_HOME_SERVICE: ", _ship.get_telemetry(), " components=", model.get_component_report(), " effects=", _ship.get_damage_presentation().get_component_effect_ids())
	_check(model.get_worst_integrity() == 1.0 and _ship.get_operational_modifiers().fire_multiplier == 1.0
		and _ship.get_damage_presentation().get_active_component_effect_count() == 0
		and _ship.get_telemetry().hull == _damaged_hull
		and _game.titan_cargo.snapshot().locker == 2 and _game.titan_cargo.snapshot().titan == 2,
		"normal own-home landing/service restores components and cues, preserving damaged hull and inert2/2 parcels")
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	_check(not _player.is_seated() and _player.get_instance_id() == identity
		and not area.is_reserved() and not _game._piloting, "normal E returns same Player to landed cabin and releases helm")
	await _wait_frames(3)
	_print_helm_candidate("serviced_before_look")
	await _aim(_ship.get_pilot_seat_anchor().global_position)
	_print_helm_candidate("serviced_after_look")
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	print("TITAN_SERVICED_REBOARD: phase=", _game.phase, " piloting=", _game._piloting, " telemetry=", _ship.get_telemetry())
	_check(_game._piloting and _player.get_instance_id() == identity
		and _player.is_seated_at(_ship.get_pilot_seat_anchor()) and area.get_reservation_token() == _player
		and _ship.get_operational_modifiers().fire_multiplier == 1.0
		and _ship.get_telemetry().hull == _damaged_hull,
		"ordinary serviced reboard regains same usable helm without hull healing")
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	_check(not _player.is_seated() and not _game._piloting and not area.is_reserved()
		and _ship.get_telemetry().hull == _damaged_hull,
		"ordinary second pilot exit preserves damaged hull and releases serviced helm")
	if not await _walk_to(_ship.to_global(Vector3(0, 0.8, 5.2)), 39):
		await _fail_exit("physical hold return walk failed")
		return
	await _aim(_game._titan_hold_panel.global_position)
	_check(_game.station_interaction_candidate == _game._titan_hold_panel, "normal look selects actual hold return panel")
	await _tap(&"interact")
	await _tap(&"interact")
	_check(_game.titan_cargo.snapshot().locker == 4 and _game.titan_cargo.snapshot().titan == 0
		and "LOCKER 4 / 4" in _game._titan_hold_panel._label.text
		and int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].locker) == 4
		and int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].titan) == 0,
		"two physical E returns durably settle locker4/Titan0 before ordinary exit")
	for point in [Vector3(0, 0.8, 6.5), Vector3(1.4, 0.8, 7.1)]:
		if not await _walk_to(_ship.to_global(point), 40):
			await _fail_exit("return cabin walk failed")
			return
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	_check(_ship.is_canopy_open(), "normal cabin hatch control opens supported exit")
	for point in [Vector3(0, 0.8, 7.1), Vector3(0, 0.8, 8), Vector3(0, 0.4, 10.5),
		Vector3(0, 0, 13), Vector3(0, 0, 14.5)]:
		if not await _walk_to(_ship.to_global(point), 50):
			await _fail_exit("physical ramp exit failed")
			return
	_check(_frames > 1000 and _supported == _frames and _clear == _frames,
		"all %d actual walking samples supported/capsule-clear (%d/%d)" % [_frames, _supported, _clear])
	_check(_player.get_instance_id() == identity and _player.is_on_floor()
		and _ship.to_local(_player.global_position).distance_to(Vector3(0, 0, 14.5)) < 0.08,
		"same Player walks at least 1m exterior to supported real exit endpoint")
	if not _failures.is_empty():
		await _fail_exit("final walking contract failed")
		return
	await _quit_normally()


func _quit_normally() -> void:
	_release_inputs()
	await _key(KEY_ESCAPE)
	var exit_button := _game.hud.find_child("ExitButton", true, false) as Control
	for frame in 160:
		if root.gui_get_focus_owner() == exit_button: break
		await _key(KEY_TAB)
	_check(is_instance_valid(exit_button) and root.gui_get_focus_owner() == exit_button, "normal pause Tab reaches Exit to desktop")
	if not _failures.is_empty():
		await _fail_exit("normal Quit focus failed")
		return
	print("TITAN_USER_DATA_DIR: ", OS.get_user_data_dir())
	print("GAME_FLOW_TITAN_INTEGRATION_TEST_PASS")
	await _key(KEY_ENTER)
	for frame in 120: await process_frame
	await _fail_exit("normal Main Quit did not terminate OS process")


func _test_lifecycle(identity: int, berth: ShipBerth, dock: Transform3D) -> void:
	var cargo := _game.titan_cargo
	var before := cargo.snapshot()
	var raw_locker := cargo.locker_handle.duplicate(true)
	var raw_ship := cargo.ship_handle.duplicate(true)
	var store_before := _game._runtime_settings_user_data_store.get_snapshot()
	var target := _game.get_node("RangeOpponent") as RangeOpponent
	var authority := _game.get_combat_authority()
	target.set_physics_process(false)
	_check(target.activate(Transform3D(_ship.global_basis, _ship.to_global(Vector3(-20, 2.15, 4)))).accepted,
		"registered opponent stages terminal incoming production rays after complete physical departure/cannon")
	await _wait_frames(2)
	var weapon := load("res://assets/weapons/range_defence_pulse.tres") as WeaponDefinition
	var cadence_ticks := ceili(60.0 / weapon.cadence_shots_per_second)
	var hits := 0
	for index in 20:
		if index > 0: await _wait_frames(cadence_ticks)
		for vent_tick in 240:
			if not authority.is_weapon_heat_locked(target, GameFlow.OPPONENT_WEAPON_ID): break
			await _wait_frames(1)
		var aim := _ship.to_global(Vector3(-5.4, 2.15, 4))
		var result := authority.submit_hitscan(target, GameFlow.OPPONENT_WEAPON_ID,
			target.global_position, (aim - target.global_position).normalized())
		print("TITAN_LIFECYCLE_INCOMING: index=", index, " result=", result)
		_check(bool(result.get("damaged", false)) and result.get("target_entity") == _ship
			and is_equal_approx(float(result.get("applied_damage", 0)), 11.0),
			"real incoming11 damage respects authored cadence and actual heat vent")
		if not _failures.is_empty(): return
		hits += 1
	var dead_before := _ship.get_telemetry()
	var cargo_before_reset := cargo.snapshot()
	var berth_before := berth.get_audit_report()
	var pending_before := _game._regeneration_pending.duplicate(true)
	var early_reset := _ship.reset_for_reuse(dock)
	_check(not early_reset.accepted and early_reset.reason == &"titan_lifecycle_changed"
		and _ship.get_telemetry() == dead_before and cargo.snapshot() == cargo_before_reset
		and berth.get_audit_report() == berth_before and _game._regeneration_pending == pending_before
		and Time.get_ticks_msec() < int(pending_before[_ship.get_instance_id()].ready_at_msec),
		"public home reset during pending-but-not-due recovery refuses before hull, lease, schedule or custody mutation")
	_check(hits == 20 and _ship.is_destroyed() and not _game._piloting and not _ship.is_piloted()
		and not _player.is_seated() and _player.get_instance_id() == identity
		and _game._regeneration_pending.has(_ship.get_instance_id())
		and not (_ship.get_node("ShipBoardingArea") as ShipBoardingArea).is_reserved()
		and not _ship.get_camera().current,
		"twenty actual opponent hits retire actual pilot/helm/camera and queue ordinary regeneration")
	var sealed := cargo.snapshot()
	# Invoke every refusal independently; a persistence mismatch must not skip
	# the service or direct-authority regression attempts.
	var dead_service := cargo.request_transfer(_player, _game._titan_locker_panel, true, 1)
	var dead_old := _game.cargo_transfer_authority.transfer(&"main_dead_old", raw_locker, raw_ship, TitanCargoCustody.ITEM, 1)
	var dead_current := _game.cargo_transfer_authority.transfer(&"main_dead_sealed", cargo.locker_handle, cargo.ship_handle, TitanCargoCustody.ITEM, 1)
	var store_after := _game._runtime_settings_user_data_store.get_snapshot()
	# The existing active race deliberately fails and saves on ship loss through
	# _fail_active_activity/_on_cinder_session_presentation_changed. Permit only
	# its seven terminal state/reason/clock fields; preserve every other field.
	# JSON canonicalization matches the actual store round trip (including floats).
	var expected_store: Dictionary = JSON.parse_string(JSON.stringify(store_before))
	var canonical_after: Dictionary = JSON.parse_string(JSON.stringify(store_after))
	var live_race := _game.cinder_race_session.capture_persistence_state()
	var expected_activity: Dictionary = expected_store.cinder_timed_race_session.activities[0]
	expected_activity.state = TimedCheckpointRace.State.FAILED
	expected_activity.progress.state = TimedCheckpointRace.State.FAILED
	expected_activity.progress.session_state.activity_state.state = CheckpointRouteActivity.State.FAILED
	expected_activity.progress.session_state.activity_state.failure_reason = "ship_destroyed"
	expected_activity.progress.session_state.race_state.state = TimedCheckpointRace.State.FAILED
	expected_activity.progress.session_state.race_state.failure_reason = "ship_destroyed"
	expected_activity.progress.session_state.race_state.race_elapsed_seconds = live_race.race_state.race_elapsed_seconds
	expected_store = JSON.parse_string(JSON.stringify(expected_store))
	var changed_keys: Array[String] = []
	for key: String in store_before:
		if store_before[key] != store_after.get(key): changed_keys.append(key)
	for key: String in store_after:
		if not store_before.has(key): changed_keys.append(key)
	print("TITAN_DEATH_STORE: ", JSON.stringify({"before": store_before, "after": store_after, "changed_keys": changed_keys,
		"dead_service": dead_service, "dead_old": dead_old, "dead_current": dead_current,
		"sealed": sealed, "detached": not _game.cargo_transfer_authority.get_manifest_snapshot(cargo.ship_handle).attached,
		"expected_normal_death_store": expected_store}))
	_check(not sealed.available and sealed.locker == 2 and sealed.titan == 2
		and not _game.cargo_transfer_authority.get_manifest_snapshot(cargo.ship_handle).attached
		and store_after[TitanCargoCustody.SLOT] == store_before[TitanCargoCustody.SLOT]
		and store_after[TitanCargoCustody.MARKER] == true and store_before[TitanCargoCustody.MARKER] == true
		and live_race.race_state.failure_reason == "ship_destroyed" and canonical_after == expected_store
		and not dead_service.accepted and not dead_old.accepted and not dead_current.accepted,
		"actual dead Main preserves exact2/2 and all store fields except normal race failure; all dead endpoints refuse")
	var seed_path := OS.get_environment("TITAN_LIFECYCLE_SEED_PATH")
	if seed_path != "":
		var payload := FileAccess.open(seed_path, FileAccess.WRITE)
		payload.store_string(JSON.stringify(_game._runtime_settings_user_data_store.get_snapshot()))
		payload.close()
		var envelope := FileAccess.open(seed_path + ".envelope.json", FileAccess.WRITE)
		envelope.store_buffer(FileAccess.get_file_as_bytes("user://mudds_user_data.json"))
		envelope.close()
	await _wait_frames(8)
	_check(_player.is_on_floor() and _player.is_control_enabled()
		and _player.global_position.distance_to(_game.world.get_player_spawn().origin) < 0.25
		and (_player.get_node("%PlayerCamera") as Camera3D).current
		and not _player.get_cabin_containment_report().active,
		"same Player actually recovers supported at normal station spawn with walking camera")
	for frame in 600:
		if not _ship.is_destroyed(): break
		await _wait_frames(1)
	var count := 0
	for candidate in _game.get_flyable_ships():
		if candidate.get_ship_id() == &"titan_provisional": count += 1
	var restored := cargo.snapshot()
	_check(count == 1 and not _ship.is_destroyed() and _ship.get_telemetry().hull == 220
		and _ship.get_component_damage().get_worst_integrity() == 1.0
		and berth.get_occupant() == _ship and berth.get_reservation_owner() == _ship
		and _ship.global_transform.is_equal_approx(dock) and _ship.velocity == Vector3.ZERO
		and not _game._regeneration_pending.has(_ship.get_instance_id())
		and restored.available and restored.locker == 2 and restored.titan == 2
		and restored.ship_handle != before.ship_handle and restored.ship_handle != sealed.ship_handle,
		"unchanged normal timer restores exactly one nominal Titan at exact own occupied berth with fresh retained2/2 custody")
	_check(not cargo.request_transfer(_player, _game._titan_locker_panel, true, 1, &"old_live_pair", before.locker_handle, before.ship_handle).accepted
		and not _game.cargo_transfer_authority.transfer(&"main_old_after_reset", raw_locker, raw_ship, TitanCargoCustody.ITEM, 1).accepted
		and cargo.snapshot().locker == 2 and cargo.snapshot().titan == 2,
		"old service and authority handles remain refused after normal regeneration")
	if not _failures.is_empty(): return
	for index in ROUTE.size():
		if not await _walk_to(ROUTE[index], 80 + index):
			_check(false, "normal recovery station return route")
			return
	var hatch := _ship.get_node("TitanOriginalShell/CabinHatchInteraction") as ShipCabinHatch
	await _aim(hatch.global_position)
	await _tap(&"interact")
	await _wait_frames(30)
	_check(_ship.is_canopy_open(), "normal recovered stern control opens regenerated physical hatch")
	for point in [Vector3(0, 0, 14.5), Vector3(0, 0, 13), Vector3(0, 0.4, 10.5),
			Vector3(0, 0.8, 8), Vector3(0, 0.8, 6.5), Vector3(0, 0.8, -4.2)]:
		if not await _walk_to(_ship.to_global(point), 110):
			_check(false, "normal recovered physical cabin walk")
			return
	await _aim(_ship.get_pilot_seat_anchor().global_position)
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	_check(_game._piloting and _ship.is_piloted() and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and (_ship.get_node("ShipBoardingArea") as ShipBoardingArea).get_reservation_token() == _player,
		"same recovered Player physically reboards regenerated usable helm")
	_engine_edges.clear()
	Input.action_press(&"brake")
	for frame in 300:
		if StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE: break
		await _wait_frames(1)
	_release_inputs()
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE
		and _engine_edges.size() == 2
		and int(_engine_edges[1].tick) - int(_engine_edges[0].tick) >= 203
		and int(_engine_edges[1].tick) - int(_engine_edges[0].tick) <= 205
		and berth.get_occupant() == _ship and cargo.snapshot().locker == 2 and cargo.snapshot().titan == 2,
		"regenerated actual helm completes real3.4s start while preserving own berth and same2/2")
	await _wait_frames(180)
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	_check(not _game._piloting and not _player.is_seated() and _player.get_instance_id() == identity
		and StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and cargo.snapshot().locker == 2 and cargo.snapshot().titan == 2
		and _frames > 1000 and _frames == _supported and _frames == _clear,
		"ordinary neutral shutdown and physical cabin stand finish supported with conserved2/2 before UI Quit")
	target.deactivate()
	target.set_physics_process(true)

func _on_engine_edge(state: StringName) -> void:
	_engine_edges.append({"state": state, "tick": Engine.get_physics_frames(), "remaining": _ship.get("_engine_timer")})

func _hull_leg_clear(motion: Vector3) -> bool:
	var support := _game.world.get_node("TitanTransportBerth/BerthDeck") as StaticBody3D
	for node in _ship.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision.disabled or not collision.get_parent() is PhysicsBody3D: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = collision.global_transform
		query.motion = motion
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		query.margin = 0
		query.exclude = [_ship.get_rid(), support.get_rid()]
		var result := _ship.get_world_3d().direct_space_state.cast_motion(query)
		if result[0] < 1 or result[1] < 1:
			print("TITAN_BLOCKED_LEG: ", collision.name, " motion=", motion, " fractions=", result)
			return false
	return true

func _aim(target: Vector3) -> void:
	# Right-stick events work through the real on-foot look sampler even on a
	# headless display, where mouse capture has no operating-system surface.
	for frame in 180:
		var direction := (target - _player.get_interaction_origin()).slide(Vector3.UP).normalized()
		var forward := _player.get_interaction_direction().slide(Vector3.UP).normalized()
		var angle := forward.signed_angle_to(direction, Vector3.UP)
		if absf(angle) < 0.03: break
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_RIGHT_X
		motion.axis_value = -signf(angle) * (0.4 if absf(angle) < 0.25 else 1.0)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await _wait_frames(1)
	var release := InputEventJoypadMotion.new()
	release.axis = JOY_AXIS_RIGHT_X
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _wait_frames(2)
	print("TITAN_AIM: direction=", _player.get_interaction_direction(), " target=", target, " origin=", _player.get_interaction_origin(), " selected=", _game.station_interaction_candidate)

func _walk_to(target: Vector3, index: int) -> bool:
	var reached := false
	for frame in 900:
		var offset := (target - _player.global_position).slide(Vector3.UP)
		if absf(offset.x) < 0.02: offset.x = 0
		if absf(offset.z) < 0.02: offset.z = 0
		if offset.length() < 0.035:
			reached = true
			break
		var direction := (_player.get_node("%CameraYaw") as Node3D).global_basis.inverse() * offset.normalized()
		_release_inputs()
		var strength := 0.4 if offset.length() < 0.8 else 1.0
		Input.action_press(&"move_right" if direction.x > 0 else &"move_left", absf(direction.x) * strength)
		Input.action_press(&"move_back" if direction.z > 0 else &"move_forward", absf(direction.z) * strength)
		await _wait_frames(1)
		_observe()
	_release_inputs()
	for frame in 12:
		await _wait_frames(1)
		_observe()
	print("TITAN_WALK: leg=", index, " target=", target, " actual=", _player.global_position, " reached=", reached)
	return reached

func _observe() -> void:
	_frames += 1
	if _player.is_on_floor(): _supported += 1
	var collision := _player.get_node("PlayerCollision") as CollisionShape3D
	var capsule := collision.shape.duplicate() as CapsuleShape3D
	capsule.radius -= 0.005
	capsule.height -= 0.01
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = collision.global_transform
	query.margin = 0
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
	query.exclude = [_player.get_rid()]
	var hits := _player.get_world_3d().direct_space_state.intersect_shape(query, 8)
	if hits.is_empty(): _clear += 1
	elif _clear == _frames - 1: print("TITAN_CAPSULE_FIRST_HIT: pose=", _player.global_position, " hits=", hits)

func _tap(action: StringName) -> void:
	if action == &"interact" or action == &"landing_assist":
		await _key(KEY_E if action == &"interact" else KEY_L)
		return
	Input.action_press(action)
	await _wait_frames(2)
	Input.action_release(action)
	await _wait_frames(2)

func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await physics_frame
		await process_frame

func _release_inputs() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"pitch_up", &"pitch_down", &"brake", &"sprint_boost", &"interact", &"landing_assist", &"fire"]:
		Input.action_release(action)

func _wait_frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition: _failures.append(message)

func _fail_exit(message: String) -> void:
	_check(false, message)
	_release_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game.queue_free()
	await _wait_frames(3)
	quit(1)


func _passenger_round_trip(seat_id: StringName, identity: int) -> bool:
	var anchor := _ship.get_node("TitanOriginalShell/" + String(seat_id)) as Marker3D
	var seat := anchor.get_node("SoloPassengerSeatInteraction") as ShipCrewSeat
	var entry := seat.get_entry_transform()
	if not await _walk_to(entry.origin, 31):
		return false
	await _aim(seat.global_position)
	_check(_game.station_interaction_candidate == seat, "normal look discovers exact " + String(seat_id))
	await _tap(&"interact")
	for frame in 180:
		if _game._station_seated and not _game._transition_busy: break
		await _wait_frames(1)
	var authority: CrewSeatRoleAuthority = _ship.call(&"get_crew_role_authority")
	var assignment := authority.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID) if authority != null else {}
	var metadata := _player.get_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
	_check(_game._solo_crew_claim_is_current() and _player.is_seated_at(anchor)
		and _player.get_instance_id() == identity and assignment.get("seat_id") == seat_id
		and assignment.get("role") == &"passenger" and metadata.get("seat_id") == seat_id
		and metadata.get("authority") == authority and metadata.get("craft") == _ship
		and not _game._piloting and not _ship.is_piloted(), "actual Player and authority occupy exact " + String(seat_id))
	var cargo_before := _game._runtime_settings_user_data_store.get_snapshot()
	_check(not _game.titan_cargo.request_transfer(_player, _game._titan_hold_panel, false, 1).accepted
		and _game.titan_cargo.snapshot().locker == 2 and _game.titan_cargo.snapshot().titan == 2
		and _game._runtime_settings_user_data_store.get_snapshot() == cargo_before,
		"occupied passenger cannot transfer or mutate durable cargo")
	var before := _ship.global_transform
	Input.action_press(&"move_forward")
	Input.action_press(&"fire")
	await _wait_frames(12)
	Input.action_release(&"fire")
	_release_inputs()
	_check(_ship.global_transform.is_equal_approx(before) and _ship.velocity.length() < 0.001
		and StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and not bool(authority.authorize_action(1, GameFlow.SOLO_CREW_AVATAR_ID, CrewSeatRoleAuthority.CAPABILITY_SHIP_COMMAND).get("accepted", false))
		and not bool(authority.authorize_action(1, GameFlow.SOLO_CREW_AVATAR_ID, CrewSeatRoleAuthority.CAPABILITY_WEAPON_CONTROL).get("accepted", false)),
		"passenger flight/fire input has no propulsion or specialist authority")
	await _tap(&"interact")
	for frame in 180:
		if not _game._station_seated and not _game._transition_busy: break
		await _wait_frames(1)
	await _wait_frames(5)
	_check(not _player.is_seated() and _player.is_on_floor() and _player.get_instance_id() == identity
		and _player.global_position.distance_to(entry.origin) < 0.05
		and authority.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty()
		and not _player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META)
		and _ship.call(&"get_crew_role_authority") == null and not _game._piloting
		and _game.phase in [GameFlow.Phase.APPROACH_SHIP, GameFlow.Phase.COMPLETE]
		and _game._boarding_area == null and not (_ship.get_node("ShipBoardingArea") as ShipBoardingArea).is_reserved()
		and not bool(_player.get_cabin_containment_report().get("active", false)),
		"normal E stands supported and empties exact " + String(seat_id) + " claim")
	return _failures.is_empty()


func _check_panel_solids() -> void:
	var capsule := (_player.get_node("PlayerCollision") as CollisionShape3D).shape as CapsuleShape3D
	for panel: TitanCargoPanel in [_game._titan_hold_panel, _game._titan_locker_panel]:
		var collision := panel._solid_collision
		var mesh_size := Vector3(0.12, 0.52, 0.72) if not panel.loading else Vector3(0.72, 0.52, 0.12)
		_check(is_instance_valid(collision) and collision.shape is BoxShape3D
			and (collision.shape as BoxShape3D).size.is_equal_approx(mesh_size)
			and collision.global_position.is_equal_approx(panel.global_position),
			"physical screen collision exactly matches " + String(panel.name))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, panel.global_position + Vector3.UP * (0.8 if panel.loading else 0.7))
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.SHIP
		query.margin = 0
		query.exclude = [_player.get_rid()]
		var hits := _ship.get_world_3d().direct_space_state.intersect_shape(query, 16)
		var hits_screen := false
		for hit in hits:
			if hit.get("collider") == collision.get_parent(): hits_screen = true
		_check(hits_screen, "actual Player capsule overlaps solid " + String(panel.name))
		var normal := panel.global_basis.z if panel.loading else panel.global_basis.x
		query.transform.origin += normal * 1.2
		query.motion = -normal * 1.2
		var motion := _ship.get_world_3d().direct_space_state.cast_motion(query)
		_check(motion[0] > 0.25 and motion[0] < 1.0,
			"actual capsule sweep cannot phase through " + String(panel.name) + ": " + str(motion))
	var locker := _game.titan_cargo.locker
	var pedestal := locker.get_node("LockerPedestalBody") as StaticBody3D
	var pedestal_shape := pedestal.get_child(0) as CollisionShape3D
	_check((pedestal_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(0.8, 1, 0.6))
		and pedestal_shape.position.is_equal_approx(Vector3(0, 0.5, 0)),
		"supported supply pedestal has matched real solid furniture")


func _post_chair_cargo_round_trip(identity: int) -> bool:
	if not await _walk_to(_ship.to_global(Vector3(0, 0.8, 5.2)), 34): return false
	await _aim(_game._titan_hold_panel.global_position)
	_check(_game.station_interaction_candidate == _game._titan_hold_panel,
		"grounded former passenger normally selects physical hold panel")
	await _tap(&"interact")
	await _tap(&"interact")
	_check(_game.titan_cargo.snapshot().locker == 4 and _game.titan_cargo.snapshot().titan == 0
		and int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].locker) == 4,
		"normal E after passenger stand durably returns both parcels4/0")
	_check(_ship.is_canopy_open() and not bool(_player.get_cabin_containment_report().get("active", false)),
		"grounded passenger retains actual open access and free supported walking")
	for point in [Vector3(0, 0.8, 6.5), Vector3(0, 0.8, 8), Vector3(0, 0.4, 10.5),
		Vector3(0, 0, 13), Vector3(0, 0, 14.3), Vector3(1.9, 0, 14.3)]:
		if not await _walk_to(_ship.to_global(point), 35): return false
	_check(_player.get_instance_id() == identity and _player.is_on_floor()
		and not (_ship.get_node("ShipBoardingArea") as ShipBoardingArea).is_reserved(),
		"same former passenger physically exits open ramp to supported supply stand")
	await _aim(_game._titan_locker_panel.global_position)
	_check(_game.station_interaction_candidate == _game._titan_locker_panel,
		"former passenger normally selects physical locker panel outside")
	await _tap(&"interact")
	await _tap(&"interact")
	_check(_game.titan_cargo.snapshot().locker == 2 and _game.titan_cargo.snapshot().titan == 2
		and int(_game._runtime_settings_user_data_store.get_snapshot()[TitanCargoCustody.SLOT].titan) == 2,
		"normal exterior E reload durably restores2/2 before original full flight")
	for point in [Vector3(0, 0, 14.3), Vector3(0, 0, 13), Vector3(0, 0.4, 10.5),
		Vector3(0, 0.8, 8), Vector3(0, 0.8, 6.5), Vector3(0, 0.8, 1.8)]:
		if not await _walk_to(_ship.to_global(point), 36): return false
	return _failures.is_empty()


## Deterministically stage the existing production opponent at the actual pilot
## reticle. This proves normal FIRE and lifecycle damage, not encounter discovery.
## Titan pose, velocity, lease, clocks and actor are never assigned by this case.
func _test_pilot_cannon() -> void:
	var authority := _game.get_combat_authority()
	var resolver := _game.get_combat_resolver()
	var target := _game.get_node("RangeOpponent") as RangeOpponent
	var camera := _ship.get_camera()
	var aim := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size * 0.5).normalized()
	var target_position := camera.global_position + aim * 60.0
	target.set_physics_process(false)
	_check(bool(target.activate(Transform3D(_ship.global_basis, target_position)).get("accepted", false)),
		"staged existing production opponent activates at ordinary pilot reticle")
	await _wait_frames(2)
	var adapter := target.get_node("AuthoritativeDamageable") as LifecycleDamageableAdapter
	var profile := authority.get_weapon_profile(_ship, GameFlow.JOVIAN_COMBAT_WEAPON_ID)
	_check(authority.get_source_id(_ship) == 1110 and profile == {"range": 650.0, "damage": 70.0, "origin_tolerance": 10.0}
		and adapter.get_target_entity() == target and is_equal_approx(_ship.weapon_cooldown, 0.62),
		"Titan1110 owns unchanged650m/70 cannon and real production lifecycle target")
	var shots: Array[Dictionary] = []
	var emitted := func(origin: Vector3, direction: Vector3) -> void:
		shots.append({"tick": Engine.get_physics_frames(), "origin": origin, "direction": direction,
			"telemetry": _ship.get_telemetry(), "readout": _ship.call("_get_cockpit_system_readout")})
	_ship.projectile_fired.connect(emitted)
	var damages: Array[float] = []
	var damaged := func(current: float, _maximum: float) -> void: damages.append(current)
	target.health_changed.connect(damaged)
	var health := target.get_health()
	Input.action_press(&"fire")
	await _wait_frames(10)
	Input.action_release(&"fire")
	var hit := _game.get_last_player_shot_result()
	var request := hit.get("request") as ShotRequest
	var telemetry := _ship.get_telemetry()
	_check(shots.size() == 1 and damages.size() == 1 and is_equal_approx(target.get_health(), health - 70)
		and bool(hit.get("damaged", false)) and hit.get("target_entity") == target
		and request != null and request.source_entity == _ship and request.source_id == 1110
		and request.weapon_id == GameFlow.JOVIAN_COMBAT_WEAPON_ID
		and _ship.to_local(shots[0].origin).distance_to(Vector3(0, 1.1, -8.9)) < 0.01,
		"normal held FIRE emits exactly one centre shot and one70 damage event with Titan ownership")
	var shot_telemetry := shots[0].telemetry as Dictionary if not shots.is_empty() else {}
	var shot_readout := shots[0].readout as Dictionary if not shots.is_empty() else {}
	print("TITAN_CANNON_TELEMETRY: shot=", shot_telemetry, " readout=", shot_readout,
		" delayed=", telemetry, " delayed_physics_ticks=", Engine.get_physics_frames() - int(shots[0].tick) if not shots.is_empty() else -1)
	_check(is_equal_approx(float(shot_telemetry.get("weapon_heat", -1)), HeroShip.WEAPON_HEAT_PER_SHOT)
		and is_equal_approx(float(shot_telemetry.get("weapon_cooldown_remaining", -1)), 0.62)
		and shot_telemetry.get("weapon_status") == &"cooldown" and not bool(shot_telemetry.get("weapon_ready", true))
		and "WPN CYCLING" in str(shot_readout.get("text", "")),
		"actual normal-input shot exposes inherited heat and cycling telemetry")
	var replay := resolver.resolve_hitscan(request) if request != null else {}
	_check(replay.get("status") == &"duplicate_sequence" and is_equal_approx(target.get_health(), health - 70),
		"replayed Titan receipt cannot apply a second damage event")
	target.deactivate()
	# Keep holding through the real cooldown: the next admitted shot must wait
	# at least38 physics ticks (0.62s at60Hz), and now deliberately misses.
	Input.action_press(&"fire")
	for frame in 45:
		if shots.size() == 2: break
		await _wait_frames(1)
	Input.action_release(&"fire")
	var miss := _game.get_last_player_shot_result()
	_check(shots.size() == 2 and int(shots[1].tick) - int(shots[0].tick) >= 38
		and int(shots[1].tick) - int(shots[0].tick) <= 39
		and bool(miss.get("accepted", false)) and not bool(miss.get("damaged", true))
		and damages.size() == 1 and is_equal_approx(target.get_health(), health - 70),
		"held FIRE respects actual0.62s cadence then deliberate clear-space miss adds no target damage")
	_ship.projectile_fired.disconnect(emitted)
	target.health_changed.disconnect(damaged)
	await _test_cannon_authority(authority, resolver, target)
	target.deactivate()
	target.set_physics_process(true)
	_check(is_equal_approx(_ship.get_telemetry().hull, 220) and _game.active_ship == _ship
		and _game._piloting and _game.phase == GameFlow.Phase.FREE_FLIGHT,
		"cannon checks preserve healthy actual Titan pilot/free-flight route")


func _test_incoming_damage_and_seat_cycle(identity: int) -> void:
	var target := _game.get_node("RangeOpponent") as RangeOpponent
	var authority := _game.get_combat_authority()
	target.set_physics_process(false)
	var origin := _ship.to_global(Vector3(-20, 2.15, 4))
	_check(bool(target.activate(Transform3D(_ship.global_basis, origin)).get("accepted", false)),
		"existing production opponent stages a real incoming port-engine ray")
	await _wait_frames(2)
	for index in 2:
		var aim := _ship.to_global(Vector3(-5.4, 2.15, 4))
		var result := authority.submit_hitscan(target, GameFlow.OPPONENT_WEAPON_ID,
			target.global_position, (aim - target.global_position).normalized())
		print("TITAN_INCOMING_RAY: index=", index, " result=", result)
		_check(bool(result.get("damaged", false)) and result.get("target_entity") == _ship,
			"registered production opponent's real resolver ray damages Titan once")
	target.deactivate()
	target.set_physics_process(true)
	await _wait_frames(2)
	var model := _ship.get_component_damage()
	var damaged := model.get_ledger_snapshot()
	_damaged_hull = float(_ship.get_telemetry().hull)
	print("TITAN_INCOMING_STATE: hull=", _damaged_hull, " ledger=", damaged,
		" telemetry=", _ship.get_telemetry(), " effects=", _ship.get_damage_presentation().get_component_effect_ids())
	_check(is_equal_approx(_damaged_hull, 198.0)
		and model.get_component_state(&"port_wing") == ShipComponentDamage.ComponentState.IMPAIRED
		and is_equal_approx(_ship.get_operational_modifiers().fire_multiplier, 0.62)
		and _ship.get_damage_presentation().get_component_effect_ids() == [&"port_wing"],
		"two actual11-damage port-engine hits cause localized .62 fire impairment and exact22 hull loss")
	_release_inputs()
	for frame in 180:
		if StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE: break
		await _wait_frames(1)
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE
		and not bool(_ship.get_telemetry().landed) and model.get_ledger_snapshot() == damaged
		and _ship.get_telemetry().hull == _damaged_hull,
		"unchanged normal idle timer reaches actual airborne OFFLINE without repairing damage")
	await _tap(&"interact")
	for frame in 180:
		if not _game._transition_busy and not _player.is_seated(): break
		await _wait_frames(1)
	print("TITAN_DAMAGED_STAND: phase=", _game.phase, " piloting=", _game._piloting,
		" player=", _player.global_position, " telemetry=", _ship.get_telemetry())
	_check(_game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not _game._piloting
		and not _player.is_seated() and _player.get_instance_id() == identity
		and model.get_ledger_snapshot() == damaged and _ship.get_telemetry().hull == _damaged_hull,
		"ordinary airborne E leaves actual helm into carried cabin without healing")
	await _wait_frames(3)
	_print_helm_candidate("damaged_before_look")
	await _aim(_ship.get_pilot_seat_anchor().global_position)
	_print_helm_candidate("damaged_after_look")
	await _tap(&"interact")
	for frame in 240:
		if _game._piloting and not _game._transition_busy: break
		await _wait_frames(1)
	print("TITAN_DAMAGED_REBOARD: phase=", _game.phase, " piloting=", _game._piloting,
		" telemetry=", _ship.get_telemetry())
	_check(_game._piloting and _player.is_seated_at(_ship.get_pilot_seat_anchor())
		and _player.get_instance_id() == identity
		and model.get_ledger_snapshot() == damaged and _ship.get_telemetry().hull == _damaged_hull
		and _game.titan_cargo.snapshot().locker == 2 and _game.titan_cargo.snapshot().titan == 2,
		"ordinary airborne reboard retains same Player/current helm, component damage, damaged hull and inert parcels")
	if not _failures.is_empty():
		return
	# Normal brake demand restarts the unchanged 3.4s engine clock in place;
	# landing still requires the real ONLINE owner after this cabin visit.
	Input.action_press(&"brake")
	for frame in 300:
		if StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE: break
		await _wait_frames(1)
	Input.action_release(&"brake")
	_check(StringName(_ship.get_telemetry().engine_state) == HeroShip.ENGINE_ONLINE
		and model.get_ledger_snapshot() == damaged and _ship.get_telemetry().hull == _damaged_hull,
		"ordinary brake demand completes unchanged restart without repairing airborne damage before own-home L")


func _print_helm_candidate(label: String) -> void:
	var area := _ship.get_node("ShipBoardingArea") as ShipBoardingArea
	var frame := _ship.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	print("TITAN_HELM_CANDIDATE: ", {"label": label, "player_local": _ship.to_local(_player.global_position),
		"inside": frame.contains_world_position(_player.global_position), "carried": frame.is_occupant_registered(_player),
		"near_ship": _game._near_ship, "boarding_candidate": _game.boarding_candidate,
		"station_candidate": _game.station_interaction_candidate, "area_current": _game._boarding_area == area,
		"area_available": area.is_available_for(_player), "reservation_owner": area.get_reservation_token(),
		"player": _player, "ship_boardable": _ship.is_boardable(), "origin": _player.get_interaction_origin(),
		"direction": _player.get_interaction_direction(), "containment": _player.get_cabin_containment_report()})


func _test_cannon_authority(authority: LiveCombatAuthority, resolver: CombatResolver, target: RangeOpponent) -> void:
	var origin := (_ship.get("_muzzle_left") as Marker3D).global_position
	var weapon := GameFlow.JOVIAN_COMBAT_WEAPON_ID
	var hull := float(_ship.get_telemetry().hull)
	var self_result := authority.submit_hitscan(_ship, weapon, _ship.to_global(Vector3(0, 2, 0)), _ship.global_basis.y)
	_check(self_result.get("collider") != _ship and is_equal_approx(_ship.get_telemetry().hull, hull),
		"Titan source excludes its own complete collision hierarchy")
	var foreign := authority.submit_hitscan(_ship, GameFlow.TORRENT_COMBAT_WEAPON_ID, origin, Vector3.UP)
	var unknown := Node3D.new()
	_game.add_child(unknown)
	unknown.global_position = origin
	var unregistered := authority.submit_hitscan(unknown, weapon, origin, Vector3.UP)
	var spoof := ShotRequest.new(unknown, 1110, GameFlow.PLAYER_FACTION, weapon,
		resolver.get_last_sequence(_ship, 1110) + 1, origin, Vector3.UP, 650, 70)
	var mismatch := resolver.resolve_hitscan(spoof)
	_check(foreign.get("status") == &"weapon_not_authorized" and unregistered.get("status") == &"unregistered_source"
		and mismatch.get("status") == &"source_mismatch", "Titan rejects foreign weapon, unregistered body and stale/source-mismatched owner")
	unknown.queue_free()
	var prior_mode := _game._network_session_mode
	_game._network_session_mode = &"client"
	_game._on_projectile_fired(origin, Vector3.UP, _ship)
	_game._network_session_mode = prior_mode
	_check(_game.get_last_player_shot_result().get("reason") == &"client_projectile_authority_forbidden",
		"client Titan projectile cannot resolve host damage")
	var arrow := _game.get_node("ArrowReconShip") as HeroShip
	var before_inactive := _game.get_last_player_shot_result()
	_game._on_projectile_fired(origin, Vector3.UP, arrow)
	_check(_game.get_last_player_shot_result() == before_inactive, "inactive friendly source cannot impersonate active Titan dispatch")
	var saved := arrow.global_transform
	arrow.global_transform = Transform3D(_ship.global_basis, origin - _ship.global_basis.z * 30)
	await _wait_frames(1)
	var friendly_hull := float(arrow.get_telemetry().hull)
	var friendly_aim := ((arrow.get_node("ArrowHullCollision") as CollisionShape3D).global_position - origin).normalized()
	var friendly := authority.submit_hitscan(_ship, weapon, origin, friendly_aim)
	_check(friendly.get("status") == &"friendly_fire_blocked" and friendly.get("collider") == arrow
		and is_equal_approx(arrow.get_telemetry().hull, friendly_hull), "real friendly hull blocks Titan beam without damage")
	arrow.global_transform = saved
	var target_position := origin - _ship.global_basis.z * 40
	target.activate(Transform3D(_ship.global_basis, target_position))
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PhysicsLayers.WORLD
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 2)
	collision.shape = box
	blocker.add_child(collision)
	_game.add_child(blocker)
	blocker.global_transform = Transform3D(_ship.global_basis, origin.lerp(target_position, 0.5))
	await _wait_frames(1)
	var health := target.get_health()
	var blocked := authority.submit_hitscan(_ship, weapon, origin, (target_position - origin).normalized())
	_check(blocked.get("status") == &"world_blocked" and blocked.get("collider") == blocker
		and is_equal_approx(target.get_health(), health), "actual world-layer occlusion protects production target from Titan cannon")
	blocker.queue_free()
	await _wait_frames(1)
