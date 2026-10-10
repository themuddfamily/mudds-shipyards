## test-matrix-display: input-only
extends SceneTree

## Two owned OS peers load actual Main. The remote exterior hatch and range
## target are staged; cabin walk, chair, siege-lance FIRE and standing use Input.
## A supported host chair then fires, stands and reseats while a confirmed peer
## pilots through the ordinary cockpit; the original migration route remains.
const Main := preload("res://scenes/main.tscn")
var _checks := 0
var _failures: Array[String] = []
var _directory := ""
var _role := ""
var _game: GameFlow
var _craft: BulwarkHeavyGunship
var _player: PlayerController
var _port := 0
var _store_path := ""
var _pilot_store_path := ""
var _package_under_test := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var package_index := args.find("--package-under-test")
	if package_index >= 0 and package_index + 1 < args.size():
		_package_under_test = args[package_index + 1]
		args.remove_at(package_index + 1)
		args.remove_at(package_index)
	if not _package_under_test.is_empty():
		_check(FileAccess.file_exists("res://project.binary"), "gunner process loads requested package without source game fallback")
		if not _failures.is_empty():
			quit(1)
			return
		print("GUNNER_PACKAGE_LOADED: pid=%d package=%s" % [OS.get_process_id(), _package_under_test])
	if args.size() < 3:
		await _orchestrate()
		return
	_role = args[0]
	_directory = args[1]
	_port = int(args[2])
	_game = Main.instantiate() as GameFlow
	_store_path = "user://gunner-peer-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("BulwarkHeavyGunship") as BulwarkHeavyGunship
	_player = _game.get_node("Player") as PlayerController
	_game.start_shift()
	await _ticks(3)
	if _role == "host":
		await _host()
	else:
		await _client()
	for action in [&"interact", &"move_forward", &"move_back", &"move_left", &"move_right", &"fire", &"camera_distance_out"]:
		Input.action_release(action)
	_game.shutdown_network_session(&"gunner_test_done")
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(_store_path)
	if not _pilot_store_path.is_empty():
		DirAccess.remove_absolute(_pilot_store_path)
	_write(_role + ".done", {"checks": _checks, "failures": _failures})
	for failure in _failures:
		push_error(failure)
	print("BULWARK_NETWORK_GUNNER_%s: %d checks, %d failures" % [_role.to_upper(), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _orchestrate() -> void:
	_directory = "/tmp/mudds-gunner-peers-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(_directory)
	_port = 26000 + OS.get_process_id() % 15000
	var host_args := _peer_arguments("host", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"]))
	var host := _spawn_peer("host", host_args)
	_check(host > 0, "owned independent host starts")
	await _wait_file("host.ready", 60.0)
	var client_args := _peer_arguments("client", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-method", "gl_compatibility"]))
	var client := _spawn_peer("client", client_args)
	_check(client > 0, "owned independent client starts")
	await _wait_file("client.done", 120.0)
	await _wait_file("host.done", 60.0)
	for role in ["host", "client"]:
		var result := _read(role + ".done")
		_check(not result.is_empty() and (result.get("failures", []) as Array).is_empty(), "%s ordinary production route passes" % role)
		if not result.is_empty():
			_checks += int(result.get("checks", 0))
	for role in ["host", "client"]:
		await _wait_file(role + ".exit", 10.0)
		_check(FileAccess.get_file_as_string(_directory.path_join(role + ".exit")).strip_edges() == "0", "%s OS process exits zero" % role)
		var child_path := _directory.path_join(role + ".pid")
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and FileAccess.file_exists(child_path):
			var child := int(FileAccess.get_file_as_string(child_path))
			if child > 0 and OS.is_process_running(child):
				OS.kill(child)
	for index in [0, 1]:
		var role := "host" if index == 0 else "client"
		var pid: int = host if index == 0 else client
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	for failure in _failures:
		push_error(failure)
	print("GUNNER_PEER_ARTIFACTS: ", _directory)
	print("BULWARK_NETWORK_GUNNER_ROUTE: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _peer_arguments(role: String, display: PackedStringArray) -> PackedStringArray:
	var parent := OS.get_cmdline_args()
	var path := ProjectSettings.globalize_path("res://")
	var path_index := parent.find("--path")
	if path_index >= 0 and path_index + 1 < parent.size():
		path = parent[path_index + 1]
	elif path.is_empty():
		path = DirAccess.open(".").get_current_dir()
	var script := "res://tests/network/bulwark_network_gunner_route_test.gd"
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
	if not _package_under_test.is_empty():
		args.append_array(["--package-under-test", _package_under_test])
	print("GUNNER_PEER_LAUNCH: ", role, " ", args)
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

func _stage_target(name: String = "TargetDrone03") -> Node3D:
	var target := _game.get_node("ShipyardWorld/ExteriorTargetRange/" + name) as Node3D
	target.set_process(false)
	target.set_physics_process(false)
	target.global_position = _craft.to_global(Vector3(2.0, 3.5, -70.0))
	return target

func _host() -> void:
	_player.set_control_enabled(false)
	_check(_game.host_network_session(_port).accepted, "production host starts")
	var target := _stage_target()
	var health := float(target.get_meta("health", 0.0))
	var receipts: Array[Dictionary] = []
	_game.get_combat_authority().authoritative_shot_submitted.connect(func(request, result: Dictionary):
		if request.source_entity == _craft and request.weapon_id == BulwarkHeavyGunship.BULWARK_CREW_WEAPON_ID:
			receipts.append(result.duplicate(true)))
	_write("host.ready", {})
	if not await _wait_file("client.seated", 60.0):
		print("GUNNER_HOST_BODY_DEBUG: ", _game.get_network_remote_body_audit())
		return
	var peer := int(_game.network_session.get_admitted_peer_ids()[0])
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar)
	var owner := _craft.get_crew_role_authority()
	var assignment := owner.get_assignment(peer, avatar)
	_check(body != null and body.is_seated_at(_craft.get_gunner_station_anchor()) and assignment.get("role") == &"gunner", "host body and actual ship role owner confirm remote gunner")
	_check(_craft.get_moving_interior_component().is_occupant_registered(body), "host seated gunner retains actual moving frame owner")
	var jovian := _game.get_node("JovianLightFreighter") as JovianLightFreighter
	var prior_lifetime := jovian.get_component_damage().get_ledger_generation()
	jovian.reset_for_reuse(jovian.global_transform)
	await _ticks(25)
	_check(jovian.get_component_damage().get_ledger_generation() > prior_lifetime and body.is_seated_at(_craft.get_gunner_station_anchor()) and owner.get_assignment(peer, avatar) == assignment, "unrelated Jovian lifetime refresh preserves actual occupied Bulwark gunner")
	_write("host.fire_ready", {})
	if not await _wait_file("client.fired", 25.0):
		return
	_check(float(target.get_meta("health", health)) < health and receipts.any(func(row): return bool(row.get("accepted", false)) and bool(row.get("damaged", false))), "actual existing siege lance damages registered range target on the host")
	_check(not _craft.is_piloted() and not _craft.get_last_ship_command().fire, "remote gunner never acquires helm or pilot FIRE")
	print("GUNNER_HOST_DAMAGE: health=", [health, target.get_meta("health")], " receipts=", receipts)
	_write("host.damage_checked", {})
	if not await _wait_file("client.stood", 20.0):
		return
	_check(owner.get_assignment(peer, avatar).is_empty() and not body.is_seated(), "ordinary stand releases exact host gunner role")
	_check(await _until(func(): return body.is_on_floor(), 3.0), "stood host body has usable cabin support")
	_check((_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "stand clears siege-lance charge")
	_check(_craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE, "stand stops only power woken by remote role demand")
	_write("host.stand_checked", {})
	if not await _wait_file("client.reseated", 20.0):
		return
	var reseated := owner.get_assignment(peer, avatar)
	_check(not reseated.is_empty() and int(reseated.get("claim_sequence", 0)) != int(assignment.claim_sequence) and body.is_seated_at(_craft.get_gunner_station_anchor()), "ordinary reseat establishes fresh host physical claim identity")
	_write("host.reseat_checked", {})
	if not await _wait_file("client.negatives", 30.0):
		return
	_check((_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "stale and malformed actual RPCs cannot start a charge")
	_write("host.negatives_checked", {})
	if not await _wait_file("client.migrate", 20.0):
		return
	_check(_game.network_session.rotate_session_migration().accepted, "real host migration rotates while gunner seated")
	await _ticks(35)
	_check(owner.get_assignment(peer, avatar).is_empty() and not body.is_seated(), "migration releases physical gunner without resurrection")
	_check(body.get_cabin_containment_report().active, "migration restores usable retained cabin body")
	_print_chair_state("host_migrated", body, avatar)
	_write("host.migrated", {})
	if not await _wait_file("client.disconnect_charging", 20.0):
		return
	_print_chair_state("host_disconnect_charge", body, avatar)
	_check(not owner.get_assignment(peer, avatar).is_empty() and _craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE and not (_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "remote role is actually occupied, powered and charging at disconnect boundary")
	_write("host.disconnect_ready", {})
	if not await _wait_file("client.disconnected", 20.0):
		return
	await _ticks(20)
	_check(simulation.get_body(avatar) == null and owner.get_assignment(peer, avatar).is_empty(), "disconnect retires actual body and role")
	_check(_craft.get_telemetry().engine_state == HeroShip.ENGINE_OFFLINE and (_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "powered disconnect stops exactly the engine demand and charge before body reaping")
	# Exercise the host's retained ordinary solo chair against the same
	# network-owned Bulwark ledger, after the remote role has actually left.
	_player.set_control_enabled(true)
	_player.teleport_to(_craft.get_gunner_station_role_contract().entry_transform)
	await _ticks(25)
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not bool(_game.get("_transition_busy")), 6.0), "host ordinary Interact uses physical gunner and the existing shared ship ledger")
	_check(not owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty(), "host physical chair uses host-local authoritative assignment")
	await _host_moving_gunner(owner, receipts)
	_check(_game.network_session.rotate_session_migration().accepted, "host-local occupied gunner participates in actual migration")
	await _ticks(35)
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() and not _player.is_seated() and _player.is_control_enabled(), "migration clears host-local claim and restores actual usable local body")
	_check((_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty() and _craft.get_command_source() == _craft.get_local_input_source(), "migration leaves no gunner charge or borrowed remote producer")
	_game.shutdown_network_session(&"gunner_host_done")
	_check(_craft.get_crew_role_authority() == null, "session shutdown detaches exact empty role owner for retained solo reuse")

func _client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "production client joins")
	await _ticks(100)
	var target := _stage_target()
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + _craft.global_basis.y.normalized() * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not bool(_game.get("_transition_busy")), 12.0), "ordinary hatch Interact admits real walking body")
	root.grab_focus()
	await _ticks(20)
	await _look(_player.global_position - _craft.global_basis.z * 20.0 + Vector3.UP * 1.5)
	await _walk(Vector3(-0.4, BulwarkHeavyGunship.CABIN_FLOOR_Y, 1.65))
	await _walk(Vector3(1.45, BulwarkHeavyGunship.CABIN_FLOOR_Y, 1.65))
	await _walk(Vector3(1.45, BulwarkHeavyGunship.CABIN_FLOOR_Y, 0.60))
	_check(_player.is_on_floor(), "ordinary full capsule walk reaches real gunner portal supported")
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	print("GUNNER_APPROACH: ", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables())
	await _press(&"interact")
	if not await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0):
		_check(false, "ordinary chair Interact seats client only after host confirms")
		print("GUNNER_CHAIR_DEBUG: ", _game.network_session.get_gunner_replica_snapshot())
		return
	_check(true, "ordinary chair Interact seats client only after host confirms")
	var source := _craft.get_local_input_source()
	source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	var first := _game.network_session.get_gunner_replica_snapshot()
	_write("client.seated", {})
	if not await _wait_file("host.fire_ready", 10.0):
		return
	await _look(target.global_position)
	_check(_player.is_seated_at(_craft.get_gunner_station_anchor()) and _player.is_station_seated() and _player.is_control_enabled() and source.get_authority_peer_id() == _game.network_session.multiplayer.get_unique_id(), "confirmed client chair retains actual seated station controls and exact transformed source owner before FIRE")
	Input.action_press(source.fire_action)
	_check(await _until(func(): return not (_game.network_session.get_gunner_replica_snapshot().get("gameplay", {}) as Dictionary).get("role_ammunition", {}).is_empty(), 12.0), "ordinary transformed held FIRE reaches existing host gunner ammunition owner")
	Input.action_release(source.fire_action)
	await _ticks(15)
	_check(_player.is_seated_at(_craft.get_gunner_station_anchor()) and _player.is_station_seated() and _player.is_control_enabled() and source.get_authority_peer_id() == _game.network_session.multiplayer.get_unique_id(), "actual host shot completes while client remains in the confirmed chair with usable station controls and exact source owner")
	_check(_craft.get_crew_role_authority() == null, "client never acquires role or weapon damage authority")
	_write("client.fired", {})
	if not await _wait_file("host.damage_checked", 12.0):
		return
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and not bool(_game.get("_transition_busy")), 8.0), "ordinary stand receives host authorization")
	await _ticks(20)
	_check(_player.is_on_floor() and _player.is_control_enabled() and not _player.is_station_seated() and source.get_authority_peer_id() == 1, "standing restores exact transformed input owner and supported controls")
	_write("client.stood", {})
	if not await _wait_file("host.stand_checked", 10.0):
		return
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	var reseated := await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_check(reseated, "ordinary reseat succeeds")
	if not reseated:
		print("GUNNER_RESEAT_DEBUG: local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables(), " boarding=", _game.call("_network_client_boarding_holds", _craft), " view=", _game.network_session.get_gunner_replica_snapshot())
		return
	_write("client.reseated", {})
	if not await _wait_file("host.reseat_checked", 10.0):
		return
	var view := _game.network_session.get_gunner_replica_snapshot()
	var payload := {"avatar_id": StringName(view.assignment.avatar_id), "entity_generation": int(view.entity_generation),
		"seat_generation": int(view.assignment.seat_generation), "claim_sequence": int(first.assignment.claim_sequence),
		"target_generation": int(view.gameplay.target_generation), "trigger": true, "aim_local": Vector3.FORWARD,
		"request_sequence": 10000, "binding_generation": int(view.binding_generation), "migration_generation": int(view.migration_generation), "server_tick": _game.network_session.get_boarding_server_tick_estimate()}
	await _refusal(payload, &"gunner_not_seated", "old physical chair claim is refused through real secure RPC")
	payload.claim_sequence = int(view.assignment.claim_sequence)
	payload.entity_generation += 1
	await _refusal(payload, &"gunner_not_seated", "stale body generation is refused")
	payload.entity_generation -= 1
	payload.binding_generation += 1
	await _refusal(payload, &"stale_gunner_generation", "stale binding generation is refused")
	payload.binding_generation -= 1
	payload.aim_local = Vector3(INF, 0.0, 0.0)
	await _refusal(payload, &"invalid_gunner_aim", "nonfinite aim fails closed")
	payload.aim_local = Vector3.FORWARD
	payload.target_generation += 1
	await _refusal(payload, &"stale_target_generation", "retired host target generation cannot charge")
	payload.target_generation -= 1
	await _refusal(payload, &"stale_gunner_sequence", "replayed application request cannot charge")
	_write("client.negatives", {})
	if not await _wait_file("host.negatives_checked", 10.0):
		return
	_write("client.migrate", {})
	if not await _wait_file("host.migrated", 10.0):
		return
	_check(await _until(func(): return not _player.is_seated() and not bool(_game.get("_transition_busy")), 8.0), "migration releases confirmed client chair presentation")
	_check(source.get_authority_peer_id() == 1, "migration restores borrowed input source")
	_print_chair_state("client_immediate_migration_recovery", _player)
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	var ready := await _until(func():
		var body_source := _game.get_network_remote_body_intent_source()
		var candidate := _game._find_station_interaction_candidate()
		return _player.is_on_floor() and _player.is_control_enabled() and not bool(_game.get("_transition_busy")) \
			and not _player.is_seated() and _game._network_client_boarding_holds(_craft) \
			and body_source != null and body_source.is_bound() and candidate is ShipCrewSeat \
			and candidate.get_ship() == _craft and candidate.get_seat_id() == BulwarkHeavyGunship.GUNNER_SEAT_ID,
		8.0)
	_print_chair_state("client_before_migration_reseat", _player)
	_check(ready, "migration recovery reaches supported controllable ordinary chair approach")
	if not ready:
		return
	await _press(&"interact")
	var migration_reseated := await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_print_chair_state("client_after_migration_reseat", _player)
	_check(migration_reseated, "ordinary chair remains reusable after migration")
	if not migration_reseated:
		return
	source.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _look(target.global_position)
	Input.action_press(source.fire_action)
	_check(await _until(func(): return not (_game.network_session.get_gunner_replica_snapshot().get("gameplay", {}) as Dictionary).get("role_charges", {}).is_empty(), 8.0), "ordinary FIRE starts actual charge before powered disconnect")
	_write("client.disconnect_charging", {})
	if not await _wait_file("host.disconnect_ready", 10.0):
		return
	Input.action_release(source.fire_action)
	_game.shutdown_network_session(&"gunner_client_disconnect")
	_check(not _player.is_seated() and _player.is_control_enabled(), "disconnect keeps local player awake and usable")
	_write("client.disconnected", {})
	await _client_pilot_host_gunner()

func _helm_cursor(source: ShipCommandSource) -> Dictionary:
	return {"stream": source.get_stream_id(), "delivery": source.get_delivery_generation(), "sequence": source.get_next_sequence()}

func _host_moving_gunner(owner: CrewSeatRoleAuthority, receipts: Array[Dictionary]) -> void:
	var source := _craft.get_local_input_source()
	var profile := source.get_input_profile_generation()
	var source_peer := source.get_authority_peer_id()
	var area := _craft.get_node("ShipBoardingArea") as ShipBoardingArea
	var first_claim := owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
	_write("host.local_seated", {})
	if not await _wait_file("client.pilot_moving", 30.0):
		return
	_check(_game._host_craft_has_remote_pilot(_craft), "actual admitted peer holds the confirmed Bulwark pilot occupancy")
	_check(_craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE, "ordinary remote throttle wakes the authoritative Bulwark engine")
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	_check(helm != null and helm != source and _craft.is_remote_piloted(), "exact remote helm remains selected beside retained host gunner input")
	if helm == null:
		return
	var start := _craft.global_position
	await _ticks(12)
	_check(_craft.global_position.distance_to(start) > 0.05, "confirmed pilot commands move the actual host gunner craft")
	_check(_player.is_seated_at(_craft.get_gunner_station_anchor()) and _game._solo_crew_claim_is_current() and _craft.get_moving_interior_component().is_occupant_registered(_player), "moving host gunner retains exact physical chair and shared owner")
	var cursor := _helm_cursor(helm)
	_game._reset_solo_gunner_input()
	_check(_helm_cursor(helm) == cursor and _craft.get_command_source() == helm, "retiring retained gunner input leaves remote helm stream and cursor untouched")
	await _host_gunner_shot("TargetDrone02", receipts)
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving gunner stand restores supported cabin controls")
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() and (_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "moving stand releases exactly the gunner lease and charge")
	_check(_craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE and _craft.get_command_source() == helm and helm.get_stream_id() == cursor.stream and helm.get_delivery_generation() == cursor.delivery, "moving stand preserves pilot power and exact remote helm epochs")
	_check(area.is_reserved() and area.get_reservation_token() == _player, "moving stand retains the host cabin reservation")
	var stand_local := _craft.to_local(_player.global_position)
	await _walk(Vector3(1.45, BulwarkHeavyGunship.CABIN_FLOOR_Y, 1.65))
	_check(_craft.to_local(_player.global_position).distance_to(stand_local) > 0.60 and _player.is_on_floor() and _craft.get_moving_interior_component().is_occupant_registered(_player), "ordinary moving walk travels away from the chair on its actual carried floor")
	await _walk(Vector3(1.45, BulwarkHeavyGunship.CABIN_FLOOR_Y, 0.60))
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	_check(await _until(func():
		var label := _game.hud.get("_interaction_label") as Label
		return _game.station_interaction_candidate is ShipCrewSeat and label != null and label.text.contains("SIT") and label.text.contains("GUNNER")
	, 3.0), "moving host sees the ordinary physical gunner SIT prompt")
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and _game._solo_crew_claim_is_current() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving gunner reseat acquires a fresh physical claim")
	var claim := owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID)
	_check(not claim.is_empty() and int(claim.get("claim_sequence", 0)) != int(first_claim.get("claim_sequence", 0)), "moving reseat replaces the retired chair claim identity")
	# Exercise the existing lease owner, without assigning a seat or mutating
	# flight, power, ammunition or damage state to manufacture a success.
	var sequence := maxi(int(claim.get("claim_sequence", 0)), int(owner.get_last_intent(1, GameFlow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0))) + 1
	_check(_craft.release_crew_role(1, 1, GameFlow.SOLO_CREW_AVATAR_ID, BulwarkHeavyGunship.GUNNER_SEAT_ID, sequence, int(claim.get("seat_generation", 0))).accepted, "existing authority revokes exactly the moving host gunner lease")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled(), 8.0), "lease loss restores supported moving gunner body")
	_check(_craft.get_command_source() == helm and helm.get_stream_id() == cursor.stream and helm.get_delivery_generation() == cursor.delivery, "gunner lease loss preserves the independent pilot stream")
	var before_unseated := receipts.size()
	await _press(source.fire_action)
	_check(receipts.size() == before_unseated and (_craft.get_gunner_gameplay_state().role_charges as Dictionary).is_empty(), "unseated FIRE cannot reuse a retired gunner lease")
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and _game._solo_crew_claim_is_current() and not bool(_game.get("_transition_busy")), 8.0), "ordinary moving reentry after lease loss uses only the host gunner chair")
	await _host_gunner_shot("TargetDrone01", receipts)
	_check(_craft.get_command_source() == helm and helm.get_next_sequence() > int(cursor.sequence) and _craft.global_position.distance_to(start) > 0.5 and _craft.get_last_ship_command().throttle > 0.0 and not _craft.get_last_ship_command().fire, "pilot commands continue through gunner FIRE, stand, walk and lease recovery without borrowing pilot FIRE")
	_write("host.moving_checked", {})
	if not await _wait_file("client.pilot_disconnected", 20.0):
		return
	_check(await _until(func(): return not _craft.is_remote_piloted() and _craft.get_command_source() == source and not is_instance_valid(helm), 5.0), "actual pilot disconnect restores the exact retained local producer")
	_check(_game._solo_crew_claim_is_current() and _player.is_seated_at(_craft.get_gunner_station_anchor()), "pilot disconnect preserves the separate host gunner claim")
	_check(source.get_authority_peer_id() == source_peer and source.get_input_profile_generation() == profile and _craft.get_local_input_source() == source, "moving gunner lifecycle preserves exact local source, authority and settings profile")

func _host_gunner_shot(target_name: String, receipts: Array[Dictionary]) -> void:
	var target := _stage_target(target_name)
	var health := float(target.get_meta("health", 0.0))
	var before := receipts.size()
	var actor := StringName("1:%s" % GameFlow.SOLO_CREW_AVATAR_ID)
	var source := _craft.get_local_input_source()
	await _look(target.global_position)
	# Actual private-window focus and the charge share the existing eight-second
	# budget. Never grant sampling permission through a synthetic notification.
	var deadline := Time.get_ticks_msec() + 8000
	root.grab_focus()
	var focused := await _until(func(): return root.has_focus() and Window.get_focused_window() == root and bool(source.call(&"_is_input_sampling_active")), maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0))
	_check(focused, "real private host Window and local sampler are active before moving FIRE: " + target_name)
	if not focused:
		return
	Input.action_press(source.fire_action)
	var fired := await _until(func(): return int((_craft.get_gunner_gameplay_state().role_ammunition as Dictionary).get(actor, 2)) < 2, maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0))
	Input.action_release(source.fire_action)
	await _ticks(8)
	_check(fired and int((_craft.get_gunner_gameplay_state().role_ammunition as Dictionary).get(actor, 2)) == 1 and receipts.size() == before + 1, "ordinary moving host held FIRE resolves exactly one real charge and ammunition debit: " + target_name)
	_check(receipts.size() == before + 1 and bool(receipts[before].get("accepted", false)) and bool(receipts[before].get("damaged", false)) and float(target.get_meta("health", health)) < health, "existing authoritative siege lance damages the registered target on host: " + target_name)

func _client_pilot_host_gunner() -> void:
	if not await _wait_file("host.local_seated", 20.0):
		return
	# The original client body has disconnected. Retire its actual Main before
	# a new ordinary connection; never reposition an already-reserved cabin body.
	var previous := _game
	previous.release_mouse_capture()
	previous.queue_free()
	await _ticks(3)
	_check(not is_instance_valid(previous), "old client Main is actually retired before the independent pilot connection")
	_print_fresh_pilot_state(&"before_new_main")
	_game = Main.instantiate() as GameFlow
	_pilot_store_path = "user://gunner-pilot-peer-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(_pilot_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("BulwarkHeavyGunship") as BulwarkHeavyGunship
	_player = _game.get_node("Player") as PlayerController
	_print_fresh_pilot_state(&"before_start_shift")
	_game.start_shift()
	await _ticks(3)
	var client_target_a := _game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone02") as Node3D
	var client_target_b := _game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone01") as Node3D
	var client_health := [client_target_a.get_meta("health"), client_target_b.get_meta("health")]
	_print_fresh_pilot_state(&"before_join")
	var join_result: Dictionary = _game.join_network_session("127.0.0.1", _port)
	_check(join_result.accepted, "fresh ordinary client joins the retained host for pilot duty")
	_print_fresh_pilot_state(&"after_join", join_result)
	await _ticks(100)
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + _craft.global_basis.y.normalized() * 0.05))
	await _ticks(10)
	_print_fresh_pilot_state(&"before_hatch_press")
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not bool(_game.get("_transition_busy")), 12.0), "fresh pilot uses ordinary exterior hatch to enter the real parked cabin")
	_print_fresh_pilot_state(&"after_hatch_wait")
	root.grab_focus()
	var anchor := _craft.get_pilot_seat_anchor()
	await _walk(_craft.to_local(anchor.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(anchor.global_position)
	await _press(&"interact")
	_check(await _until(func(): return bool(_game.get("_piloting")) and not bool(_game.get("_transition_busy")), 12.0), "ordinary client cockpit Interact acquires the real confirmed pilot seat")
	if not bool(_game.get("_piloting")):
		return
	_check(_game._network_client_boarding_claim.get("role") == &"pilot", "actual client boarding receipt grants only the pilot role")
	var source := _craft.get_local_input_source()
	# Focus acquisition consumes the existing five-second engine/motion budget.
	var deadline := Time.get_ticks_msec() + 5000
	root.grab_focus()
	var focused := await _until(func(): return root.has_focus() and Window.get_focused_window() == root and bool(source.call(&"_is_input_sampling_active")), maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0))
	_check(focused, "real private client Window and local sampler are active before ordinary pilot throttle")
	if not focused:
		return
	Input.action_press(source.throttle_forward_action, 0.15)
	_check(await _until(func(): return _craft.get_telemetry().engine_state == HeroShip.ENGINE_ONLINE and _craft.velocity.length() > 0.1, maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0)), "ordinary confirmed client throttle starts the engine and actual craft motion")
	_write("client.pilot_moving", {})
	if not await _wait_file("host.moving_checked", 60.0):
		Input.action_release(source.throttle_forward_action)
		return
	_check([client_target_a.get_meta("health"), client_target_b.get_meta("health")] == client_health and _craft.get_crew_role_authority() == null, "host-local gunner shots never resolve target damage or acquire role authority on client")
	Input.action_release(source.throttle_forward_action)
	_game.shutdown_network_session(&"host_gunner_pilot_disconnect")
	_check(not _player.is_seated() and _player.is_control_enabled(), "pilot disconnect restores the actual client body and controls")
	_write("client.pilot_disconnected", {})

## Read-only admission observations expose failures buffered until client.done.
func _print_fresh_pilot_state(stage: StringName, join_result: Dictionary = {}) -> void:
	print("GUNNER_FRESH_PILOT_STATE: stage=", stage, " monotonic_ms=", Time.get_ticks_msec(), " physics_tick=", Engine.get_physics_frames(), " pending_failures=", _failures, " join_result=", join_result, " game_valid=", is_instance_valid(_game))
	if not is_instance_valid(_game):
		return
	var session := _game.network_session
	var session_available := is_instance_valid(session)
	var peer: MultiplayerPeer = session.multiplayer.multiplayer_peer if session_available else null
	print("GUNNER_FRESH_PILOT_CONTEXT: stage=", stage,
		" session_available=", session_available,
		" session_mode=", _game.get("_network_session_mode"), " connection_status=", peer.get_connection_status() if peer != null else -1,
		" session_server=", session.is_server() if session_available else null, " admitted_peers=", session.get_admitted_peer_ids() if session_available else [],
		" boarding_claim=", _game.get("_network_client_boarding_claim"), " boarding_request=", _game.get("_network_client_boarding_request"), " boarding_audit=", _game.get_network_client_boarding_audit(),
		" piloting=", _game.get("_piloting"), " phase=", _game.phase, " transition_busy=", _game.get("_transition_busy"),
		" player_control=", _player.is_control_enabled(), " player_seated=", _player.is_seated(), " containment=", _player.get_cabin_containment_report())

func _refusal(payload: Dictionary, reason: StringName, description: String) -> void:
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_gunner_intent(payload)
	_check(await _until(func(): return _game.network_session.get_gunner_replica_snapshot().get("error") == reason, 5.0), description)

func _walk(target_local: Vector3) -> void:
	_print_walk_state(&"start", target_local, Vector3.ZERO, Vector2.ZERO, 0)
	var stalled_ticks := 0
	var printed_stall := false
	var printed_collision := false
	var iterations := 0
	for _index in 240:
		var target := _craft.to_global(target_local)
		var delta := target - _player.global_position
		delta = delta.slide(_craft.global_basis.y.normalized())
		if delta.length() < 0.30:
			break
		var forward := (-_player.get_camera().global_basis.z).slide(_craft.global_basis.y.normalized()).normalized()
		var right := forward.cross(_craft.global_basis.y.normalized()).normalized()
		var direction := delta.normalized()
		var axis := Vector2(direction.dot(right), -direction.dot(forward))
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			Input.action_release(action)
		Input.action_press(&"move_left" if axis.x < 0.0 else &"move_right", absf(axis.x))
		Input.action_press(&"move_forward" if axis.y < 0.0 else &"move_back", absf(axis.y))
		var before_local := _craft.to_local(_player.global_position)
		await _ticks(1)
		iterations = _index + 1
		var moved := _craft.to_local(_player.global_position).distance_to(before_local)
		stalled_ticks = stalled_ticks + 1 if moved < 0.01 else 0
		if not printed_collision:
			for collision_index in _player.get_slide_collision_count():
				if _player.get_slide_collision(collision_index).get_normal().dot(direction) < -0.1:
					_print_walk_state(&"first_blocking_collision", target_local, direction, axis, iterations)
					printed_collision = true
					break
		if not printed_stall and stalled_ticks >= 12:
			_print_walk_state(&"first_stall", target_local, direction, axis, iterations)
			printed_stall = true
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	await _ticks(15)
	_print_walk_state(&"end", target_local, Vector3.ZERO, Vector2.ZERO, iterations)

## Bounded read-only observations; no changes to route decisions or input.
func _print_walk_state(stage: StringName, target_local: Vector3, direction: Vector3, commanded_axis: Vector2, iteration: int) -> void:
	var collisions: Array[Dictionary] = []
	for index in mini(_player.get_slide_collision_count(), 4):
		var collision := _player.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		collisions.append({"collider": collider.get_path() if collider != null else NodePath(), "normal": collision.get_normal(), "position": collision.get_position(), "travel": collision.get_travel(), "remainder": collision.get_remainder()})
	var source: NetworkRemoteBodyIntentSource = _game.get_network_remote_body_intent_source()
	var delta := (_craft.to_global(target_local) - _player.global_position).slide(_craft.global_basis.y.normalized())
	print("GUNNER_WALK_STATE: stage=", stage, " monotonic_ms=", Time.get_ticks_msec(), " physics_tick=", Engine.get_physics_frames(),
		" iteration=", iteration, " local=", _craft.to_local(_player.global_position), " target=", target_local, " planar_distance=", delta.length(),
		" floor=", _player.is_on_floor(), " control=", _player.is_control_enabled(), " focus=", root.has_focus(), " focused_window=", Window.get_focused_window(),
		" commanded_axis=", commanded_axis, " actual_input_axis=", Input.get_vector("move_left", "move_right", "move_forward", "move_back"), " direction=", direction, " velocity=", _player.velocity,
		" collisions=", collisions, " containment=", _player.get_cabin_containment_report(), " phase=", _game.phase, " transition_busy=", _game.get("_transition_busy"),
		" seated=", _player.is_seated(), " role_view=", _game.network_session.get_gunner_replica_snapshot(), " piloted=", _craft.is_piloted(), " remote_piloted=", _craft.is_remote_piloted(),
		" session_server=", _game.network_session.is_server(), " admitted_peers=", _game.network_session.get_admitted_peer_ids(), " body_source_audit=", source.get_audit() if source != null else {})

func _look(target: Vector3) -> void:
	for _index in 4:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			_player._unhandled_input(click)
		var desired := _player.global_basis.inverse() * (target - _player.get_camera().global_position).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		_player._unhandled_input(event)
		await _ticks(1)

func _press(action: StringName) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)
	await _ticks(3)

func _until(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await _ticks(1)
	return false

func _ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func _wait_file(name: String, seconds: float) -> bool:
	var started_ms := Time.get_ticks_msec()
	var result := await _until(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds)
	print("GUNNER_WAIT_END: role=", _role, " boundary=", name, " monotonic_ms=", Time.get_ticks_msec(), " physics_tick=", Engine.get_physics_frames(), " elapsed_ms=", Time.get_ticks_msec() - started_ms, " original_budget_seconds=", seconds, " arrived=", result)
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
	print("GUNNER_PEER_BOUNDARY: ", _role, " ", name, " monotonic_ms=", Time.get_ticks_msec(), " physics_tick=", Engine.get_physics_frames())

func _read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_directory.path_join(name)):
		return {}
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(_directory.path_join(name))) != OK or not parsed.data is Dictionary:
		print("GUNNER_INVALID_RECEIPT: ", name)
		return {}
	return parsed.data

func _print_chair_state(boundary: String, body: PlayerController, avatar: StringName = &"") -> void:
	var seat := _craft.find_child("SoloGunnerSeatInteraction", true, false) as ShipCrewSeat
	var state := {
		"boundary": boundary, "role": _role, "local_position": _craft.to_local(body.global_position),
		"floor": body.is_on_floor(), "controls": body.is_control_enabled(), "seated": body.is_seated(),
		"station_context": body.is_station_seated(), "nearby": body.get_nearby_interactables(),
		"reach": body.get_interaction_origin().distance_to(seat.get_entry_transform().origin),
		"epochs": _game.network_session.get_migration_snapshot(),
		"movement_tick": _game.network_session.get_movement_server_tick(),
		"relationship_tick": _game.network_session.get_moving_interior_latest_server_tick(),
		"boarding_tick": _game.network_session.get_boarding_server_tick_estimate(),
		"view": _game.network_session.get_gunner_replica_snapshot(),
		"source_owner": _craft.get_local_input_source().get_authority_peer_id(),
	}
	if _role == "host":
		state["body_record"] = _game.get_network_remote_body_simulation().get_body_record(avatar)
		state["body_audit"] = _game.get_network_remote_body_audit()
		state["movement_audit"] = _game.network_session.get_movement_authority_audit()
		state["assignment"] = _craft.get_crew_role_authority().get_assignment(int(NetworkRemoteBodySimulation.get_remote_body_identity(body).get("owner_peer_id", 0)), avatar)
	else:
		state["phase"] = _game.phase
		state["transition_busy"] = _game.get("_transition_busy")
		state["pending_seat"] = _game.get("_network_engineer_pending_seat")
		state["boarding_holds"] = _game._network_client_boarding_holds(_craft)
		state["candidate"] = _game._find_station_interaction_candidate()
		var source := _game.get_network_remote_body_intent_source()
		state["body_source_bound"] = source != null and source.is_bound()
		state["body_source_audit"] = source.get_audit() if source != null else {}
	print("GUNNER_CHAIR_STATE: ", state)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
