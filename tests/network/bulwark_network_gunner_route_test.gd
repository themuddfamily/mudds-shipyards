## test-matrix-display: input-only
extends SceneTree

## Two owned OS peers load actual Main. The remote exterior hatch and range
## target are staged; cabin walk, chair, siege-lance FIRE and standing use Input.
## A supported host chair approach separately exercises retained solo migration.
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

func _stage_target() -> Node3D:
	var target := _game.get_node("ShipyardWorld/ExteriorTargetRange/TargetDrone03") as Node3D
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
	_write("host.migrated", {})
	if not await _wait_file("client.disconnect_charging", 20.0):
		return
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
	_check(_game.network_session.rotate_session_migration().accepted, "host-local occupied gunner participates in actual migration")
	await _ticks(35)
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() and not _player.is_seated() and _player.is_control_enabled(), "migration clears host-local claim and restores actual usable local body")
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
	await _walk(Vector3(-1.4, BulwarkHeavyGunship.CABIN_FLOOR_Y, 2.15))
	await _walk(Vector3(1.45, BulwarkHeavyGunship.CABIN_FLOOR_Y, 2.15))
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
	await _ticks(20)
	await _look(_craft.get_gunner_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_gunner_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "ordinary chair remains reusable after migration")
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

func _refusal(payload: Dictionary, reason: StringName, description: String) -> void:
	payload.server_tick = _game.network_session.get_boarding_server_tick_estimate()
	_game.network_session.send_gunner_intent(payload)
	_check(await _until(func(): return _game.network_session.get_gunner_replica_snapshot().get("error") == reason, 5.0), description)

func _walk(target_local: Vector3) -> void:
	var target := _craft.to_global(target_local)
	print("GUNNER_WALK_START: local=", _craft.to_local(_player.global_position), " target=", target_local)
	for _index in 240:
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
		await _ticks(1)
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(action)
	await _ticks(15)

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
	var result := await _until(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds)
	_check(result, "peer boundary arrives: " + name)
	return result

func _write(name: String, data: Dictionary) -> void:
	print("GUNNER_PEER_BOUNDARY: ", _role, " ", name)
	var file := FileAccess.open(_directory.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_directory.path_join(name)):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(_directory.path_join(name))) as Dictionary

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
