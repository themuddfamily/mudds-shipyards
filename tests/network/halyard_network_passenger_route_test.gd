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
var _craft: HalyardCrewTransport
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
	_game = Main.instantiate() as GameFlow
	_store_path = "user://passenger-peer-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	_player = _game.get_node("Player") as PlayerController
	_game.start_shift()
	await _ticks(3)
	if _role == "host":
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
	_directory = "/tmp/mudds-passenger-peers-%d" % OS.get_process_id()
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
	for role in ["host", "client"]:
		var child := int(FileAccess.get_file_as_string(_directory.path_join(role + ".pid")))
		_check(child > 0 and not DirAccess.dir_exists_absolute("/proc/%d" % child), "%s actual Godot actor is absent after owning wait" % role)
	for index in [0, 1]:
		var role := "host" if index == 0 else "client"
		var pid: int = host if index == 0 else client
		if not FileAccess.file_exists(_directory.path_join(role + ".exit")) and pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
	for failure in _failures:
		push_error(failure)
	print("PASSENGER_PEER_ARTIFACTS: ", _directory)
	print("HALYARD_NETWORK_PASSENGER_ROUTE: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

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
	var owner := _craft.get_crew_role_authority()
	_check(owner != null, "network binding owns actual Halyard physical roster")
	# One exterior staging placement; all subsequent host movement is input.
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(20)
	await _walk(Vector3(-3.10, 0.0, HalyardCrewTransport.AIRSTAIR_Z))
	var hatch := _craft.get_node("WalkableInterior/CabinHatchInteraction") as ShipCabinHatch
	await _look(hatch.global_position)
	await _press(&"interact")
	_check(await _until(func(): return _craft.is_canopy_open(), 5.0), "ordinary host hatch Interact opens physical cabin")
	await _walk(Vector3(-1.35, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	await _walk(_craft.to_local(_craft.get_passenger_station_role_contract().entry_transform.origin))
	await _look(_craft.get_loadmaster_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	var host_seated := await _until(func(): return _player.is_seated_at(_craft.get_loadmaster_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_check(host_seated, "host ordinary walk and chair Interact physically seats passenger")
	print("PASSENGER_HOST_CHAIR: seated=", host_seated, " local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " assignment=", owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID))
	if not host_seated:
		return
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).get("role") == &"passenger" and _game._solo_crew_claim_is_current(), "host-local claim uses exact network-owned chair and body")
	_check(_game._network_local_role_presentation().local_role == &"passenger", "host HUD names confirmed passenger role")
	await _press(&"interact")
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and not bool(_game.get("_transition_busy")), 8.0), "ordinary host stand restores supported controllable body")
	_check(owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() and _craft.get_crew_role_authority() == owner, "host stand releases own claim and preserves shared network ledger")
	# Clear the shared exit through ordinary walking before another body arrives.
	await _walk(Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z))
	_check(_player.global_position.distance_to(_craft.get_passenger_station_role_contract().exit_transform.origin) > 2.0, "host walks clear of the shared chair exit")
	_player.set_control_enabled(false)
	_write("host.ready", {})
	if not await _wait_file("client.seated", 60.0):
		return
	var simulation := _game.get_network_remote_body_simulation()
	var peers := _game.network_session.get_admitted_peer_ids()
	_check(peers.size() == 1, "one actual separate client is admitted")
	if peers.is_empty():
		return
	var peer := int(peers[0])
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var body := simulation.get_body(avatar)
	var assignment := owner.get_assignment(peer, avatar)
	_check(body != null and body.is_seated_at(_craft.get_loadmaster_station_anchor()), "host production walking body physically occupies passenger anchor")
	_check(assignment.get("role") == &"passenger" and assignment.get("seat_id") == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID, "host role owner grants exactly the authored passenger chair")
	var seat := simulation.get_body_crew_seat(avatar)
	var unregistered := PlayerController.new()
	var spoof := {"body": unregistered, "owner_peer_id": peer, "entity_id": &"foreign_passenger", "craft": _craft, "frame": _craft.get_moving_interior_component()}
	_check(not _game._network_engineer_binding.passenger.claim(spoof, seat).accepted, "unregistered body cannot invent passenger occupancy")
	unregistered.free()
	_write("host.seat_checked", {})
	if not await _wait_file("client.stood", 20.0):
		return
	_check(owner.get_assignment(peer, avatar).is_empty() and not body.is_seated(), "ordinary remote stand releases exact physical role")
	_check(await _until(func(): return body.is_on_floor(), 3.0), "stood host body has usable cabin support")
	_write("host.stand_checked", {})
	if not await _wait_file("client.reseated", 20.0):
		return
	var reseated := owner.get_assignment(peer, avatar)
	_check(not reseated.is_empty() and int(reseated.get("claim_sequence", 0)) != int(assignment.claim_sequence), "ordinary reseat creates fresh authoritative chair identity")
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
	_game.shutdown_network_session(&"passenger_host_done")
	_check(_craft.get_crew_role_authority() == null, "shutdown detaches exact empty role owner for ordinary solo reuse")

func _client() -> void:
	_check(_game.join_network_session("127.0.0.1", _port).accepted, "production client joins")
	await _ticks(100)
	_player.teleport_to(Transform3D(_craft.global_basis.orthonormalized(), _craft.get_boarding_position() + Vector3.UP * 0.05))
	await _ticks(10)
	await _press(&"interact")
	_check(await _until(func(): return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and _game.get_network_remote_body_intent_source() != null and not bool(_game.get("_transition_busy")), 12.0), "ordinary hatch Interact admits real walking body")
	root.grab_focus()
	await _ticks(20)
	await _walk(_craft.to_local(_craft.get_passenger_station_role_contract().entry_transform.origin))
	_check(_player.is_on_floor(), "ordinary cabin walk reaches actual passenger chair supported")
	await _look(_craft.get_loadmaster_station_anchor().global_position + Vector3.UP * 1.2)
	print("PASSENGER_APPROACH: local=", _craft.to_local(_player.global_position), " candidate=", _game.station_interaction_candidate, " nearby=", _player.get_nearby_interactables())
	await _press(&"interact")
	var seated := await _until(func(): return _player.is_seated_at(_craft.get_loadmaster_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0)
	_check(seated, "ordinary chair Interact seats client only after host confirms")
	if not seated:
		print("PASSENGER_CHAIR_DEBUG: ", _game.network_session.get_passenger_replica_snapshot())
		return
	_check(_player.is_station_seated() and _player.is_control_enabled(), "confirmed passenger retains usable seated controls")
	_check(_craft.get_crew_role_authority() == null and _craft.get_local_input_source().get_authority_peer_id() == 1, "client passenger acquires neither physical role authority nor flight input producer")
	_check(_game._network_local_role_presentation().local_role == &"passenger", "client HUD names confirmed passenger role")
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
	await _walk(Vector3(0.0, 0.52, -6.80))
	_check(_craft.to_local(_player.global_position).distance_to(stood_local) > 0.6 and _player.is_on_floor(), "ordinary post-stand locomotion moves the supported passenger along the cabin aisle")
	await _walk(_craft.to_local(_craft.get_passenger_station_role_contract().entry_transform.origin))
	await _look(_craft.get_loadmaster_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_loadmaster_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "ordinary reseat succeeds without injected occupancy")
	print("PASSENGER_RESEAT_DEBUG: local=", _craft.to_local(_player.global_position), " floor=", _player.is_on_floor(), " control=", _player.is_control_enabled(), " candidate=", _game.station_interaction_candidate, " view=", _game.network_session.get_passenger_replica_snapshot(), " body_source=", _game.get_network_remote_body_intent_source().get_audit())
	_write("client.reseated", {})
	if not await _wait_file("host.reseat_checked", 10.0):
		return
	_write("client.migrate", {})
	if not await _wait_file("host.migrated", 12.0):
		return
	_check(await _until(func(): return not _player.is_seated() and _player.is_on_floor() and _player.is_control_enabled() and not bool(_game.get("_transition_busy")), 8.0), "migration restores usable local passenger body")
	_check(await _until(func():
		var source := _game.get_network_remote_body_intent_source()
		return source != null and source.is_bound() and source.get_audit().stream_id == 2 \
			and bool(source.get_audit().opening_confirmed) \
			and _game.station_interaction_candidate is ShipCrewSeat \
			and _game._network_client_boarding_holds(_craft)
	, 8.0), "fresh authenticated offer reopens the same body stream with the actual host clock")
	await _look(_craft.get_loadmaster_station_anchor().global_position + Vector3.UP * 1.2)
	await _press(&"interact")
	_check(await _until(func(): return _player.is_seated_at(_craft.get_loadmaster_station_anchor()) and not bool(_game.get("_transition_busy")), 8.0), "fresh post-migration ordinary chair claim succeeds")
	_write("client.disconnect_seated", {})
	if not await _wait_file("host.disconnect_ready", 10.0):
		return
	_game.shutdown_network_session(&"passenger_client_disconnect")
	_check(not _player.is_seated() and _player.is_control_enabled(), "disconnect leaves local passenger awake with controls")
	_write("client.disconnected", {})

func _walk(target_local: Vector3) -> void:
	var target := _craft.to_global(target_local)
	print("PASSENGER_WALK_START: local=", _craft.to_local(_player.global_position), " target=", target_local)
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
	print("PASSENGER_PEER_BOUNDARY: ", _role, " ", name)

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
