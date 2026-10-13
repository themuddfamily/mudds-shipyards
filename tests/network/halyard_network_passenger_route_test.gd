## test-matrix-display: input-only
extends SceneTree

## Two owned OS peers load actual Main. Each exterior hatch approach is staged;
## cabin walking, hatch opening, physical passenger chair and standing use Input.
## Claims remain on the authoritative host body and existing sealed role owner.
const Main := preload("res://scenes/main.tscn")
var _checks := 0
var _failures: Array[String] = []
var _directory := ""
var _role := ""
var _game: GameFlow
var _craft: HeroShip
var _cinder := false
var _navigator := false
var _gunner := false
var _gunner_shots := 0
var _navigator_cues: Array[StringName] = []
# Real outbound cruise, landing + authored survey use the existing shared success
# route's overall budget. All default waits and stage caps stay intact.
const EMBER_SURFACE_TOTAL_SECONDS := 2400.0
var _ember_surface := false
var _ember_surface_loss := false
var _ember_surface_loss_authority_first := false
var _ember_surface_total_deadline_unix := 0.0
var _shared_cruise := false
var _readiness_pressure_epoch := 0
var _host_loadmaster_flight := false
var _host_gunner_flight := false
var _manifest_receipts := 0
var _cargo_before: Dictionary = {}
var _player: PlayerController
var _port := 0
var _store_path := ""
var _package_under_test := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_ember_surface = "--ember-surface" in args
	args.erase("--ember-surface")
	_ember_surface_loss = "--ember-surface-loss" in args
	args.erase("--ember-surface-loss")
	_ember_surface_loss_authority_first = "--ember-surface-loss-authority-first" in args
	args.erase("--ember-surface-loss-authority-first")
	_ember_surface_loss = _ember_surface_loss or _ember_surface_loss_authority_first
	_ember_surface = _ember_surface or _ember_surface_loss
	var deadline_index := args.find("--ember-total-deadline")
	if deadline_index >= 0 and deadline_index + 1 < args.size():
		_ember_surface_total_deadline_unix = args[deadline_index + 1].to_float()
		args.remove_at(deadline_index + 1)
		args.remove_at(deadline_index)
	_shared_cruise = _shared_cruise or "--shared-cruise" in args
	args.erase("--shared-cruise")
	_host_gunner_flight = "--host-gunner-flight" in args
	args.erase("--host-gunner-flight")
	_gunner = "--halyard-gunner" in args or _host_gunner_flight
	args.erase("--halyard-gunner")
	_navigator = "--cinder-navigator" in args
	args.erase("--cinder-navigator")
	_host_loadmaster_flight = "--host-loadmaster-flight" in args
	args.erase("--host-loadmaster-flight")
	_cinder = "--cinder-loadmaster" in args or _host_loadmaster_flight or _navigator
	args.erase("--cinder-loadmaster")
	var package_index := args.find("--package-under-test")
	if package_index >= 0 and package_index + 1 < args.size():
		_package_under_test = args[package_index + 1]
		args.remove_at(package_index + 1)
		args.remove_at(package_index)
	if not _package_under_test.is_empty():
		_check(FileAccess.file_exists("res://project.binary"), "passenger process loads requested package without source game fallback")
		if not _failures.is_empty():
			quit(1)
			return
		print("PASSENGER_PACKAGE_LOADED: pid=%d package=%s" % [OS.get_process_id(), _package_under_test])
	if args.size() < 3:
		await _orchestrate()
		return
	_role = args[0]
	_directory = args[1]
	_port = int(args[2])
	_write(_role + ".script_ready", {})
	_game = Main.instantiate() as GameFlow
	_store_path = "user://passenger-peer-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game._find_flyable_ship_by_id(GameFlow.CINDER_CARGO_SHIP_ID) if _cinder else _game.get_node("HalyardCrewTransport") as HeroShip
	_player = _game.get_node("Player") as PlayerController
	_game.start_shift()
	await _ticks(3)
	if _navigator or _gunner:
		await _remap_navigator_fire()
	if _navigator:
		_game.audio.semantic_cue_emitted.connect(func(_source: StringName, cue: StringName, _intensity: float, _position: Vector3) -> void: _navigator_cues.append(cue))
	if _gunner:
		_craft.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3): _gunner_shots += 1)
	_write(_role + ".main_ready", {})
	if _ember_surface:
		if _role == "host":
			await _ember_surface_host()
		else:
			await _ember_surface_client()
	elif _shared_cruise:
		if _role == "host":
			await _shared_host()
		else:
			await _shared_client()
	elif _role == "host":
		await _host()
	else:
		await _client()
	for action in [&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"camera_distance_out"]:
		Input.action_release(action)
	_game.shutdown_network_session(&"passenger_test_done")
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(_store_path)
	_write(_role + ".done", {"checks": _checks, "failures": _failures})
	for failure in _failures:
		push_error(failure)
	print("HALYARD_NETWORK_PASSENGER_%s: %d checks, %d failures" % [_role.to_upper(), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _orchestrate() -> void:
	var ember_deadline := Time.get_ticks_msec() + int(EMBER_SURFACE_TOTAL_SECONDS * 1000.0)
	# Peers have separate tick clocks. Share this actual wall deadline for their
	# transit waits; the parent's unchanged monotonic cap still owns all setup.
	_ember_surface_total_deadline_unix = Time.get_unix_time_from_system() + EMBER_SURFACE_TOTAL_SECONDS
	_directory = "/tmp/mudds-passenger-peers-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(_directory)
	_port = 26000 + OS.get_process_id() % 15000
	var host_args := _peer_arguments("host", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"]))
	var host := _spawn_peer("host", host_args)
	_check(host > 0, "owned independent host starts")
	var peers := {"host": host}
	var host_ready := host > 0 and await _wait_file("host.main_ready", 60.0)
	if host_ready:
		host_ready = await _wait_file("host.ready", 60.0)
	if host_ready:
		for role in (["client", "client_b"] if _shared_cruise else ["client"]):
			var client_args := _peer_arguments(role, PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"]))
			var client := _spawn_peer(role, client_args)
			peers[role] = client
			_check(client > 0, "owned independent peer starts: " + role)
		var shared_clients_ready := true
		if _shared_cruise:
			# Cold Main startup has its own existing budget. The travel wait
			# begins only after both independent clients can participate.
			for role in ["client", "client_b"]:
				shared_clients_ready = await _wait_file(role + ".main_ready", 60.0) and shared_clients_ready
		if _shared_cruise and shared_clients_ready and await _wait_file("host.rebased", 60.0):
			var observer := _spawn_peer("observer", _peer_arguments("observer", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"])))
			peers["observer"] = observer
			_check(observer > 0, "owned late observer starts after actual origin commit")
		var finished := true
		if _shared_cruise:
			for role in ["client", "client_b"]:
				finished = await _wait_file(role + ".done", 120.0) and finished
			finished = await _wait_file("host.done", 60.0) and finished
			if peers.has("observer"):
				finished = await _wait_file("observer.done", 60.0) and finished
		elif _ember_surface:
			var remaining := maxf(0.0, float(ember_deadline - Time.get_ticks_msec()) / 1000.0)
			finished = int(peers.client) > 0 and await _wait_file("client.done", remaining)
			if finished:
				remaining = maxf(0.0, float(ember_deadline - Time.get_ticks_msec()) / 1000.0)
				finished = await _wait_file("host.done", minf(60.0, remaining))
		else:
			finished = int(peers.client) > 0 and await _wait_file("client.done", 120.0)
			if finished:
				finished = await _wait_file("host.done", 60.0)
		if not finished:
			for role in peers:
				await _abort_peer(role)
	else:
		await _abort_peer("host")
	for role in peers:
		var result := _read(role + ".done")
		_check(not result.is_empty() and (result.get("failures", []) as Array).is_empty(), "%s ordinary production route passes" % role)
		if not result.is_empty():
			_checks += int(result.get("checks", 0))
	for role in peers:
		await _wait_file(role + ".exit", 10.0)
		_check(FileAccess.get_file_as_string(_directory.path_join(role + ".exit")).strip_edges() == "0", "%s OS process exits zero" % role)
		var child_path := _directory.path_join(role + ".pid")
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and FileAccess.file_exists(child_path):
			var child := int(FileAccess.get_file_as_string(child_path))
			if child > 0 and DirAccess.dir_exists_absolute("/proc/%d" % child):
				OS.kill(child)
	for role in peers:
		var child := int(FileAccess.get_file_as_string(_directory.path_join(role + ".pid")))
		_check(child > 0 and not DirAccess.dir_exists_absolute("/proc/%d" % child), "%s actual Godot actor is absent after owning wait" % role)
	for role in peers:
		var pid := int(peers[role])
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	for failure in _failures:
		push_error(failure)
	print("PASSENGER_PEER_ARTIFACTS: ", _directory)
	print("HALYARD_NETWORK_PASSENGER_ROUTE: %d checks, %d failures" % [_checks, _failures.size()])
	if _failures.is_empty():
		if _ember_surface:
			print("HALYARD_NETWORK_EMBER_PASSENGER_TERRAIN_OK checks=%d" % _checks)
		else:
			print("HALYARD_NETWORK_PASSENGER_ROUTE_TEST_OK checks=%d" % _checks)
	quit(0 if _failures.is_empty() else 1)

func _abort_peer(role: String) -> void:
	if FileAccess.file_exists(_directory.path_join(role + ".done")):
		if await _until(func(): return FileAccess.file_exists(_directory.path_join(role + ".exit")), 10.0):
			return
	var pid_path := _directory.path_join(role + ".pid")
	if FileAccess.file_exists(pid_path):
		var pid := int(FileAccess.get_file_as_string(pid_path))
		if pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid):
			OS.kill(pid)
	# The owned shell still waits/reaps the actual child and records its exit.
	await _wait_file(role + ".exit", 10.0)

func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var parent := OS.get_cmdline_args()
	var path := ProjectSettings.globalize_path("res://")
	var path_index := parent.find("--path")
	if path_index >= 0 and path_index + 1 < parent.size():
		path = parent[path_index + 1]
	elif path.is_empty():
		path = DirAccess.open(".").get_current_dir()
	var script := "res://tests/network/halyard_network_passenger_route_test.gd"
	if not _package_under_test.is_empty():
		# Tests are excluded from export. Only this fixture is external;
		# res:// production Main and dependencies come from the selected pack.
		var script_index := parent.find("--script")
		if script_index >= 0 and script_index + 1 < parent.size():
			script = parent[script_index + 1]
		if script.begins_with("res://"):
			script = path.path_join(script.trim_prefix("res://"))
	var args := display.duplicate()
	args.append_array(["--audio-driver", "Dummy", "--path", path])
	if not _package_under_test.is_empty():
		args.append_array(["--main-pack", _package_under_test])
	args.append_array(["--script", script, "--", role, _directory, str(_port)])
	if _ember_surface:
		args.append("--ember-surface")
		args.append_array(["--ember-total-deadline", str(_ember_surface_total_deadline_unix)])
	if _ember_surface_loss:
		args.append("--ember-surface-loss")
	if _ember_surface_loss_authority_first:
		args.append("--ember-surface-loss-authority-first")
	if _shared_cruise:
		args.append("--shared-cruise")
	if _cinder:
		args.append("--cinder-loadmaster")
	if _gunner:
		args.append("--halyard-gunner")
	if _navigator:
		args.append("--cinder-navigator")
	if _host_gunner_flight:
		args.append("--host-gunner-flight")
	if _host_loadmaster_flight:
		args.append("--host-loadmaster-flight")
	if not _package_under_test.is_empty():
		args.append_array(["--package-under-test", _package_under_test])
	print("PASSENGER_PEER_LAUNCH: ", role, " ", args)
	return args

func _spawn_peer(role: String, args: PackedStringArray) -> int:
	# The wrapper waits for our child and records its actual OS exit status.
	# Positional arguments keep executable/path text out of shell evaluation.
	var command := '\"$@\" & child=$!; printf \"%s\" \"$child\" > \"$0.pid\"; wait \"$child\"; status=$?; printf \"%s\" \"$status\" > \"$0.exit\"; exit \"$status\"'
	# Each peer owns a separate display: two captured cursors must never
	# contend on one X server. The inner shell records the actual Godot PID
	# and exit; xvfb-run reaps its private server after that shell exits.
	var wrapper := PackedStringArray(["-a", "--server-args=-screen 0 1280x720x24 -nolisten unix -nolisten tcp", "/bin/sh", "-c", command, _directory.path_join(role), OS.get_executable_path()])
	wrapper.append_array(args)
	return OS.create_process("xvfb-run", wrapper)

func _host() -> void:
	_check(_game.host_network_session(_port).accepted, "production host starts")
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	_check(owner != null, "network binding owns actual Halyard physical roster")
	# One exterior staging placement; all subsequent host movement is input.
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05 + (_craft.global_basis.x * -0.8 if _cinder else Vector3.ZERO)))
	await _ticks(20)
	if _cinder:
		await _walk(Vector3(-2.2, -0.86, 0.0))
	else:
		await _walk(Vector3(-3.10, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
		var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
		await _look(hatch.global_position)
		await _press(&"interact")
		_check(await _until(func(): return _craft.is_canopy_open(), 5.0), "ordinary host hatch Interact opens physical cabin")
		await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
		await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	_game._refresh_interaction_targets()
	print("LOADMASTER_HOST_APPROACH: local=", _craft.to_local(_player.global_position), " floor=", _player.is_on_floor(), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables(), " facing=", _player.get_interaction_direction(), " target=", _station_anchor().global_position + Vector3.UP * 1.2, " origin=", _player.get_interaction_origin(), " cabin=", _game._solo_safe_recovery_cabin(_craft), " area=", (_craft.get_node("ShipBoardingArea") as ShipBoardingArea).is_available_for(_player))
	await _press(&"interact")
	var host_seated := await _until(func(): return _player.is_seated_at(_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_check(host_seated, "host ordinary walk and chair Interact physically seats passenger")
	print("PASSENGER_HOST_CHAIR: seated=", host_seated, " local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " assignment=", owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID))
	if not host_seated:
		return
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).get("role") == (&"gunner" if _gunner else &"passenger") and _game._solo_crew_claim_is_current(), "host-local claim uses exact network-owned chair and body")
	_check(_game._network_local_role_presentation().local_role == (&"gunner" if _gunner else &"passenger"), "host HUD names confirmed passenger role")
	if _host_gunner_flight:
		await _host_moving_gunner(owner)
		return
	if _host_loadmaster_flight:
		await _host_moving_loadmaster(owner)
		return
	if _navigator:
		_check(await _until(func(): return _objective_text().contains("AWAITING ROUTE HINT"), 3.0), "new navigator claim starts without old route-hint acknowledgement")
	if _cinder:
		_cargo_before = _cargo_state()
		_check(int(_cargo_before.finite_source) == GameFlow.CARGO_DELIVERY_SOURCE_INITIAL_QUANTITY and int(_cargo_before.capacity) == 8, "production cargo owner starts with exact finite quantity and retained eight-slot Cinder hold")
		await _press(&"fire")
		_check(await _until(func(): return _role_effect_ready(_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()), 3.0), "host ordinary seated FIRE reaches real manifest consumer")
		_check(_cargo_state() == _cargo_before, "host readiness preserves exact finite cargo state")
	if _gunner:
		await _press(&"fire")
		_check(_gunner_shots > 0 and not _craft.is_piloted() and not _craft.get_last_ship_command().fire, "ordinary host chair FIRE emits existing Halyard lance without helm command")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not bool(_game.get("_transition_busy")), 8.0), "ordinary host stand restores supported controllable body")
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() and _craft.get_crew_role_authority() == owner, "host stand releases own claim and preserves shared network ledger")
	# Clear the shared exit through ordinary walking before another body arrives.
	await _walk(Vector3(-1.85, -0.86, -1.7) if _cinder else Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	_check(_player.global_position.distance_to(_station_contract().exit_transform.origin) > 2.0, "host walks clear of the shared chair exit")
	_player.set_control_enabled(false)
	var observed_craft: HeroShip
	var observed_source: ShipCommandSource
	if _navigator:
		# Change only the host's observed craft, retaining the real walking Cinder
		# bodies, chair authority and all command producers.
		observed_craft = _game._find_flyable_ship_by_id(GameFlow.TORRENT_SHIP_ID)
		observed_source = observed_craft.get_command_source()
		_game.active_ship = observed_craft
		_check(_game._attach_network_ship_authority_composition().accepted and _game._network_composition_ship == observed_craft, "host observes another actual craft before remote navigator FIRE")
	_write("host.ready", {})
	if not await _wait_file("client.admitted", 60.0):
		return
	if not await _wait_file("client.seated", 60.0):
		print("PASSENGER_HOST_TIMEOUT: wall=", Time.get_unix_time_from_system(),
			" peers=", _game.network_session.get_admitted_peer_ids(),
			" capacity=", _game.network_session.get_session_capacity_snapshot(),
			" bodies=", _game.get_network_remote_body_audit())
		return
	var simulation := _game.get_network_remote_body_simulation()
	var peers := _game.network_session.get_admitted_peer_ids()
	_check(peers.size() == 1, "one actual separate client is admitted")
	if peers.is_empty():
		return
	var peer := int(peers[0])
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var body := simulation.get_body(avatar)
	var assignment: Dictionary = owner.get_assignment(peer, avatar)
	_check(body != null and body.is_seated_at(_station_anchor()), "host production walking body physically occupies passenger anchor")
	_check(assignment.get("role") == (&"gunner" if _gunner else &"passenger") and assignment.get("seat_id") == (&"co_pilot_station" if _gunner else (CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID if _navigator else (CinderCargoHauler.LOADMASTER_STATION_SEAT_ID if _cinder else HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID))), "host role owner grants exactly the authored passenger chair")
	var seat := simulation.get_body_crew_seat(avatar)
	var unregistered := PlayerController.new()
	var spoof := {"body": unregistered, "owner_peer_id": peer, "entity_id": &"foreign_passenger", "craft": _craft, "frame": _craft.get_moving_interior_component()}
	_check(not (_game._network_engineer_binding.loadmaster if _cinder else _game._network_engineer_binding.passenger).claim(spoof, seat).accepted, "unregistered body cannot invent passenger occupancy")
	unregistered.free()
	if _cinder:
		_check(_role_effect_ready(_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()), "host owns remote manifest readiness effect")
		if _navigator:
			_check(_navigator_cues.has(&"cinder_navigator_ping_accepted") and _game._cinder_navigator_ping_hud_composition.get_snapshot().presenter.state == &"active", "off-camera authenticated FIRE reaches retained real HUD and semantic audio")
			_check(_game.active_ship == observed_craft and observed_craft.get_command_source() == observed_source and not observed_craft.is_piloted(), "off-camera ping preserves the observed craft and exact helm producer")
		_check(_cargo_state() == _cargo_before, "remote readiness preserves host finite cargo state")
		var binding := _game._network_engineer_binding.loadmaster
		var payload := {"action": &"navigator_ping" if _navigator else &"cargo_manifest_ready", "avatar_id": avatar, "entity_generation": int(simulation.get_body_record(avatar).entity_generation), "seat_generation": int(assignment.seat_generation), "claim_sequence": int(assignment.claim_sequence), "request_sequence": int(binding.get("_requests").get(avatar, 0)), "binding_generation": int(binding.get("_generation")), "migration_generation": int(_game.network_session.get_migration_snapshot().migration_generation), "server_tick": _game.network_session.get_boarding_server_tick()}
		var forged := payload.duplicate()
		forged.avatar_id = &"foreign_loadmaster"
		_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "forged avatar cannot submit manifest readiness")
		for key in ["entity_generation", "seat_generation"]:
			forged = payload.duplicate()
			forged[key] += 1
			_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "foreign " + key + " cannot submit readiness")
		forged = payload.duplicate()
		forged.server_tick -= 121
		_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "stale host tick cannot submit readiness")
		forged = payload.duplicate()
		forged.action = &"engineer_repair"
		_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "foreign role action cannot submit readiness")
		forged = payload.duplicate()
		forged.claim_sequence += 1
		_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "foreign chair claim cannot submit readiness")
		forged = payload.duplicate()
		forged.migration_generation += 1
		_check(not _game._network_engineer_binding.dispatch(peer, forged).accepted, "stale session role generation cannot submit readiness")
		_check(not _game._network_engineer_binding.dispatch(1, payload).accepted, "host peer cannot forge admitted remote readiness")
		_check(_role_effect_ready(_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()) and not _game._network_engineer_binding.dispatch(peer, payload).accepted, "actual authenticated FIRE accepts once and refuses replay without advancing the client's cursor")
	if _gunner:
		_check(_gunner_shots > 1 and _craft.get_gunner_gameplay_state().last_fire.get("selection", {}).get("selection", {}).get("avatar_id") == avatar, "authenticated ordinary peer FIRE reaches the actual host projectile owner")
		var binding := _game._network_engineer_binding.passenger
		var payload := {"avatar_id": avatar, "entity_generation": int(simulation.get_body_record(avatar).entity_generation), "seat_generation": int(assignment.seat_generation), "claim_sequence": int(assignment.claim_sequence), "target_generation": int(_craft.get_gunner_gameplay_state().target_generation), "request_sequence": int(binding.get("_requests").get(avatar, 0)), "binding_generation": int(binding.get("_generation")), "migration_generation": int(_game.network_session.get_migration_snapshot().migration_generation), "server_tick": _game.network_session.get_boarding_server_tick(), "trigger": true, "aim_local": Vector3.FORWARD}
		var before := _gunner_shots
		_check(not binding.dispatch_gunner(peer, payload).accepted, "replayed authenticated gunner cursor refuses duplicate fire")
		for field in ["entity_generation", "seat_generation", "claim_sequence", "binding_generation", "migration_generation", "target_generation"]:
			var forged := payload.duplicate()
			forged.request_sequence += 1
			forged[field] += 1
			_check(not binding.dispatch_gunner(peer, forged).accepted, "foreign gunner " + field + " refuses fire")
		_check(before == _gunner_shots, "refused gunner generations never emit a projectile")
	_write("host.seat_checked", {})
	if not await _wait_file("client.stood", 20.0):
		return
	_check(owner.get_assignment(peer, avatar).is_empty() and not body.is_seated(), "ordinary remote stand releases exact physical role")
	if _navigator:
		_check((_craft.get_navigator_ping_snapshot().get("receipt", {}) as Dictionary).is_empty() and _navigator_cues.has(&"cinder_navigator_ping_cleared") and _game._cinder_navigator_ping_hud_composition.get_snapshot().presenter.state == &"cleared", "off-camera ordinary stand clears the actual navigator receipt, HUD and semantic audio")
	_check(await _until(func(): return body.is_on_floor(), 3.0), "stood host body has usable cabin support")
	_write("host.stand_checked", {})
	if not await _wait_file("client.reseated", 20.0):
		return
	var reseated: Dictionary = owner.get_assignment(peer, avatar)
	_check(not reseated.is_empty() and int(reseated.get("claim_sequence", 0)) != int(assignment.claim_sequence), "ordinary reseat creates fresh authoritative chair identity")
	if _navigator:
		var binding := _game._network_engineer_binding.loadmaster
		var generation: int = binding.get_navigator_presentation_generation()
		var clears := _navigator_cues.count(&"cinder_navigator_ping_cleared")
		_check(_craft.release_crew_role(1, peer, avatar, CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID, binding.next_request_sequence(int(owner.get_last_intent(peer, avatar).get("request_sequence", 0))), int(reseated.seat_generation)).accepted and owner.get_assignment(peer, avatar).is_empty() and body.is_seated_at(_station_anchor()), "actual host role owner revokes the ordinary peer's row before retained publication retirement")
		var other_cards: Dictionary = (_game.hud.get("_runtime_status_cards") as Dictionary).duplicate(true)
		other_cards.erase(&"crew")
		var retained_source: Dictionary = _game._cinder_navigator_ping_hud_composition.get_snapshot().adapter.composed_crew_snapshot.duplicate(true)
		var replacement := retained_source.duplicate(true)
		replacement.crew_status_headline = "NAVIGATOR UPDATED CREW STATUS"
		_game.hud.update_crew_role_status(replacement)
		var replacement_view := CrewRoleSeatPresenter.new().present_snapshot(replacement)
		binding.cinder_navigator_ping_tombstones_forwarded.connect(func(envelope: Dictionary):
			var rendered: Dictionary = (_game.hud.get("_runtime_status_cards") as Dictionary).get(&"crew", {}).get("snapshot", {})
			_check(rendered == replacement_view and _game._cinder_navigator_ping_hud_composition.get_snapshot().attached, "old navigator retirement preserves a newer real crew card with the same occupant and changed headline")
			_game.hud.update_crew_role_status(retained_source)
			_game._on_cinder_navigator_ping_tombstones_forwarded(envelope)
		, CONNECT_ONE_SHOT)
		var retired: Dictionary = binding._retire_navigator_publication(&"test_retained_publication")
		_check(int(retired.get("tombstone_count", 0)) == 1 and int(retired.tombstones[0].receipt.ship_generation) == generation, "existing bridge detach retains its actual old-generation wire clear")
		_check(_navigator_cues.count(&"cinder_navigator_ping_cleared") == clears + 1 and not (_game.hud.get("_runtime_status_cards") as Dictionary).has(&"crew") and not _game._cinder_navigator_ping_hud_composition.get_snapshot().attached, "revoked ordinary peer's retained tombstone clears its rendered old overlay and actual audio without inventing occupancy")
		var remaining_cards: Dictionary = (_game.hud.get("_runtime_status_cards") as Dictionary).duplicate(true)
		remaining_cards.erase(&"crew")
		_check(remaining_cards == other_cards, "revoked navigator retirement preserves every unrelated existing status card")
		_game._sync_cinder_navigator_presentations()
		_check(binding.get_navigator_presentation_generation() == 0 and not _game.optional_semantic_audio_composition.get_snapshot().navigator.attached and not _game._cinder_navigator_ping_hud_composition.get_snapshot().attached, "detach retires both existing presentation consumers after forwarding")
		_game._on_cinder_navigator_ping_tombstones_forwarded(retired)
		_check(_navigator_cues.count(&"cinder_navigator_ping_cleared") == clears + 1 and _game._cinder_navigator_presentation_ship_generation == 0, "retired old-generation envelope cannot replay or reattach presentation authority")
		simulation.stand_crew_body(avatar)
		_check(await _until(func(): return not body.is_seated() and body.is_on_floor() and body.get_cabin_containment_report().active, 3.0), "existing host body owner restores supported cabin standing after exact row revocation")
	print("PASSENGER_HOST_WALK_AUDIT: wall=", Time.get_unix_time_from_system(), " body=", simulation.get_body_record(avatar), " intent=", body.get_remote_drive_audit(), " movement=", _game.network_session.get_movement_authority_audit())
	_write("host.reseat_checked", {})
	if not await _wait_file("client.migrate", 20.0):
		return
	_check(_game.network_session.rotate_session_migration().accepted, "real host migration rotates while passenger seated")
	var epoch := _game.network_session.get_migration_snapshot()
	_check(_game.network_session.rotate_session_migration().get("status") == &"rebind_pending"
		and _game.network_session.get_migration_snapshot() == epoch,
		"a consecutive rotation cannot overtake the pending authenticated rebind")
	await _ticks(35)
	_check(owner.get_assignment(peer, avatar).is_empty() and not body.is_seated() and body.get_cabin_containment_report().active, "migration releases physical passenger and restores retained cabin body")
	_write("host.migrated", {})
	if not await _wait_file("client.disconnect_seated", 25.0):
		return
	_check(not owner.get_assignment(peer, avatar).is_empty() and body.is_seated(), "passenger physically occupies chair at disconnect boundary")
	var rebound: Dictionary = _game.network_session.get_migration_snapshot().peers[0]
	_check(bool(rebound.active) and not bool(rebound.rebind_required)
		and int(rebound.peer_generation) == 2
		and rebound.attachment.seat.seat_id == GameFlow.network_cabin_berth_seat_id(_craft.get_ship_id(), 1),
		"production newer hello rebinds the retained authoritative boarding receipt")
	_check(rebound.attachment.interest == (_game.network_session.get_snapshot().lifecycle.peer_interest as Dictionary).get(peer, {}),
		"retained bounded interest is the lifecycle owner's committed record")
	_check(simulation.get_body(avatar) == body and int(simulation.get_body_record(avatar).entity_generation) == 1,
		"migration preserves one existing physical body and entity generation")
	_write("host.disconnect_ready", {})
	if not await _wait_file("client.disconnected", 20.0):
		return
	await _ticks(20)
	_check(simulation.get_body(avatar) == null and owner.get_assignment(peer, avatar).is_empty(), "disconnect retires actual remote body and exact passenger role")
	if _navigator:
		_game.active_ship = _craft
		_game._attach_network_ship_authority_composition()
	_game.shutdown_network_session(&"passenger_host_done")
	_check(_craft.get_crew_role_authority() == null, "shutdown detaches exact empty role owner for ordinary solo reuse")
	if _cinder:
		_player.set_control_enabled(true)
		await _walk(_craft.to_local(_station_contract().entry_transform.origin))
		await _look(_station_anchor().global_position + Vector3.UP * 1.2)
		await _press(&"interact")
		_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "ordinary local-only chair reentry creates the supported loadmaster consumer")
		var local_owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
		_check(local_owner != null and local_owner != owner and _game._solo_crew_claim_is_current(), "local-only loadmaster owns a fresh exact physical chair claim")
		await _press(&"fire")
		_check(await _until(func(): return _role_effect_ready(_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()), 3.0), "local-only ordinary FIRE reaches real manifest consumer")
		_check(_cargo_state() == _cargo_before, "local-only readiness preserves exact finite cargo state")
		if _navigator and local_owner != null:
			await _test_navigator_safe_home_recovery(local_owner)
		elif local_owner != null:
			_craft.queue_free()
			_check(await _until(func(): return not is_instance_valid(_craft) and not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled(), 8.0), "retiring actual seated Cinder restores supported usable local controls")
			_check(local_owner.get_snapshot().assignments.is_empty() and not _player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META), "retired Cinder releases only its exact claim and physical body tag")

func _admitted_session_ready() -> bool:
	var session := _game.network_session
	if not session.is_session_active():
		return false
	var offer: Dictionary = session.get_server_offer()
	var admission: Dictionary = offer.get("admission", {})
	var peer: Dictionary = admission.get("peer", {})
	var transport: Dictionary = offer.get("transport", {})
	var epoch: Dictionary = (offer.get("migration", {}) as Dictionary).get("epoch", {})
	var current: Dictionary = session.get_migration_snapshot()
	if not bool(admission.get("accepted", false)) or int(peer.get("peer_id", 0)) != session.multiplayer.get_unique_id() \
			or int(peer.get("peer_generation", 0)) <= 0 \
			or int(transport.get("peer_id", 0)) != session.multiplayer.get_unique_id() \
			or int(transport.get("peer_generation", 0)) != int(peer.get("peer_generation", 0)):
		return false
	for key in ["package_generation", "session_generation", "migration_generation"]:
		if int(epoch.get(key, 0)) <= 0 or epoch.get(key) != current.get(key):
			return false
	return true

func _client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "production client joins")
	var ready := await _until(_admitted_session_ready, 60.0)
	_check(ready, "client receives matching admitted current-epoch server offer")
	if not ready:
		return
	_write("client.admitted", {})
	var offer: Dictionary = _game.network_session.get_server_offer()
	print("PASSENGER_CLIENT_JOIN: wall=", Time.get_unix_time_from_system(),
		" active=", _game.network_session.is_session_active(),
		" offer_peer=", (offer.get("admission", {}) as Dictionary).get("peer", {}),
		" phase=", _game.phase, " local=", _craft.to_local(_player.global_position))
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05 + (_craft.global_basis.x * -0.8 if _cinder else Vector3.ZERO)))
	await _ticks(10)
	await _press(&"interact")
	var admitted := await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not bool(_game.get("_transition_busy")), 12.0)
	_check(admitted, "ordinary hatch Interact admits real walking body")
	print("PASSENGER_CLIENT_HATCH: wall=", Time.get_unix_time_from_system(),
		" admitted=", admitted, " active=", _game.network_session.is_session_active(),
		" phase=", _game.phase, " local=", _craft.to_local(_player.global_position),
		" boarding=", _game.get_network_client_boarding_audit())
	if not admitted:
		return
	root.grab_focus()
	await _ticks(20)
	if _host_loadmaster_flight or _host_gunner_flight:
		await _client_loadmaster_pilot()
		return
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	_check(_player.is_on_floor(), "ordinary cabin walk reaches actual passenger chair supported")
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	print("PASSENGER_APPROACH: local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables())
	await _press(&"interact")
	var seated := await _until(func(): return _player.is_seated_at(_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_check(seated, "ordinary chair Interact seats client only after host confirms")
	if not seated:
		print("PASSENGER_CHAIR_DEBUG: ", _game.network_session.get_passenger_replica_snapshot())
		return
	_check(_player.is_station_seated() and _player.is_control_enabled(), "confirmed passenger retains usable seated controls")
	_check(_craft.get_crew_role_authority() == null and not _craft.is_piloted() and (_cinder or _gunner or _craft.get_local_input_source().get_authority_peer_id() == 1), "client chair acquires no role ledger or pilot control; Cinder sampler serves only readiness")
	_check(_game._network_local_role_presentation().local_role == (&"gunner" if _gunner else &"passenger"), "client HUD names confirmed passenger role")
	if _navigator:
		_check(await _until(func(): return _objective_text().contains("AWAITING ROUTE HINT"), 3.0), "new navigator claim starts without old route-hint acknowledgement")
	if _cinder:
		_cargo_before = _cargo_state()
		_check(int(_cargo_before.finite_source) == GameFlow.CARGO_DELIVERY_SOURCE_INITIAL_QUANTITY and int(_cargo_before.capacity) == 8, "production cargo owner starts with exact finite quantity and retained eight-slot Cinder hold")
		await _press(&"fire")
		_check(await _until(func(): return _role_effect_ready(_game.network_session.get_passenger_replica_snapshot().get("navigator" if _navigator else "manifest", {})), 5.0), "remote ordinary seated FIRE reaches host manifest consumer and confirms receipt")
		_check(_cargo_state() == _cargo_before, "client readiness leaves finite cargo unchanged")
	if _gunner:
		await _press(&"fire")
		_check(_gunner_shots == 0 and not _craft.is_piloted(), "client sends admitted gunner demand without local projectile or helm")
	_write("client.seated", {})
	if not await _wait_file("host.seat_checked", 10.0):
		return
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and not bool(_game.get("_transition_busy")), 8.0), "ordinary passenger stand receives host authorization")
	await _ticks(20)
	print("PASSENGER_STAND_DEBUG: local=", _craft.to_local(_player.global_position), " floor=", _player.is_on_floor(), " control=", _player.is_control_enabled(), " station=", _player.is_station_seated(), " containment=", _player.get_cabin_containment_report(), " view=", _game.network_session.get_passenger_replica_snapshot())
	_check(await _until(func(): return _player.is_on_floor() and _player.is_control_enabled() and not _player.is_station_seated(), 3.0), "standing restores supported ordinary controls")
	_write("client.stood", {})
	if not await _wait_file("host.stand_checked", 10.0):
		return
	var stood_local := _craft.to_local(_player.global_position)
	await _walk(Vector3(-1.85, -0.86, -1.7) if _cinder else Vector3(0.0, 0.52, -6.80))
	_check(_craft.to_local(_player.global_position).distance_to(stood_local) > 0.6 and _player.is_on_floor(), "ordinary post-stand locomotion moves the supported passenger along the cabin aisle")
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "ordinary reseat succeeds without injected occupancy")
	if _gunner:
		_check(await _until(func(): return _objective_text().contains("READY"), 3.0), "ordinary reseat starts with fresh gunner acknowledgement")
		await _press(&"fire")
	if _navigator:
		_check(await _until(func(): return _objective_text().contains("AWAITING ROUTE HINT"), 3.0), "ordinary reseat clears the previous visible navigator acknowledgement")
		await _press(&"fire")
	print("PASSENGER_RESEAT_DEBUG: local=", _craft.to_local(_player.global_position), " floor=", _player.is_on_floor(), " control=", _player.is_control_enabled(), " candidate=", _game.station_interaction_candidate, " view=", _game.network_session.get_passenger_replica_snapshot(), " body_source=", _game.get_network_remote_body_intent_source().get_audit())
	_write("client.reseated", {})
	if not await _wait_file("host.reseat_checked", 10.0):
		return
	_write("client.migrate", {})
	if not await _wait_file("host.migrated", 12.0):
		return
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled() and not bool(_game.get("_transition_busy")), 8.0), "migration restores usable local passenger body")
	if _cinder:
		await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	_check(await _until(func():
		var source := _game.get_network_remote_body_intent_source()
		return source != null and source.is_bound() and source.get_audit().stream_id == 2 \
			and bool(source.get_audit().opening_confirmed) \
			and _game.station_interaction_candidate is ShipCrewSeat \
			and _game._network_client_boarding_holds(_craft)
	, 8.0), "fresh authenticated offer reopens the same body stream with the actual host clock")
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "fresh post-migration ordinary chair claim succeeds")
	if _gunner:
		await _press(&"fire")
	if _cinder:
		await _press(&"fire")
		_check(await _until(func(): return _role_effect_ready(_game.network_session.get_passenger_replica_snapshot().get("navigator" if _navigator else "manifest", {})), 5.0), "post-migration ordinary FIRE uses fresh binding and request cursor")
	_write("client.disconnect_seated", {})
	if not await _wait_file("host.disconnect_ready", 10.0):
		return
	_game.shutdown_network_session(&"passenger_client_disconnect")
	_check(not _player.is_seated() and _player.is_control_enabled(), "disconnect leaves local passenger awake with controls")
	_write("client.disconnected", {})


func _station_anchor() -> Marker3D:
	return _craft.get_gunner_station_anchor() if _gunner else (_craft.get_navigator_station_anchor() if _navigator else _craft.get_loadmaster_station_anchor())

func _station_contract() -> Dictionary:
	if _gunner:
		return _craft.get_gunner_station_role_contract()
	if _navigator:
		if _craft.has_method("get_navigator_station_role_contract"):
			return _craft.get_navigator_station_role_contract()
		return {"entry_transform": _craft.global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.95, -0.86, 0.25)), "exit_transform": _craft.global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.95, -0.86, 0.25))}
	return _craft.get_passenger_station_role_contract()

func _role_effect_ready(snapshot: Dictionary) -> bool:
	var receipt := snapshot.get("receipt", {}) as Dictionary
	return receipt.get("marker_id", &"") == CinderCargoHauler.NAVIGATOR_ROUTE_ID if _navigator else bool(receipt.get("ready", false))

func _test_navigator_safe_home_recovery(retired_owner: CrewSeatRoleAuthority) -> void:
	var disk := UserDataStore.new(_store_path)
	disk.load()
	var context: Dictionary = disk.get_snapshot().get(GameFlow.SOLO_SAFE_RECOVERY_SLOT, {})
	_check(context.get("mode") == "crew" and context.get("craft_id") == String(CinderCargoHauler.COMPONENT_ID) and context.size() == 4, "ordinary navigator stores only existing safe crew/craft/home preference")
	var settings: Dictionary = disk.get_snapshot().get("runtime_settings", {}).duplicate(true)
	_game.queue_free()
	await _ticks(3)
	_check(retired_owner.get_snapshot().assignments.is_empty(), "retiring actual seated Main empties old navigator claim")
	_game = Main.instantiate() as GameFlow
	var fresh_store := UserDataStore.new(_store_path)
	_check(_game.configure_runtime_settings_persistence(fresh_store), "fresh Main reads the same real private save")
	root.add_child(_game)
	await _ticks(4)
	_player = _game.player
	_craft = _game._find_flyable_ship_by_id(GameFlow.CINDER_CARGO_SHIP_ID)
	_check(not _game.get_recovery_available_snapshot().is_empty() and _game.get_session_recovery_save_summary().contains("awake"), "fresh Main offers ordinary awake navigator home recovery")
	var resume := (_game.hud.get("_session_recovery_action_buttons") as Dictionary).get(&"continue") as Button
	_check(resume != null, "existing HUD Resume action is available")
	if resume == null:
		return
	resume.pressed.emit()
	await _ticks(3)
	_game.start_shift()
	_check(await _until(func(): return _player.is_on_floor() and _player.is_control_enabled() and not _player.is_seated() and _game.active_ship == _craft, 8.0), "real-file Resume returns awake in the supported home Cinder cabin")
	_check(_craft.get_crew_role_authority() == null and not _craft.is_piloted() and not _player.has_meta(HeroShip.SOLO_CREW_ROLE_OCCUPANT_META) and (_craft.get_navigator_ping_snapshot().get("receipt", {}) as Dictionary).is_empty(), "recovery restores no old navigator claim, ping, or helm authority")
	_check(fresh_store.get_snapshot().get("runtime_settings", {}) == settings, "awake home recovery retains actual remapped settings namespace")
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	print("NAVIGATOR_HOME_HELM_APPROACH: local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " boarding=", _game.boarding_candidate, " nearby=", _player.get_nearby_interactables(), " facing=", _player.get_interaction_direction(), " containment=", _player.get_cabin_containment_report())
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(pilot) and bool(_game.get("_piloting")), 8.0), "recovered awake navigator walks and Interact returns to actual home helm")

func _on_manifest_ready(_receipt: Dictionary) -> void:
	_manifest_receipts += 1

func _helm_cursor(source: ShipCommandSource) -> Dictionary:
	return {"stream": source.get_stream_id(), "delivery": source.get_delivery_generation(), "sequence": source.get_next_sequence()}

func _host_moving_gunner(owner: CrewSeatRoleAuthority) -> void:
	var area := _craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var local_source := _craft.get_local_input_source()
	var profile_values: Dictionary = local_source.get_input_binding_profile().to_dictionary().duplicate(true)
	var start := _craft.global_position
	var engine_before := StringName(_craft.get_telemetry().engine_state)
	await _press(&"fire")
	_check(engine_before == HeroShip.ENGINE_OFFLINE and bool(_player.get_meta(HalyardCrewTransport.HALYARD_CREW_ROLE_OCCUPANT_META, {}).get("weapon_power_started", false)), "ordinary pre-admission gunner FIRE owns actual weapon-started power")
	_write("host.ready", {})
	if not await _wait_file("client.moving", 60.0):
		return
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	_check(_game._host_craft_has_remote_pilot(_craft) and helm != null and helm != local_source, "admitted real peer owns Halyard helm alongside ordinary host gunner")
	if helm == null:
		return
	var helm_weak: WeakRef = weakref(helm)
	_check(await _until(func(): return _craft.global_position.distance_to(start) > 5.0 and _craft.velocity.length() > 0.1, 5.0), "real authenticated throttle displaces actual Halyard hull with seated gunner")
	var consumed := _craft.get_last_ship_command()
	_check(consumed != null and consumed.stream_id == helm.get_stream_id() and absf(consumed.throttle) > HeroShip.AUTOMATIC_ENGINE_INTENT_EPSILON and _craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE, "host consumes current remote pilot throttle through existing engine owner")
	_check(_player.is_seated_at(_station_anchor()) and _game._solo_crew_claim_is_current() and _craft.get_moving_interior_component().is_occupant_registered(_player), "moving gunner retains exact chair generation and physical carry")
	var cursor := _helm_cursor(helm)
	_game._reset_solo_gunner_input()
	_check(_helm_cursor(helm) == cursor and _craft.get_command_source() == helm, "retiring crew input leaves authenticated remote helm cursor unchanged")
	var shots := _gunner_shots
	await _press(&"fire")
	_check(_gunner_shots > shots and _craft.get_command_source() == helm and not _craft.get_last_ship_command().fire, "moving ordinary remapped gunner FIRE emits real lance without changing remote flight producer")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled() and not _game._transition_busy, 8.0), "moving ordinary gunner stand restores supported host walking")
	_check(area.get_reservation_token() == _player and _craft.get_command_source() == helm and helm.get_stream_id() == cursor.stream and helm.get_delivery_generation() == cursor.delivery and _craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE, "moving stand retains exact cabin reservation, remote helm epoch and peer-owned engine power")
	var stood := _craft.to_local(_player.global_position)
	await _walk(Vector3(0.0, 0.52, -8.9))
	_check(_craft.to_local(_player.global_position).distance_to(stood) > 0.6 and _player.is_on_floor(), "ordinary gunner walks real moving Halyard flight deck")
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and _game._solo_crew_claim_is_current() and not _game._transition_busy, 8.0), "moving ordinary gunner reseat uses retained physical cabin and fresh claim")
	var claim := owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
	if claim.is_empty():
		return
	shots = _gunner_shots
	await _press(&"fire")
	_check(_gunner_shots > shots and owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).seat_generation == claim.seat_generation, "moving reseat fires through current generation and crew cursor")
	var sequence := maxi(int(claim.claim_sequence), int(owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
	_check(_craft.release_crew_role(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, &"co_pilot_station", sequence, int(claim.seat_generation)).accepted, "existing owner revokes exact moving gunner lease")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled(), 8.0), "revoked moving gunner returns to supported carried walking")
	shots = _gunner_shots
	_fire_key(true)
	await _ticks(4)
	_fire_key(false)
	_check(shots == _gunner_shots and _craft.get_command_source() == helm, "unseated remapped FIRE cannot reuse revoked gunner authority or alter remote helm")
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and _game._solo_crew_claim_is_current() and not _game._transition_busy, 8.0), "ordinary moving reentry reacquires only the released gunner chair")
	_check(_craft.get_local_input_source() == local_source and local_source.get_input_binding_profile().to_dictionary() == profile_values and area.get_reservation_token() == _player and _craft.get_command_source() == helm, "moving gunner lifecycle preserves configured sampler, cabin and exact remote producer")
	_write("host.flight_checked", {})
	if not await _wait_file("client.disconnected", 20.0):
		return
	_check(await _until(func(): return not _craft.is_remote_piloted() and _craft.get_command_source() == local_source and helm_weak.get_ref() == null, 5.0), "real pilot disconnect restores retained local producer")
	_check(_game._solo_crew_claim_is_current(), "authenticated pilot disconnect preserves independent physical gunner claim")
	shots = _gunner_shots
	await _press(&"fire")
	_check(_gunner_shots > shots, "ordinary gunner FIRE remains usable after real peer helm disconnect")


func _host_moving_loadmaster(owner: CrewSeatRoleAuthority) -> void:
	_cargo_before = _cargo_state()
	var area := _craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var local_source := _craft.get_local_input_source()
	var profile := local_source.get_input_profile_generation()
	var profile_values: Dictionary = local_source.get_input_binding_profile().to_dictionary().duplicate(true)
	(_craft as CinderCargoHauler).loadmaster_manifest_intent_accepted.connect(_on_manifest_ready)
	_print_host_loadmaster_state(&"before_client_ready", local_source, profile, profile_values, area)
	_write("host.ready", {})
	if not await _wait_file("client.moving", 60.0):
		return
	_print_host_loadmaster_state(&"on_client_moving", local_source, profile, profile_values, area)
	_check(_game._cinder_host_has_remote_pilot(_craft), "actual admitted peer holds the confirmed Cinder pilot lease")
	_print_host_loadmaster_state(&"before_engine_assertion", local_source, profile, profile_values, area)
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	_check(helm != null and helm != local_source and _craft.is_remote_piloted(), "remote helm stays selected beside the retained local crew sampler")
	if helm == null:
		return
	var helm_weak: WeakRef = weakref(helm)
	var start := _craft.global_position
	await _ticks(12)
	_print_host_loadmaster_state(&"after_original_12_ticks", local_source, profile, profile_values, area, helm_weak)
	# The client movement marker is prediction; verify authoritative consumption after the existing ticks.
	var consumed_command: ShipCommand = _craft.get_last_ship_command()
	_check(
		_craft.get_command_source() == helm
		and consumed_command != null and consumed_command.is_valid()
		and consumed_command.stream_id == helm.get_stream_id()
		and absf(consumed_command.throttle) > HeroShip.AUTOMATIC_ENGINE_INTENT_EPSILON
		and _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE,
		"validated remote throttle wakes the authoritative Cinder engine"
	)
	_check(_craft.global_position.distance_to(start) > 0.05, "authoritative pilot commands move the actual crew craft")
	_check(_player.is_seated_at(_station_anchor()) and _craft.get_moving_interior_component().is_occupant_registered(_player), "moving host Loadmaster retains exact physical chair and carry frame")
	var cursor := _helm_cursor(helm)
	_game._reset_solo_gunner_input()
	_check(_helm_cursor(helm) == cursor and _craft.get_command_source() == helm, "crew stream retirement leaves remote helm identity and cursor untouched")
	if _navigator:
		_fire_key(true)
	else:
		Input.action_press(&"fire")
	_check(await _until(func(): return _role_effect_ready(_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()), 3.0), "ordinary host FIRE submits readiness while the confirmed peer pilots")
	var receipt := ((_craft.get_navigator_ping_snapshot() if _navigator else _craft.get_loadmaster_manifest_snapshot()).get("receipt", {}) as Dictionary).duplicate(true)
	await _ticks(15)
	if _navigator:
		_fire_key(false)
	else:
		Input.action_release(&"fire")
	_check((owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence") == receipt.get("request_sequence") if _navigator else _manifest_receipts == 1 and _craft.get_loadmaster_manifest_snapshot().get("receipt", {}) == receipt), "held FIRE records exactly one readiness receipt for the claim")
	_print_host_loadmaster_state(&"before_readiness_invariant", local_source, profile, profile_values, area, helm_weak)
	_check(_cargo_state() == _cargo_before and _craft.get_local_input_source() == local_source and local_source.is_input_configuration_valid() and local_source.get_input_binding_profile().to_dictionary() == profile_values, "moving readiness preserves finite cargo and the settings-configured input profile")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving stand restores supported host cabin controls")
	_check(_craft.get_command_source() == helm and helm.get_stream_id() == cursor.stream and helm.get_delivery_generation() == cursor.delivery, "moving stand preserves the selected remote helm stream and delivery epoch")
	_check(area.is_reserved() and area.get_reservation_token() == _player, "moving stand retains the host's exact cabin reservation")
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	_check(await _until(func():
		var label := _game.hud.get("_interaction_label") as Label
		return _game.station_interaction_candidate is ShipCrewSeat and label != null and label.text.contains("SIT") and label.text.contains("NAVIGATOR" if _navigator else "LOADMASTER")
	, 3.0), "moving host sees the actual authored Loadmaster chair SIT prompt")
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and _game._solo_crew_claim_is_current() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving chair reseat uses the already-owned cabin and fresh claim")
	if _navigator:
		_check(await _until(func(): return _objective_text().contains("AWAITING ROUTE HINT"), 3.0), "moving reseat clears the previous visible navigator acknowledgement")
	await _press(&"fire")
	_check(await _until(func(): return _role_effect_ready(_craft.get_navigator_ping_snapshot()) if _navigator else _manifest_receipts == 2, 3.0), "moving reseat reaches readiness once through its fresh crew stream")
	var claim := owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
	var sequence := maxi(int(claim.get("claim_sequence", 0)), int(owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
	_check(_craft.release_crew_role(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, CinderCargoHauler.NAVIGATOR_STATION_SEAT_ID if _navigator else CinderCargoHauler.LOADMASTER_STATION_SEAT_ID, sequence, int(claim.get("seat_generation", 0))).accepted, "existing role authority revokes the exact host chair lease")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled(), 8.0), "chair lease loss restores supported moving cabin body")
	_check(_craft.get_command_source() == helm and helm.get_stream_id() == cursor.stream and helm.get_delivery_generation() == cursor.delivery, "chair lease loss leaves the remote pilot producer unchanged")
	if _navigator:
		_fire_key(true)
	else:
		Input.action_press(&"fire")
	await _ticks(8)
	if _navigator:
		_fire_key(false)
	else:
		Input.action_release(&"fire")
	_check((_craft.get_navigator_ping_snapshot().get("receipt", {}) as Dictionary).is_empty() if _navigator else _manifest_receipts == 2, "unseated FIRE cannot reuse the revoked Loadmaster lease")
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	_check(await _until(func():
		var label := _game.hud.get("_interaction_label") as Label
		return _game.station_interaction_candidate is ShipCrewSeat and label != null and label.text.contains("SIT") and label.text.contains("NAVIGATOR" if _navigator else "LOADMASTER")
	, 3.0), "moving host sees the actual authored Loadmaster chair SIT prompt")
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_station_anchor()) and _game._solo_crew_claim_is_current() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving reentry after lease loss reacquires only the host chair")
	_print_host_loadmaster_state(&"before_reentry_invariant", local_source, profile, profile_values, area, helm_weak)
	_check(area.get_reservation_token() == _player and _craft.get_command_source() == helm and _craft.get_local_input_source() == local_source and local_source.is_input_configuration_valid() and local_source.get_input_binding_profile().to_dictionary() == profile_values, "reentry preserves exact reservation, remote helm and configured local source")
	_write("host.flight_checked", {})
	if not await _wait_file("client.disconnected", 20.0):
		return
	_check(await _until(func(): return not _craft.is_remote_piloted() and _craft.get_command_source() == local_source and helm_weak.get_ref() == null, 5.0), "real peer disconnect restores the exact retained local producer through the existing helm owner")
	_check(_game._solo_crew_claim_is_current(), "remote pilot disconnect preserves the independent host Loadmaster claim")
	await _press(&"fire")
	_check(await _until(func(): return _role_effect_ready(_craft.get_navigator_ping_snapshot()) if _navigator else _manifest_receipts == 3, 3.0), "host readiness remains usable after the remote helm is released")
	_print_host_loadmaster_state(&"before_final_invariant", local_source, profile, profile_values, area, helm_weak)
	_check(_cargo_state() == _cargo_before and _craft.get_local_input_source() == local_source and local_source.is_input_configuration_valid() and local_source.get_input_binding_profile().to_dictionary() == profile_values, "full moving chair lifecycle preserves finite cargo and the settings-configured input profile")

## Read-only named-owner and predicate values for the unchanged moving checks.
func _print_host_loadmaster_state(stage: StringName, local_source: LocalShipInputSource, baseline_profile: int, baseline_profile_values: Dictionary, area: ShipBoardingArea, helm_weak: WeakRef = null) -> void:
	var cargo: Dictionary = _cargo_state()
	var binding: Node = _game._get_nearby_activity_binding()
	var configured: LocalShipInputSource = _craft.get_local_input_source()
	var selected: ShipCommandSource = _craft.get_command_source()
	var remote: NetworkRemotePilotCommandSource = selected as NetworkRemotePilotCommandSource
	var last_command: ShipCommand = _craft.get_last_ship_command()
	var configured_profile: InputBindingProfile = configured.get_input_binding_profile()
	var configured_profile_values: Dictionary = configured_profile.to_dictionary() if configured_profile != null else {}
	var helm: Object = helm_weak.get_ref() if helm_weak != null else null
	print("LOADMASTER_HOST_STATE: stage=", stage,
		" baseline_cargo=", _cargo_before, " current_cargo=", cargo,
		" cargo_equal=", cargo == _cargo_before,
		" nearby_cinder_binding=", binding,
		" finite_cargo_owner=", _game.cargo_transfer_authority,
		" baseline_profile_generation=", baseline_profile,
		" current_profile_generation=", local_source.get_input_profile_generation(),
		" profile_generation_equal=", local_source.get_input_profile_generation() == baseline_profile,
		" retained_local_source=", local_source, " configured_local_source=", configured,
		" retained_source_equal=", configured == local_source,
		" configured_profile=", configured_profile,
		" baseline_profile_values=", baseline_profile_values,
		" configured_profile_values=", configured_profile_values,
		" profile_values_equal=", configured_profile_values == baseline_profile_values,
		" input_configuration_valid=", local_source.is_input_configuration_valid(),
		" input_transform_snapshot=", local_source.get_input_transform_snapshot(),
		" input_provider=", local_source.get_input_provider(),
		" selected_source=", selected, " expected_helm=", helm,
		" remote_command_audit=", remote.get_audit() if remote != null else {},
		" last_consumed_command=", last_command.to_dictionary() if last_command != null else {},
		" selected_helm_equal=", selected == helm,
		" remote_piloted=", _craft.is_remote_piloted(),
		" reservation_token=", area.get_reservation_token(),
		" expected_player=", _player, " reservation_equal=", area.get_reservation_token() == _player,
		" telemetry=", _craft.get_telemetry(),
		" engine_online=", _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE,
		" velocity=", _craft.velocity)

func _client_loadmaster_pilot() -> void:
	var anchor := _craft.get_pilot_seat_anchor()
	await _walk(_craft.to_local(anchor.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(anchor.global_position)
	await _press(&"interact")
	_check(await _until(func(): return bool(_game.get("_piloting")) and not bool(_game.get("_transition_busy")), 12.0), "ordinary cockpit Interact swaps the admitted client berth for the real pilot seat")
	if not bool(_game.get("_piloting")):
		return
	_check(_game._network_client_boarding_claim.get("role") == &"pilot", "confirmed client owns the production pilot boarding receipt")
	# The authored flight controls are demand-driven: throttle is the ordinary
	# engine-start demand, not a separate engine toggle or forced state.
	Input.action_press(&"move_forward", 1.0 if _host_gunner_flight else 0.15)
	_check(await _until(func(): return _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE, 5.0), "ordinary client throttle wakes its confirmed flight engine")
	_check(await _until(func(): return _craft.velocity.length() > 0.1, 5.0), "ordinary client throttle drives the confirmed craft helm")
	_write("client.moving", {})
	if not await _wait_file("host.flight_checked", 60.0):
		Input.action_release(&"move_forward")
		return
	Input.action_release(&"move_forward")
	_game.shutdown_network_session(&"moving_loadmaster_pilot_disconnect")
	_write("client.disconnected", {})

func _cargo_state() -> Dictionary:
	var binding := _game._get_nearby_activity_binding()
	return {"cinder_stream_loaded": binding != null,
		"cinder": binding.get_cargo_transfer_authority().to_dictionary() if binding != null else {},
		"jovian": _game.cargo_transfer_authority.to_dictionary(),
		"finite_source": _game.cargo_transfer_authority.get_quantity(_game.get("_cargo_delivery_source_handle"), GameFlow.CARGO_DELIVERY_ITEM_ID),
		"capacity": _craft.get_cargo_capacity() if _cinder else 0,
	}

func _walk(target_local: Vector3) -> void:
	var start := _player.global_position
	var furthest := 0.0
	var source := _game.get_network_remote_body_intent_source()
	var settle_authoritative := (_ember_surface or _shared_cruise) and _role in ["client", "client_b"] \
		and source != null and source.is_bound()
	var source_entity := source.get_entity_id() if settle_authoritative else &""
	var source_generation := source.get_entity_generation() if settle_authoritative else 0
	var source_stream := int(source.get_audit().get("stream_id", -1)) if settle_authoritative else -1
	var frame := _craft.get_moving_interior_component() as MovingInteriorFrame
	var settled_ticks := 0
	var sample_authoritative_waypoint := func() -> Dictionary:
		var latest := _game.network_session.get_moving_interior_latest_relationship(source_entity)
		var current: bool = source.is_bound() and source.get_entity_id() == source_entity \
			and source_entity == GameFlow.network_client_boarding_avatar_id(_game._network_client_peer_id()) \
			and source.get_entity_generation() == source_generation \
			and int(source.get_audit().get("stream_id", -1)) == source_stream \
			and is_instance_valid(frame) and frame == _craft.get_moving_interior_component() \
			and frame.is_occupant_registered(_player) and frame._local_prediction_is_current(_player) \
			and latest.get("entity_id") == source_entity \
			and int(latest.get("entity_generation", 0)) == source_generation \
			and latest.get("parent_frame_id") == StringName("frame_%s" % _craft.get_ship_id()) \
			and int(latest.get("parent_frame_generation", 0)) == 1 \
			and int(latest.get("occupancy_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING
		var authoritative := latest.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D
		var authoritative_delta := _craft.to_global(target_local) - _craft.to_global(authoritative.origin)
		return {"current": current, "delta": authoritative_delta.slide(_craft.global_basis.y.normalized())}
	_print_walk_support("start", target_local)
	for _index in 240:
		furthest = maxf(furthest, _player.global_position.distance_to(start))
		var delta := _craft.to_global(target_local) - _player.global_position
		delta = delta.slide(_craft.global_basis.y.normalized())
		var authoritative_sample: Dictionary = sample_authoritative_waypoint.call() if settle_authoritative else {}
		var current: bool = bool(authoritative_sample.get("current", false))
		var authoritative_delta: Vector3 = authoritative_sample.get("delta", Vector3.ZERO)
		if delta.length() < 0.30 and (not settle_authoritative or not current or authoritative_delta.length() < 0.30):
			if not settle_authoritative:
				break
			# A predicted arrival is provisional: late reconciliation can move the
			# body away after input release. Keep ordinary feedback in this SAME
			# 240-iteration budget, resuming input if that happens. The existing
			# fifteen neutral settling ticks belong inside this loop as well.
			for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				Input.action_release(action)
			await _ticks(1)
			delta = (_craft.to_global(target_local) - _player.global_position).slide(_craft.global_basis.y.normalized())
			authoritative_sample = sample_authoritative_waypoint.call()
			current = bool(authoritative_sample.get("current", false))
			authoritative_delta = authoritative_sample.get("delta", Vector3.ZERO)
			var settled: bool = delta.length() < 0.30 and current \
				and authoritative_delta.length() < 0.30 \
				and _player.is_on_floor() and _player.velocity.slide(_craft.global_basis.y.normalized()).length() < 0.1
			settled_ticks = settled_ticks + 1 if settled else 0
			if settled_ticks >= 15:
				break
			continue
		settled_ticks = 0
		if settle_authoritative and current:
			# Both bodies receive this ordinary input. Steering their mean error
			# toward the SAME waypoint avoids a neutral dead zone when only the
			# prediction has arrived, within production correction tolerance.
			delta = (delta + authoritative_delta) * 0.5
			# A delayed pose can oppose the local error. Keep ordinary input
			# toward the SAME target when their mean numerically cancels.
			if delta.is_zero_approx():
				delta = authoritative_delta
		var forward := (-_player.get_camera().global_basis.z).slide(_craft.global_basis.y.normalized()).normalized()
		var right := forward.cross(_craft.global_basis.y.normalized()).normalized()
		var direction := delta.normalized()
		var axis := Vector2(direction.dot(right), -direction.dot(forward))
		# Slow an ordinary analog walk near the authored pose. At low render
		# cadence several real physics steps can run between input refreshes.
		if _cinder or _host_gunner_flight or _shared_cruise or _ember_surface:
			axis *= clampf(delta.length() / 1.5, 0.6, 1.0)
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		Input.action_press(&"move_left" if axis.x < 0.0 else &"move_right", absf(axis.x))
		Input.action_press(&"move_forward" if axis.y < 0.0 else &"move_back", absf(axis.y))
		if _cinder:
			await physics_frame
		else:
			await _ticks(1)
	if _shared_cruise:
		_print_walk_support("release", target_local)
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	if settle_authoritative:
		if settled_ticks < 15:
			print("PASSENGER_WALK_UNSETTLED: role=", _role, " target=", target_local,
				" settled_ticks=", settled_ticks, " authoritative_sample=", sample_authoritative_waypoint.call())
		_check(settled_ticks >= 15, "ordinary client walk settles at the same authoritative waypoint within its original input budget")
	elif _cinder:
		_check(await _until(func(): return _player.is_on_floor() and _player.velocity.slide(_craft.global_basis.y.normalized()).length() < 0.1, 3.0), "ordinary Cinder walk settles on actual cabin support")
	else:
		await _ticks(15)
	if _role in ["client", "client_b"]:
		print("PASSENGER_WALK_END: role=", _role, " wall=", Time.get_unix_time_from_system(), " local=", _craft.to_local(_player.global_position),
			" furthest_world_distance_m=", furthest, " floor=", _player.is_on_floor(), " yaw=", _player.get_look_yaw(),
			" source=", source.get_audit(), " relationship=", _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id()))

	_print_walk_support("end", target_local)

func _print_walk_support(boundary: String, target: Vector3) -> void:
	var frame := _craft.get_moving_interior_component() as MovingInteriorFrame
	var source := _game.get_network_remote_body_intent_source()
	print("PASSENGER_WALK_SUPPORT: role=", _role, " boundary=", boundary, " wall=", Time.get_unix_time_from_system(), " ticks=", Engine.get_physics_frames(), " local=", _craft.to_local(_player.global_position), " target=", target, " floor=", _player.is_on_floor(), " velocity=", _player.velocity, " controls=", _player.is_control_enabled(), " containment=", _player.get_cabin_containment_report(), " registered=", frame.is_occupant_registered(_player), " authority=", frame.is_simulation_authority_for(_player), " prediction=", frame._local_prediction_is_current(_player), " admission=", _game._network_local_cabin_prediction_is_current(_player, _craft, _game.network_session), " source=", source.get_audit() if source != null else {}, " relationship=", _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id()) if source != null else {})

func _look(target: Vector3) -> void:
	var target_local := _craft.to_local(target) if _host_gunner_flight or _shared_cruise or _ember_surface else Vector3.ZERO
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			_player._unhandled_input(click)
		var current_target := _craft.to_global(target_local) if _host_gunner_flight or _shared_cruise or _ember_surface else target
		var desired := _player.global_basis.inverse() * (current_target - (_player.get_interaction_origin() if _navigator or _shared_cruise or _ember_surface else _player.get_camera().global_position)).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		_player._unhandled_input(event)
		if _cinder:
			await physics_frame
		else:
			await _ticks(1)

func _press(action: StringName) -> void:
	if (_navigator or _gunner) and action == &"fire":
		_fire_key(true)
		await _ticks(2)
		_fire_key(false)
		await _ticks(3)
		if _gunner:
			_check(await _until(func(): return _objective_text().contains("LANCE FIRED") and _objective_text().contains("F13"), 3.0), "live remapped FIRE receives real lance acknowledgement")
			return
		_check(await _until(func(): return _objective_text().contains("NAVIGATOR") and _objective_text().contains("ROUTE HINT SENT") and _objective_text().contains("F13"), 3.0), "actual remapped FIRE receives visible authoritative navigator acknowledgement")
		return
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(3)

func _fire_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F13
	event.pressed = pressed
	Input.parse_input_event(event)

func _objective_text() -> String:
	return str((_game.hud.get("_objective_label") as Label).text).to_upper()

func _remap_navigator_fire() -> void:
	var profile := _game.runtime_settings.get_input_binding_profile()
	_check(profile.set_bindings(&"fire", [{"device": &"keyboard", "type": &"key", "physical_keycode": KEY_F13}]), "navigator fixture defines actual remapped FIRE")
	_game._on_setting_change_requested(&"input_binding_profile", profile)
	await _ticks(3)
	_check(_craft.get_local_input_source().get_input_binding_profile().get_bindings(&"fire") == profile.get_bindings(&"fire"), "retained Cinder input producer receives committed FIRE remapping")

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await _ticks(1)
	return false

func _ember_surface_seconds_remaining() -> float:
	return clampf(_ember_surface_total_deadline_unix - Time.get_unix_time_from_system(),
		0.0, EMBER_SURFACE_TOTAL_SECONDS)

func _ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func _wait_file(name: String, seconds: float) -> bool:
	var result := await _until(func(): return FileAccess.file_exists(_directory.path_join(name)) or ((name in ["host.ready", "host.rebased"] or (_ember_surface and name.begins_with("host."))) and FileAccess.file_exists(_directory.path_join("host.done"))), seconds)
	result = result and FileAccess.file_exists(_directory.path_join(name))
	_check(result, "peer boundary arrives: " + name)
	return result

func _write(name: String, data: Dictionary) -> void:
	var target := _directory.path_join(name)
	var temporary := target + ".tmp-" + str(OS.get_process_id())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_check(false, "peer receipt temporary file opens: " + name)
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, target) != OK:
		_check(false, "complete peer receipt publishes atomically: " + name)
		return
	print("PASSENGER_PEER_BOUNDARY: ", _role, " ", name, " wall=", Time.get_unix_time_from_system(), " ticks=", Engine.get_physics_frames())

func _read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_directory.path_join(name)):
		return {}
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(_directory.path_join(name))) != OK or not parsed.data is Dictionary:
		print("PASSENGER_INVALID_RECEIPT: ", name)
		return {}
	return parsed.data

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)

## Two actual ENet peers: an admitted passenger keeps its authoritative body
## while walking the supported caldera patch. The host alone performs the real
## authored survey; its durable manifest admits the ordinary same-body return.
func _ember_surface_host() -> void:
	_check(_game.host_network_session(_port).accepted, "terrain host starts actual ENet session")
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.to_global(Vector3(-3.10, 0.0, HalyardCrewTransport.AIRSTAIR_Z))))
	await _ticks(15)
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _craft.is_canopy_open(), 5.0), "ordinary host hatch opens real airstair")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	_write("host.ready", {})
	if not await _wait_file("client.cabin", 60.0):
		return
	var peer := int(_read("client.cabin").get("peer_id", 0))
	var avatar := _game.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	_check(is_instance_valid(body), "confirmed passenger has actual authoritative standing body")
	if not is_instance_valid(body):
		return
	var body_id := body.get_instance_id()
	var generation := int(simulation.get_body_record(avatar).get("entity_generation", 0))
	var admissions := int(simulation.get_audit().get("admitted", 0))
	var releases_before := int(simulation.get_audit().get("released", 0))
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._piloting and _player.is_seated_at(pilot) and not _game._transition_busy, 12.0), "ordinary host cockpit owns real pilot seat")
	if not _game._piloting:
		return
	var commands := _craft.get_command_source()
	# Stage the existing shared cruise's Mudds-side flight envelope. A craft
	# placed near Ember without a journey correctly gets the stranded-return HUD.
	# The whole canonical outbound leg now remains real after this initial setup.
	var frame := _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var destination: Vector3 = frame.orbital_to_world_streaming_position(
		_game.planetary_cruise_binding.get_snapshot().canonical_destination_orbital, frame.get_generation()).position
	var home: Vector3 = (_game.world.call(&"get_ship_spawn") as Transform3D).origin
	_craft.global_position = home + Vector3(0.0, 5000.0, -8640.0).normalized() * 9995.0
	_craft.global_basis = Basis.looking_at((destination - _craft.global_position).normalized(), Vector3.UP)
	_craft.velocity = Vector3.ZERO
	_game._sortie_departed_berth = true
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	_check(not _game._planetary_journey.stranded_return_available(),
		"actual Mudds-side envelope offers outbound cruise rather than stranded return")
	_write("host.flight_started", {})
	var request_serial: int = _game._last_hud_planetary_cruise_toggle_serial + 1
	var admission_before: Dictionary = _game._planetary_cruise_presentation()
	var admission_context := {
		"status": admission_before.get("status_id", &""),
		"public_gate": admission_before.get("public_gate", &""),
		"toggle_enabled": bool(admission_before.get("toggle_enabled", false)),
		"engagement_requested": bool(admission_before.get("engagement_requested", false)),
		"live_gate": _game._planetary_cruise_gate_reason(),
		"host_eligible": _game._shared_planetary_host_eligible(),
		"hud_busy": bool(_game._planetary_cruise_hud_toggle_active),
		"request_serial": request_serial,
		"shared_phase_before": _game.get_network_planetary_journey_snapshot().get("phase", &""),
		"surface_pending": not _game._pending_ember_surface_request.is_empty() or bool(_game._ember_surface_journey_active),
		"stranded_return_available": _game._planetary_journey.stranded_return_available(),
	}
	_game.hud.planetary_cruise_toggle_requested.emit(request_serial)
	var shared_phase: StringName = _game.get_network_planetary_journey_snapshot().get("phase", &"")
	if shared_phase not in [&"preparing", &"cruising"]:
		admission_context["shared_phase_after"] = shared_phase
		admission_context["consumed_serial"] = _game._last_hud_planetary_cruise_toggle_serial
		print("EMBER_PASSENGER_HUD_ADMISSION_REFUSED: %s" % JSON.stringify(admission_context))
	_check(shared_phase in [&"preparing", &"cruising"],
		"ordinary HUD prepares shared cruise with real admitted passenger")
	var journey = _game.get("_planetary_journey")
	var host := _game.ember_surface_loop_host
	var production := _game.ember_surface_loop_production_binding
	# The old 120-second combined wait covered only a near-Ember fixture.
	# Canonical transit uses remaining total time; physical landing keeps 120.
	var approached := await _until(func(): return bool(journey.get_shared_ember_landing_snapshot().get("handoff_ready", false)),
		_ember_surface_seconds_remaining())
	_check(approached, "real canonical outbound reaches current typed approach completion")
	if not approached:
		return
	_write("host.approaching", {})
	_check(await _until(func(): return journey.shared_ember_surface_is_current(), 120.0), "genuine typed approach and supported landing admit shared visit")
	if not journey.shared_ember_surface_is_current():
		return
	_check(host._landed_public_state_is_exact(), "actual Host occupancy, lease and solid hull support remain exact")
	_check(await _until(func(): return host.get_phase() == EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 20.0), "Host physically disembarks standing pilot")
	var departure_result: Dictionary = {}
	var observe_departure := func(result: Dictionary) -> void:
		var caller := _game.network_session.multiplayer.get_remote_sender_id()
		if caller == peer:
			departure_result.clear()
			departure_result.merge({"caller_peer_id": caller, "accepted": result.get("accepted"),
				"status": result.get("status"), "reason": result.get("reason"), "sequence": result.get("sequence")})
	_game.network_session.boarding_intent_result.connect(observe_departure)
	_write("host.landed", {})
	var terrain_arrived := await _wait_file("client.terrain", 20.0)
	_game.network_session.boarding_intent_result.disconnect(observe_departure)
	if not terrain_arrived:
		var actual_body := simulation.get_body(avatar) as PlayerController
		var record := simulation.get_body_record(avatar)
		var host_visit := _game.get_network_planetary_journey_snapshot()
		var telemetry := _craft.get_telemetry()
		var hatch_audit := _game.get_network_remote_body_audit()
		print("EMBER_PASSENGER_HOST_DEPARTURE_FAILED: %s" % JSON.stringify({
			"boarding_result": departure_result, "expected_peer_id": peer,
			"body_id": actual_body.get_instance_id() if is_instance_valid(actual_body) else 0,
			"body_owner": record.get("owner_peer_id"), "entity_generation": record.get("entity_generation"),
			"seat_state": record.get("seat_state"), "last_interaction_id": record.get("last_interaction_id"),
			"frozen": record.get("frozen"), "local_position": _craft.to_local(actual_body.global_position) if is_instance_valid(actual_body) else null,
			"floor": actual_body.is_on_floor() if is_instance_valid(actual_body) else false,
			"at_hatch": _game._network_ember_passenger_at_hatch(actual_body, _craft, false),
			"host_current": _game._network_ember_passenger_host_is_current(_craft),
			"host_phase": host.get_phase(), "host_attached": host.is_attached(),
			"lease_exact": host._landed_public_state_is_exact(),
			"engine": telemetry.get("engine_state"), "landed": telemetry.get("landed"),
			"journey_epoch": host_visit.get("journey_epoch"), "journey_phase": host_visit.get("phase"),
			"last_hatch_status": hatch_audit.get("last_hatch_status"),
			"interactions": hatch_audit.get("interactions"), "interactions_refused": hatch_audit.get("interactions_refused"),
		}))
		return
	_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id
		and simulation.is_surface_walking(avatar) and _game._network_ember_passenger_surface_is_current(avatar)
		and not bool(body.get_cabin_containment_report().get("active", false))
		and body.is_on_floor() and not body.is_seated(), "confirmed departure keeps same supported authoritative exterior body")
	if not await _wait_file("client.return_refused", 20.0):
		return
	_check(_game.get_network_remote_body_audit().get("last_hatch_status") == &"surface_body_retained"
		and simulation.is_surface_walking(avatar) and not journey._ember_survey_return_is_admitted(production.get_snapshot()),
		"early ordinary return refuses before genuine survey without admitting a new body")
	var landing := _game.ember_streaming_bootstrap.get_loaded_instance().get_node("LandingRegion") as Node3D
	var route := host.get_snapshot().surface_route as Dictionary
	var bow: Array[Vector3] = [_craft.to_global(Vector3(-9.0, 0.0, -16.0)), _craft.to_global(Vector3(18.0, 0.0, -16.0))]
	_check(await _ember_walk_world(route.egress_anchor, 20.0, bow)
		and await _ember_walk_world(route.staging_anchor, 20.0), "host walks ordered real egress and staging within original leg caps")
	if not _failures.is_empty():
		return
	_check(await _until(func(): return production.get_planetary_surface_snapshot().adapter.activity_reward.state == &"active", 4.0), "host on-foot observations start genuine authored survey")
	_check(await _ember_walk_world(landing.to_global(Vector3(160.0, 0.0, -30.0)), 50.0), "ordinary host walk reaches actual mandatory tower")
	_check(await _until(func(): return int(_game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get("next_checkpoint_index", 0)) == 1, 4.0), "Director consumes genuine first checkpoint")
	var survey_generation := int(_game.activity_director.get_activity_snapshot(&"ember_beacon_survey").get("generation", 0))
	var completed := func() -> bool:
		var activity := _game.activity_director.get_activity_snapshot(&"ember_beacon_survey")
		return int(activity.get("generation", -1)) == survey_generation \
			and int(activity.get("state", -1)) == CheckpointRouteActivity.State.COMPLETED \
			and int(activity.get("next_checkpoint_index", -1)) == 2
	_check(await _ember_walk_world(landing.to_global(Vector3(540.0, 30.0, -210.0)), 100.0, [], completed),
		"ordinary host walk completes both genuine checkpoints in the current Director generation")
	_check(await _until(func(): return production.get_planetary_surface_snapshot().adapter.activity_reward.state == &"completed", 4.0), "genuine final observation completes and saves survey")
	if not _failures.is_empty():
		return
	var surface := production.get_planetary_surface_snapshot()
	var reward: Dictionary = production.get_snapshot().relay_reward_commit
	var store := _game._runtime_settings_user_data_store
	var reader := UserDataStore.new(str(store.get("_path")))
	var persistence := EmberRelaySurveyPersistenceBinding.new()
	var configured := persistence.configure(reader, GameFlow.EMBER_RELAY_SURVEY_PERSISTENCE_SLOT)
	var captured := persistence.capture(surface)
	var loaded := reader.load_read_only()
	var saved := reader.get_snapshot()
	var ledger := saved.get("game_flow_reward_store", {}) as Dictionary
	_check(configured.accepted and captured.accepted and loaded.accepted
		and reader.get_loaded_source() == &"primary" and reader.get_generation() == store.get_generation()
		and saved.get("ember_relay_survey_completion", {}) == captured.record
		and int(reward.authority_commit_count) == 1 and int(reward.persistence_commit_count) == 1
		and int(ledger.get("total_receipts", 0)) == 1
		and int((ledger.get("reward_counts", {}) as Dictionary).get("ember_beacon_data", 0)) == 1,
		"independent disk read retains actual completed survey and exactly one reward")
	_check(await _until(func(): return journey._ember_survey_return_is_admitted(production.get_snapshot()), 4.0), "host current durable survey manifest admits ordinary passenger return")
	if not _failures.is_empty():
		return
	var saved_generation := store.get_generation()
	_write("host.return_ready", {})
	if not await _wait_file("client.reboarded", 20.0):
		return
	_check(simulation.get_body(avatar) == body and body.get_instance_id() == body_id
		and int(simulation.get_body_record(avatar).get("entity_generation", -1)) == generation
		and int(simulation.get_audit().get("admitted", -1)) == admissions
		and not simulation.is_surface_walking(avatar)
		and bool(body.get_cabin_containment_report().get("active", false)) and body.is_on_floor(),
		"ordinary manifest-gated hatch return restores containment on same host body without readmission")
	_check(_craft.get_command_source() != null and _game._piloting and not _player.is_seated()
		and (_game.network_session.get_boarding_snapshot().get("occupancies", []) as Array).any(func(held: Dictionary): return int(held.get("peer_id", 0)) == peer and held.get("role") == GameFlow.NETWORK_CABIN_BERTH_ROLE),
		"returning passenger owns only cabin berth while standing host retains pilot ledger")
	_write("host.reboard_seen", {})
	if _ember_surface_loss:
		if not await _wait_file("client.world_lost", 20.0):
			return
		# Destroy the actual visit world, not a lease/Host/receipt field. Existing
		# production lifetime guards must retire authority and notify the peer.
		_game.ember_streaming_bootstrap.get_loaded_instance().queue_free()
		_check(await _until(func(): return simulation.get_body_count() == 0 \
			and _game._network_ember_passenger_surfaces.is_empty(), 5.0)
			and int(simulation.get_audit().get("released", -1)) - releases_before == 1
			and _game.network_session.get_movement_avatar_snapshot(avatar).is_empty()
			and _game.network_session.get_admitted_peer_ids().has(peer),
			"actual terrain loss releases exactly one body while the peer remains admitted")
		if not await _wait_file("client.recovered", 20.0):
			return
		var after_loss := UserDataStore.new(str(store.get("_path")))
		_check(after_loss.load_read_only().accepted and after_loss.get_snapshot() == saved
			and store.get_generation() == saved_generation,
			"visit loss and explicit recovery preserve genuine durable survey manifest and once-only reward")
		return
	if not await _wait_file("client.disconnected", 20.0):
		return
	_check(await _until(func(): return simulation.get_body_count() == 0 and _game._network_ember_passenger_surfaces.is_empty(), 5.0)
		and int(simulation.get_audit().get("released", -1)) - releases_before == 1,
		"actual exterior disconnect releases exactly one retained body and clears its surface lifetime")
	_check(store.get_generation() == saved_generation and int(production.get_snapshot().relay_reward_commit.persistence_commit_count) == 1,
		"passenger departure, return and disconnect cannot write another host reward")
	_check(commands == host.get("_original_command_source"), "passenger route preserves original pilot command owner")

func _ember_surface_client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "independent terrain client joins actual host")
	if not await _until(_admitted_session_ready, 60.0):
		_check(false, "terrain passenger receives authenticated admission")
		return
	# Existing initial yard hatch staging; every landed exterior step below is Input.
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not _game._transition_busy, 12.0), "ordinary passenger boarding confirms actual walking body")
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
	var epoch := int(_game.get_network_planetary_journey_snapshot().get("journey_epoch", 0))
	_check(await _until(func(): return _game._network_client_ember_surface_scene_is_current(_craft, epoch), 12.0), "authenticated landed state and real loaded surface select exterior route")
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _look(hatch.global_position)
	var before := source.get_audit()
	await _press(&"interact")
	var departure_confirmed := await _until(func(): return _game._network_client_ember_passenger_surface_is_current(), 12.0)
	_check(departure_confirmed, "ordinary hatch press waits for host-confirmed exterior departure")
	if not departure_confirmed:
		var source_audit := source.get_audit()
		var boarding := _game.get_network_client_boarding_audit()
		var answer := _game.network_session.get_boarding_intent_result_replica()
		var visit := _game.get_network_planetary_journey_snapshot()
		var operation := _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()).get("operation_presentation", {}) as Dictionary
		var target: Node = _game.station_interaction_candidate
		print("EMBER_PASSENGER_CLIENT_DEPARTURE_FAILED: %s" % JSON.stringify({
			"request_serial": boarding.get("sequence"), "request_pending": boarding.get("request_pending"),
			"last_status": boarding.get("last_status"), "requests": boarding.get("requests"),
			"refusals": boarding.get("refusals"), "timeouts": boarding.get("timeouts"),
			"answer_serial": answer.get("sequence"), "answer_action": answer.get("action"),
			"answer_accepted": answer.get("accepted"), "answer_status": answer.get("status"), "answer_reason": answer.get("reason"),
			"source_entity": source_audit.get("entity_id"), "source_generation": source_audit.get("entity_generation"),
			"source_stream": source_audit.get("stream_id"), "source_sequence": source_audit.get("sequence"),
			"source_bound": source_audit.get("bound"), "corrections": source_audit.get("corrections"),
			"interaction_id_before": before.get("interaction_request_id"), "interaction_id_after": source_audit.get("interaction_request_id"),
			"target": str(target.get_path()) if is_instance_valid(target) else "",
			"hatch_nearby": _player.get_nearby_interactables().has(hatch), "hatch_reach": _player.get_interaction_origin().distance_to(hatch.global_position),
			"local_position": _craft.to_local(_player.global_position), "floor": _player.is_on_floor(), "controls": _player.is_control_enabled(),
			"cabin_ship_current": _game._cabin_ship == _craft, "secure_surface_current": _game._network_client_ember_surface_scene_is_current(_craft, epoch),
			"engine": operation.get("engine"), "landed": operation.get("landed"),
			"journey_epoch": visit.get("journey_epoch"), "journey_phase": visit.get("phase"),
		}))
	if not _game._network_client_ember_passenger_surface_is_current():
		return
	var old_departure := _game.network_session.get_boarding_intent_result_replica()
	_check(bool(old_departure.get("accepted", false)) and old_departure.get("status") == &"disembarked"
		and old_departure.get("avatar_id") == source.get_entity_id(), "capture real host-accepted exterior departure answer")
	var retired_prediction := Callable(_game, "_network_local_ember_passenger_prediction_is_current").bind(_game._network_client_ember_passenger_surface)
	_check(_player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and not bool(_player.get_cabin_containment_report().get("active", false)), "departure retains local body, entity generation and predictor stream without placement")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(-8.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	_check(_player.is_on_floor() and _game._network_client_ember_passenger_surface_is_current()
		and _craft.to_local(_player.global_position).x < -5.0 and source.get_audit().sequence > before.sequence,
		"ordinary Input walks same supported body down airstair onto real caldera patch")
	_write("client.terrain", {})
	# Walk back physically before asking; the manifest, rather than proximity,
	# must still refuse this supported same-body return before the host survey.
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game.get_network_client_boarding_audit().get("last_status") == &"surface_survey_return_pending", 12.0)
		and _game._network_client_ember_passenger_surface_is_current() and source.is_bound()
		and not _game._network_client_boarding_holds(_craft), "early ordinary hatch return is refused by actual durable survey gate")
	_write("client.return_refused", {})
	if not await _wait_file("host.return_ready", 240.0):
		return
	before = source.get_audit()
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._network_client_boarding_holds(_craft) and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN, 12.0), "ordinary hatch return confirms cabin only after host saved survey manifest")
	_check(_player.get_instance_id() == body_id and _game.get_network_remote_body_intent_source() == source
		and source.get_audit().stream_id == before.stream_id and source.get_audit().entity_generation == before.entity_generation
		and source.get_audit().sequence > before.sequence
		and bool(_player.get_cabin_containment_report().get("active", false))
		and not _player.is_seated() and not _game._piloting,
		"return retains same actual body, ordered predictor and passenger authority")
	var old_boarding := _game.network_session.get_boarding_intent_result_replica()
	_check(bool(old_boarding.get("accepted", false)) and old_boarding.get("status") == &"boarded"
		and old_boarding.get("avatar_id") == source.get_entity_id(), "capture real host-accepted same-body return answer")
	_write("client.reboarded", {})
	if not await _wait_file("host.reboard_seen", 20.0):
		return
	# A second genuine hatch exit leaves the same exterior lifetime active at
	# actual disconnect, so cleanup tests the new route rather than cabin cleanup.
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _game._network_client_ember_passenger_surface_is_current(), 12.0)
		and not bool(retired_prediction.call()), "second ordinary exit retains body without reviving first departure admission")
	var current_answer := _game.network_session.get_boarding_intent_result_replica()
	_check(int(old_departure.get("sequence", -1)) < int(old_boarding.get("sequence", -1))
		and int(old_boarding.get("sequence", -1)) < int(current_answer.get("sequence", -1)),
		"captured genuine answers precede the current confirmed departure")
	var current_context := _game._network_client_ember_passenger_surface.duplicate(true)
	var current_predictor := source.get_audit()
	var current_pose := _player.global_transform
	var confirmations := int(_game.get_network_client_boarding_audit().get("confirmations", 0))
	# Replay the exact accepted answers delivered by the real host through the
	# production signal/callback path, without making a new ledger decision.
	for answer: Dictionary in [old_departure, old_boarding]:
		_game.network_session.boarding_intent_result.emit(answer.duplicate(true))
	_check(_game._network_client_ember_passenger_surface == current_context
		and _game._network_client_ember_passenger_surface_is_current()
		and _player.get_instance_id() == body_id and _player.global_transform == current_pose
		and _game.get_network_remote_body_intent_source() == source and source.get_audit() == current_predictor
		and source.is_bound() and not _game._network_client_boarding_holds(_craft)
		and _game.phase == GameFlow.Phase.APPROACH_SHIP
		and int(_game.get_network_client_boarding_audit().get("confirmations", -1)) == confirmations,
		"real old departure and return answers cannot mutate the current exterior body, context or ordered predictor")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(-8.0, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	var stale := Callable(_game, "_network_local_ember_passenger_prediction_is_current").bind(_game._network_client_ember_passenger_surface)
	var surface_position := _player.global_position
	if _ember_surface_loss:
		var retirements: Array[Dictionary] = []
		var recovery_messages: Array[String] = []
		var received_retirement := func(packet: Dictionary) -> void:
			if packet.get("phase") == &"retired":
				retirements.append(packet.duplicate(true))
				recovery_messages.append(str((_game.hud.get("_toast_title") as Label).text))
		_game.network_session.planetary_journey_state_received.connect(received_retirement)
		var local_scene := _game.ember_streaming_bootstrap.get_loaded_instance()
		if _ember_surface_loss_authority_first:
			_check(_game._network_client_ember_passenger_surface_is_current() and _player.is_on_floor(),
				"authority-first loss starts with actual current supported client terrain")
		else:
			# Local loss arrives first. It may revoke prediction, but must not
			# grant recall until the real server retires this exact visit.
			local_scene.queue_free()
			_check(await _until(func(): return _game._network_client_ember_passenger_surface.is_empty() \
				and not _game._network_client_ember_passenger_retired.is_empty(), 4.0)
				and not source.is_bound() and not bool(stale.call()) and retirements.is_empty()
				and _player.get_instance_id() == body_id
				and _player.global_position.distance_to((_game.world.call(&"get_player_spawn") as Transform3D).origin) > 1_000_000.0,
				"local terrain loss revokes stale prediction while retaining identity without recovery authority")
		_write("client.world_lost", {})
		_check(await _until(func(): return not retirements.is_empty() and _player.is_on_floor() \
			and _player.is_control_enabled() and _game._network_client_ember_passenger_retired.is_empty(), 20.0)
			and _game._network_client_boarding_is_live() and _player.get_instance_id() == body_id
			and not source.is_bound() and not bool(stale.call()) and _game._cabin_ship == null
			and recovery_messages.has("CREW SAFE RECOVERY")
			and _player.global_position.distance_to((_game.world.call(&"get_player_spawn") as Transform3D).origin) < 2.0,
			"authenticated current visit retirement recalls the same supported usable actor without ending ENet")
		if retirements.is_empty():
			return
		if _ember_surface_loss_authority_first and is_instance_valid(local_scene) and not local_scene.is_queued_for_deletion():
			local_scene.queue_free()
		var recovered_pose := _player.global_transform
		var toast_serial: int = _game.hud.get("_toast_serial")
		var recovered_confirmations := int(_game.get_network_client_boarding_audit().get("confirmations", 0))
		_game.network_session.planetary_journey_state_received.emit(retirements[0].duplicate(true))
		for answer: Dictionary in [old_departure, old_boarding]:
			_game.network_session.boarding_intent_result.emit(answer.duplicate(true))
		_check(_player.global_transform == recovered_pose and not source.is_bound() and not bool(stale.call())
			and _game._network_client_ember_passenger_surface.is_empty()
			and _game._network_client_ember_passenger_retired.is_empty()
			and not _game._network_client_boarding_holds(_craft)
			and source.advance(_game._network_client_peer_id(), {}, _game.network_session.get_moving_interior_latest_server_tick()).is_empty()
			and int(_game.hud.get("_toast_serial")) == toast_serial
			and int(_game.get_network_client_boarding_audit().get("confirmations", -1)) == recovered_confirmations,
			"real duplicate retirement and old boarding answers cannot repeat recovery or revive exterior authority")
		_game.network_session.planetary_journey_state_received.disconnect(received_retirement)
		await _ticks(3)
		_check(_player.is_on_floor() and _player.is_control_enabled() and _game._network_client_boarding_is_live()
			and _game._network_client_ember_passenger_retired.is_empty(),
			"recovery remains supported and usable after subsequent local terrain retirement")
		_write("client.recovered", {})
		return
	_game.shutdown_network_session(&"terrain_passenger_disconnect")
	_check(not source.is_bound() and _game._network_client_ember_passenger_surface.is_empty()
		and not bool(stale.call()) and _player.is_control_enabled()
		and _player.global_position.distance_to(surface_position) < 0.01,
		"actual disconnect retires predictor and stale admission without a Mudds teleport")
	_write("client.disconnected", {})

func _ember_walk_world(target: Vector3, seconds: float, via: Array[Vector3] = [], completed: Callable = Callable()) -> bool:
	var waypoints: Array[Vector3] = via.duplicate()
	waypoints.append(target)
	var index := 0
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if completed.is_valid() and completed.call() == true:
			_ember_release_walk()
			return true
		var delta := (waypoints[index] - _player.global_position).slide(_player.up_direction)
		if delta.length() <= 1.5:
			if index == waypoints.size() - 1:
				_ember_release_walk()
				if not completed.is_valid():
					return true
				await physics_frame
				continue
			index += 1
			continue
		var camera := _player.get_node("%CameraYaw") as Node3D
		var forward := -camera.global_basis.z.slide(_player.up_direction).normalized()
		var right := camera.global_basis.x.slide(_player.up_direction).normalized()
		var direction := delta.normalized()
		var axes := Vector2(direction.dot(right), -direction.dot(forward))
		_ember_release_walk()
		Input.action_press(&"move_right" if axes.x > 0.0 else &"move_left", absf(axes.x))
		Input.action_press(&"move_back" if axes.y > 0.0 else &"move_forward", absf(axes.y))
		await physics_frame
	_ember_release_walk()
	print("EMBER_PASSENGER_WALK_FAILED: role=", _role, " position=", _player.global_position, " waypoint=", waypoints[index], " floor=", _player.is_on_floor())
	return false

func _ember_release_walk() -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)

# Shared Ember orbit: actual Main, independent Input/frame clocks, two physical
# cabin admissions before cruise and a third observer joining after origin shift.
func _shared_host() -> void:
	_check(_game.host_network_session(_port).accepted, "shared cruise production host starts")
	# The existing ordinary passenger lane's physical airstair entrance. The
	# generic boarding area would seat the host directly and close the hatch.
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.to_global(Vector3(-3.10, 0.0, HalyardCrewTransport.AIRSTAIR_Z))))
	await _ticks(15)
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _craft.is_canopy_open(), 5.0), "host ordinary airstair hatch Interact opens physical cabin")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	_write("host.ready", {})
	if not await _wait_file("client.cabin", 60.0) or not await _wait_file("client_b.cabin", 60.0):
		return
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	_game._refresh_interaction_targets()
	print("SHARED_HOST_COCKPIT_APPROACH: local=", _craft.to_local(_player.global_position), " phase=", _game.phase, " boarding=", _game.boarding_candidate, " candidate=", _game.station_interaction_candidate, " near=", _player.get_nearby_interactables(), " floor=", _player.is_on_floor())
	await _press(&"interact")
	_check(await _until(func(): return _game._piloting and _player.is_seated_at(pilot) and not _game._transition_busy, 12.0), "host ordinary cockpit Interact owns the actual pilot seat")
	if not _game._piloting:
		return
	_check(_game._network_remote_body_simulation.get_body_count() == 2, "two real crew bodies exist on host before planetary travel")
	# The boarding route above is physical. Stage only the flight envelope, as
	# the existing cruise activation test does; travel/rebase remain real physics.
	var frame: PlanetaryCoordinateFrame = _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var destination := frame.orbital_to_world_streaming_position(_game.planetary_cruise_binding.get_snapshot().canonical_destination_orbital, frame.get_generation())
	_craft.global_position = Vector3(0.0, 5000.0, -8640.0).normalized() * 9995.0
	_craft.global_basis = Basis.looking_at((destination.position - _craft.global_position).normalized(), Vector3.UP)
	_craft.velocity = Vector3.ZERO
	_game._sortie_departed_berth = true
	_game.phase = GameFlow.Phase.FREE_FLIGHT
	_game._sync_planetary_cruise_hud()
	await _ticks(12)
	_check(_game._shared_planetary_host_eligible(), "real host pilot claim admits only shared orbit lane")
	_check(_game._planetary_cruise_presentation().status_text == "READY — SHARED EMBER LANDING", "ordinary HUD honestly names the authenticated shared Ember landing")
	_check(not _game.begin_ember_surface_journey(_game.ember_surface_loop_host, _game.activity_director, Callable(_game, "_commit_game_flow_activity_reward"), 1).accepted, "direct solo surface admission cannot bypass the authenticated shared host entry point")
	# One real client acknowledges and then loses the journey-state stream;
	# another has not acknowledged yet. Advance the physical origin manually,
	# then restore only the second: an old first acknowledgement must not start.
	# Face outward for this manual origin crossing rather than relying on a
	# partial throttle to overcome the still-active shipyard gravity field.
	_craft.global_basis = Basis.looking_at(_craft.global_position.normalized(), Vector3.UP)
	_game.hud.planetary_cruise_toggle_requested.emit(1)
	if not await _wait_file("client.ack_held", 10.0):
		return
	var preparation_frame := frame.get_generation()
	Input.action_press(&"move_forward")
	var preparation_rebased := await _until(func(): return frame.get_generation() > preparation_frame, 6.0)
	Input.action_release(&"move_forward")
	print("SHARED_PREPARATION_ORIGIN: committed=", preparation_rebased, " position=", _craft.global_position, " velocity=", _craft.velocity, " telemetry=", _craft.get_telemetry(), " journey=", _game.get_network_planetary_journey_snapshot())
	_check(preparation_rebased, "ordinary host throttle commits an origin while crew preparation is pending")
	if not preparation_rebased:
		return
	_write("host.restore_b", {})
	_check(await _until(func(): return _game.get_network_planetary_journey_snapshot().get("ready_peers", []).size() == 1, 3.0), "fresh second peer acknowledges new preparation origin without reviving first old acknowledgement")
	_check(_game.get_network_planetary_journey_snapshot().get("phase") == &"preparing" and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)), "stale pre-rebase readiness cannot start shared physical cruise")
	_check(await _until(func(): return not _game._network_planetary_journey.is_active(), 12.0), "unready actual peer reaches bounded production preparation timeout")
	_check(not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)), "preparation timeout leaves physical cruise unengaged")
	_write("host.restore_all", {})
	if not await _wait_file("client.ready_restored", 10.0) or not await _wait_file("client_b.ready_restored", 10.0):
		return
	# Prepare/cancel through the same ordinary HUD signal without yielding to
	# a physics tick, then wait for both real clients' reliable retirement.
	_game.hud.planetary_cruise_toggle_requested.emit(2)
	_game.hud.planetary_cruise_toggle_requested.emit(3)
	_check(not _game._network_planetary_journey.is_active() and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)), "ordinary queued HUD cancellation retires prepared journey before movement")
	_write("host.cancelled", {})
	if not await _wait_file("client.cancel_seen", 10.0) or not await _wait_file("client_b.cancel_seen", 10.0):
		return
	destination = frame.orbital_to_world_streaming_position(_game.planetary_cruise_binding.get_snapshot().canonical_destination_orbital, frame.get_generation())
	_craft.global_basis = Basis.looking_at((destination.position - _craft.global_position).normalized(), Vector3.UP)
	var source := _craft.get_command_source()
	var start := frame.world_streaming_to_orbital_position(_craft.global_position, frame.get_generation()).coordinate as Dictionary
	var initial_frame := frame.get_generation()
	var initial_crew_tick := _game._network_moving_interior_server_tick
	var readiness_strikes_before := (_game.network_session.get("_security_strikes") as Dictionary).duplicate()
	var pressure_drop := [false]
	_game.hud.planetary_cruise_toggle_requested.emit(4)
	_check(_game.get_network_planetary_journey_snapshot().phase == &"preparing", "ordinary HUD prepares authenticated crew readiness before cruise")
	_check(await _until(func():
		var pressure := _read("client.ready_pressure")
		var peer_id := int(pressure.get("peer_id", 0))
		var strikes := _game.network_session.get("_security_strikes") as Dictionary
		var counts := _game.network_session.get("_secure_window_counts") as Dictionary
		if peer_id > 0 and int(strikes.get(peer_id, 0)) > int(readiness_strikes_before.get(peer_id, 0)) \
				and int(counts.get(peer_id, 0)) >= _game.network_session.MAX_SECURE_PACKETS_PER_WINDOW:
			pressure_drop[0] = true
		return _game.get_network_planetary_journey_snapshot().get("phase") == &"cruising",
		12.0), "both real crew peers acknowledge production streaming readiness")
	_check(pressure_drop[0], "authenticated preparation pressure exhausts the actual secure packet budget and drops readiness admission")
	print("SHARED_READINESS_PRESSURE: dropped=", pressure_drop[0], " state=", _game.get_network_planetary_journey_snapshot(),
		" strikes=", _game.network_session.get("_security_strikes"))
	_check(await _until(func(): return frame.get_generation() > initial_frame, 35.0), "real cruise physics crosses existing ten-kilometre origin threshold and commits")
	var traveled := frame.orbital_to_world_streaming_position(start, frame.get_generation())
	_check(_craft.global_position.distance_to(traveled.position) > 8000.0 and _craft.velocity.length() > 50.0, "host craft physically travels before origin shift with nonzero cruise velocity")
	_check(_craft.get_command_source() == source and _game._network_remote_body_simulation.get_body_count() == 2, "real origin commit preserves pilot source and both actual crew bodies")
	_check(_game._network_moving_interior_server_tick > initial_crew_tick, "crew physics and publication continue through shared cruise")
	_write("host.rebased", {"origin_revision": frame.get_generation()})
	if not await _wait_file("client.walked", 60.0) or not await _wait_file("client_b.walked", 60.0):
		return
	if not await _wait_file("observer.observed", 60.0):
		return
	# Both crew use the same actual passenger chair in turn. A forged seat or
	# replica posture would not exercise the physical host ownership path.
	for role in ["client", "client_b"]:
		_write(role + ".chair_go", {})
		if not await _wait_file(role + ".chair_done", 60.0):
			return
		_check(_game._network_remote_body_simulation.get_body_count() == 2, "both crew remain admitted after ordinary stand and reseat: " + role)
	_write("host.finish", {})
	if not await _wait_file("client.disconnected", 30.0) or not await _wait_file("client_b.disconnected", 30.0):
		return
	_check(await _until(func(): return _game._network_remote_body_simulation.get_body_count() == 0, 5.0), "actual peer disconnect retires both travelling cabin bodies")
	_game.shutdown_network_session(&"shared_cruise_done")
	_check(_game.get_network_planetary_journey_snapshot().get("journey_epoch", 0) == 0 and _craft.get_command_source() == source, "session stop retires journey without replacing retained solo pilot input")

## Exhaust admission with authenticated but semantically stale requests in one
## receive burst, before production's first legitimate acknowledgement. No
## body, boarding claim, origin generation or authority is injected.
func _pressure_shared_preparation(packet: Dictionary) -> void:
	if _readiness_pressure_epoch <= 0 or int(packet.get("journey_epoch", 0)) != _readiness_pressure_epoch \
			or packet.get("phase") != &"preparing":
		return
	_readiness_pressure_epoch = 0
	for _index in _game.network_session.MAX_SECURE_PACKETS_PER_WINDOW:
		_game.network_session.send_planetary_journey_ready({
			"journey_epoch": -1, "origin_revision": int(packet.origin_revision),
			"world_id": packet.world_id, "ship_id": packet.ship_id})
	_write("client.ready_pressure", {"peer_id": _game.network_session.multiplayer.get_unique_id(),
		"journey_epoch": int(packet.journey_epoch), "origin_revision": int(packet.origin_revision)})


func _shared_client() -> void:
	if _role == "client":
		var prior_frame: PlanetaryCoordinateFrame = _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
		var prior_generation := prior_frame.get_generation()
		_player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(10020.0, 5.0, 0.0)))
		_check(await _until(func(): return prior_frame.get_generation() > prior_generation, 5.0), "client makes a genuine solo origin commit before joining")
		_player.teleport_to(_game.world.get_player_spawn())
		_check(await _until(func(): return prior_frame.get_generation() > prior_generation + 1, 5.0), "prior solo return leaves independently advanced local frame history")
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "shared cruise independent peer joins")
	if not await _until(_admitted_session_ready, 60.0):
		_check(false, "shared peer receives authenticated admission")
		return
	if _role == "observer":
		var observer_frame: PlanetaryCoordinateFrame = _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
		var initial_generation := observer_frame.get_generation()
		var origin := _game.world.global_position
		_check(await _until(func(): return int(_game.get_network_planetary_journey_snapshot().get("origin_revision", 0)) > 1, 10.0), "late observer receives current authenticated shared journey bootstrap")
		await _ticks(30)
		_check(observer_frame.get_generation() == initial_generation and _game.world.global_position == origin and _player.global_position.length() < 1000.0, "late yard observer retains nearby local origin instead of rebasing to remote travelling ship")
		_check(_game.get_network_remote_body_intent_source() == null and not _player.is_seated(), "late journey bootstrap grants no cabin or pilot ownership")
		_write("observer.observed", {})
		await _wait_file("host.finish", 60.0)
		return
	if _role == "client_b" and not await _wait_file("client.cabin", 60.0):
		return
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not _game._transition_busy, 12.0), "ordinary peer hatch admits actual host-owned walking body: " + _role)
	if _game.get_network_remote_body_intent_source() == null:
		return
	var cabin_frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	_check(cabin_frame.is_simulation_authority_for(_player) and cabin_frame.authority_mode == MovingInteriorFrame.AuthorityMode.FRAME_AUTHORITY, "confirmed crew predicts only its own carried body with unchanged host frame authority: " + _role)
	_check(not _game._network_local_cabin_prediction_is_current(_craft, _craft, _game.network_session), "a foreign body cannot use this crew's local prediction admission: " + _role)
	root.grab_focus()
	await _ticks(20)
	await _walk(Vector3(-1.3 if _role == "client" else 1.3, 0.52, -5.8))
	var journey_receiver := Callable(_game, "_on_network_planetary_journey_state")
	if _role == "client_b":
		_game.network_session.planetary_journey_state_received.disconnect(journey_receiver)
	_write(_role + ".cabin", {})
	if _role == "client":
		var acknowledged := await _until(func(): return _game._network_planetary_journey.is_preparing() and int(_game._network_planetary_journey.get("_last_ack_origin")) > 0, 20.0)
		_check(acknowledged, "first actual peer acknowledges initial preparation before stream impairment")
		if not acknowledged:
			return
		_game.network_session.planetary_journey_state_received.disconnect(journey_receiver)
		_write("client.ack_held", {})
	else:
		if not await _wait_file("host.restore_b", 20.0):
			return
		_game.network_session.planetary_journey_state_received.connect(journey_receiver)
	if not await _wait_file("host.restore_all", 20.0):
		return
	if not _game.network_session.planetary_journey_state_received.is_connected(journey_receiver):
		_game.network_session.planetary_journey_state_received.connect(journey_receiver)
	_write(_role + ".ready_restored", {})
	if not await _wait_file("host.cancelled", 20.0):
		return
	_check(await _until(func(): return not _game._network_planetary_journey.is_active(), 10.0), "real peer receives reliable queued cancellation without stale focus resurrection: " + _role)
	if _role == "client":
		_readiness_pressure_epoch = int(_game._network_planetary_journey.get("_epoch")) + 1
		_game.network_session.planetary_journey_state_received.connect(_pressure_shared_preparation)
	_write(_role + ".cancel_seen", {})
	var frame: PlanetaryCoordinateFrame = _game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var initial_frame := frame.get_generation()
	if not await _wait_file("host.rebased", 60.0):
		return
	_check(await _until(func(): return frame.get_generation() > initial_frame, 10.0), "aboard peer commits own local origin from canonical shared craft focus: " + _role)
	var source := _game.get_network_remote_body_intent_source()
	var initial_tick := _game.network_session.get_moving_interior_latest_server_tick()
	var initial_position := _craft.to_local(_player.global_position)
	# A carried body retains its pre-rebase parking pose; walk to a distinct
	# supported waypoint on the same side to exercise real displacement.
	await _walk(Vector3(-1.0 if _role == "client" else 1.0, 0.52, -7.0))
	print("SHARED_CREW_WALK_RESULT: role=", _role, " initial_local=", initial_position, " final_local=", _craft.to_local(_player.global_position), " distance=", _craft.to_local(_player.global_position).distance_to(initial_position), " floor=", _player.is_on_floor())
	_check(_craft.to_local(_player.global_position).distance_to(initial_position) > 0.6 and _player.is_on_floor(), "ordinary cabin walking remains supported after live origin shift: " + _role)
	_check(source.is_bound() and _game.network_session.get_moving_interior_latest_server_tick() > initial_tick and not bool(_game.planetary_cruise_binding.get_snapshot().get("engagement_requested", true)), "peer streams actual body while host alone owns physical cruise: " + _role)
	var sample := _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id())
	_check(not sample.is_empty() and _craft.global_position.distance_to(sample.position) < 5000.0, "replicated hull remains in current local origin after interpolation: " + _role)
	_write(_role + ".walked", {})
	if not await _wait_file(_role + ".chair_go", 60.0):
		return
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	_game._refresh_interaction_targets()
	print("SHARED_CREW_CHAIR_APPROACH: role=", _role, " local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables(), " objective=", _objective_text(), " source=", source.get_audit())
	await _press(&"interact")
	var chair_claimed := await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0)
	if not chair_claimed:
		print("SHARED_CREW_CHAIR_UNCONFIRMED: role=", _role,
			" pending_seat=", _game._network_engineer_pending_seat,
			" pending_elapsed=", _game._network_engineer_pending_elapsed,
			" client_seat=", _game._network_engineer_client_seat,
			" transition_busy=", _game._transition_busy,
			" crew_view=", _game._network_physical_crew_view(),
			" orphan_release=", _game._network_engineer_orphan_release,
			" source=", source.get_audit())
	_check(chair_claimed, "ordinary travelling crew chair claim after origin shift: " + _role)
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and not _game._transition_busy, 8.0), "ordinary travelling crew stand after origin shift: " + _role)
	await _ticks(20)
	await _walk(_craft.to_local(_station_contract().entry_transform.origin))
	await _look(_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	var chair_reseated: bool = await _until(func(): return _player.is_seated_at(_station_anchor()) and not _game._transition_busy, 8.0)
	if not chair_reseated:
		print("SHARED_CREW_CHAIR_UNCONFIRMED: role=", _role, " boundary=reseat",
			" local=", _craft.to_local(_player.global_position),
			" floor=", _player.is_on_floor(), " controls=", _player.is_control_enabled(),
			" phase=", _game.phase, " candidate=", _game.station_interaction_candidate,
			" reach=", _player.get_interaction_origin().distance_to(_station_contract().entry_transform.origin),
			" max_reach=", GameFlow.STATION_SEAT_MAX_REACH,
			" boarding_holds=", _game._network_client_boarding_holds(_craft),
			" pending_seat=", _game._network_engineer_pending_seat,
			" pending_elapsed=", _game._network_engineer_pending_elapsed,
			" client_seat=", _game._network_engineer_client_seat,
			" transition_busy=", _game._transition_busy,
			" crew_view=", _game._network_physical_crew_view(),
			" passenger_view=", _game.network_session.get_passenger_replica_snapshot(),
			" orphan_release=", _game._network_engineer_orphan_release,
			" objective=", _objective_text(), " source=", source.get_audit(),
			" relationship=", _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id()))
	_check(chair_reseated, "ordinary travelling crew reseat after origin shift: " + _role)
	await _press(&"interact")
	await _until(func(): return not _player.is_seated() and not _game._transition_busy, 8.0)
	# Park clear of the centre aisle before the other client's chair turn.
	await _walk(Vector3(-1.0 if _role == "client" else 1.0, 0.52, -5.8))
	_write(_role + ".chair_done", {})
	if not await _wait_file("host.finish", 60.0):
		return
	_game.shutdown_network_session(&"shared_crew_disconnect")
	_check(_player.is_control_enabled() and not _player.is_seated(), "disconnect restores real travelling crew controls: " + _role)
	_check(not cabin_frame._local_prediction_is_current(_player) and not _game._network_local_cabin_prediction_is_current(_player, _craft, _game.network_session), "actual disconnect retires the crew prediction grant while retaining ordinary solo cabin controls: " + _role)
	_write(_role + ".disconnected", {})
