## test-matrix-display: input-only
extends SceneTree

## Two owned OS peers load actual Main. Each exterior hatch approach is staged;
## cabin walking, hatch opening, physical passenger chair and standing use Input.
## Claims remain on the authoritative host body and existing sealed role owner.
const Main := preload("res://scenes/main.tscn")
const Director := preload("res://scripts/audio/audio_director.gd")

# Install on Main's existing node before tree entry. Every request still enters
# the real resident bank/backend path, including its mandatory Dummy guard.
class NavigatorRequestSpy extends Director:
	var navigator_requests: Array[Dictionary] = []
	var _navigator_request_cue: StringName = &""
	func _on_semantic_cue(source: StringName, cue: StringName, intensity: float, position: Vector3) -> void:
		var previous := _navigator_request_cue
		_navigator_request_cue = cue if source == &"navigator" else &""
		super._on_semantic_cue(source, cue, intensity, position)
		_navigator_request_cue = previous
	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		if not _navigator_request_cue.is_empty():
			navigator_requests.append({"cue_id": _navigator_request_cue, "stream_id": stream_id, "bus": bus,
				"volume_db": volume_db, "effective_volume_db": volume_db + _effect_attenuation_db()})
		return super._play_resident(stream_id, bus, volume_db)

var _checks := 0
var _failures: Array[String] = []
var _directory := ""
var _role := ""
var _game: GameFlow
var _craft: HeroShip
var _cinder := false
var _navigator := false
var _navigator_rejection := false
var _navigator_result_packets: Array[Dictionary] = []
var _gunner := false
var _gunner_shots := 0
var _navigator_cues: Array[StringName] = []
var _navigator_captions: Array[Dictionary] = []
var _navigator_applied: Array[Dictionary] = []
var _navigator_records: Array[Dictionary] = []
var _navigator_first_claim_sequence := 0
var _navigator_observed_events := 0
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
var _profile_deadline := 0

# Select-only HALYARD-BOARD; inherited staged and Jovian callers stay unchanged.
const ORDINARY_WALK_ACTIONS := [&"move_forward", &"move_back", &"move_left", &"move_right"]
const ORDINARY_HALYARD_APPROACH := [
	Vector3(0, 0, 15.5), Vector3(0, 0, 39), Vector3(0, 0, 46.3),
	Vector3(0, 0, 51), Vector3(-5.7, 0, 51), Vector3(-5.7, 4.2, 61.2),
	Vector3(-3.5, 4.2, 61.5), Vector3(-3.5, 4.2, 64.2), Vector3(-3.5, 4.2, 68.3),
	Vector3(6, 4.2, 68.3), Vector3(13, 4.2, 68.3), Vector3(22, 4.2, 68.3),
	Vector3(37, 4.2, 68.3), Vector3(32.4, 4.2, 68.2), Vector3(32, 4.2, 62.2),
	Vector3(32, 4.2, 54.2),
]
var _ordinary_two_client_passenger_loss := false
var _ordinary_passenger_loss_retained: Dictionary = {}
var _ordinary_two_client_pilot_loss := false
var _ordinary_two_client_authority_stop := false
var _ordinary_two_client_moving := false
# Shared ordinary prefix/orchestration is also enabled for its moving continuation.
var _ordinary_two_client_board := false
var _ordinary_motion_active := false
var _ordinary_motion_min_speed := 0.0
var _ordinary_motion_samples := 0
var _ordinary_complete := false
var _ordinary_first_failure := false
var _ordinary_player_id := 0
var _ordinary_peer_id := 0
var _ordinary_initial_peer_generation := 0
var _ordinary_walking_identity: Dictionary = {}
var _ordinary_authority_adapter: NetworkEnetSessionAdapter
var _ordinary_authority_events: Dictionary = {}
var _ordinary_pilot_loss_events: Dictionary = {}
var _ordinary_pilot_loss_retained: Dictionary = {}

## Optional ordinary-controls callers share this harness and its owned exits.
## Empty defaults retain every existing Halyard/Cinder profile and deadline.
func _peer_profile() -> Dictionary:
	if _ordinary_two_client_board:
		return {"client_roles": ["client", "client_b"], "private_environment": true,
			"total_seconds": 300.0, "abort_exit_grace_seconds": 10.0}
	return {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_ordinary_two_client_passenger_loss = "--ordinary-two-client-passenger-loss" in args
	_ordinary_two_client_pilot_loss = "--ordinary-two-client-pilot-loss" in args
	_ordinary_two_client_authority_stop = "--ordinary-two-client-authority-stop" in args
	_ordinary_two_client_moving = "--ordinary-two-client-moving" in args or _ordinary_two_client_authority_stop or _ordinary_two_client_pilot_loss or _ordinary_two_client_passenger_loss
	_ordinary_two_client_board = "--ordinary-two-client-board" in args or _ordinary_two_client_moving
	if _ordinary_two_client_board:
		args.erase("--ordinary-two-client-board")
		args.erase("--ordinary-two-client-moving")
		args.erase("--ordinary-two-client-authority-stop")
		args.erase("--ordinary-two-client-pilot-loss")
		args.erase("--ordinary-two-client-passenger-loss")
		await _ordinary_run(args)
		return
	if "--exit-receipt-only" in args:
		await _test_exit_receipt_wait()
		return
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
	_navigator_rejection = "--navigator-rejection" in args
	args.erase("--navigator-rejection")
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
	if _navigator:
		_game.get_node("AudioDirector").set_script(NavigatorRequestSpy)
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
		_game._on_setting_change_requested(&"captions_enabled", true)
		_check(_game.runtime_settings.captions_enabled and _game.hud.are_captions_enabled(), "navigator route enables captions through actual production settings before capture")
		_game.audio.semantic_cue_emitted.connect(_capture_navigator_cue)
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
	var profile := _peer_profile()
	if profile.has("total_seconds"):
		_profile_deadline = Time.get_ticks_msec() + int(float(profile.total_seconds) * 1000.0)
	var ember_deadline := Time.get_ticks_msec() + int(EMBER_SURFACE_TOTAL_SECONDS * 1000.0)
	# Peers have separate tick clocks. Share this actual wall deadline for their
	# transit waits; the parent's unchanged monotonic cap still owns all setup.
	_ember_surface_total_deadline_unix = Time.get_unix_time_from_system() + EMBER_SURFACE_TOTAL_SECONDS
	var peer_root := OS.get_environment("TMPDIR")
	if peer_root.is_empty():
		peer_root = "/tmp"
	_directory = peer_root.path_join("mudds-passenger-peers-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_directory)
	_port = 26000 + OS.get_process_id() % 15000
	# Preserve each peer's private input window and real physics while matching
	# this suite's input-only renderer contract; no peer reads rendered pixels.
	var host_args := _peer_arguments("host", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy"]))
	var host := _spawn_peer("host", host_args)
	_check(host > 0, "owned independent host starts")
	var peers := {"host": host}
	var host_ready := host > 0 and await _wait_file("host.main_ready", 60.0)
	if host_ready:
		host_ready = await _wait_file("host.ready", 60.0)
	if host_ready:
		var client_roles: Array = profile.get("client_roles", ["client", "client_b"] if _shared_cruise else ["client"])
		for role in client_roles:
			var client_args := _peer_arguments(role, PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy"]))
			var client := _spawn_peer(role, client_args)
			peers[role] = client
			_check(client > 0, "owned independent peer starts: " + role)
		var shared_clients_ready := true
		if _shared_cruise or not profile.is_empty():
			# Cold Main startup has its own existing budget. The travel wait
			# begins only after both independent clients can participate.
			for role in client_roles:
				shared_clients_ready = await _wait_file(role + ".main_ready", 60.0) and shared_clients_ready
		if _shared_cruise and shared_clients_ready and await _wait_file("host.rebased", 60.0):
			var observer := _spawn_peer("observer", _peer_arguments("observer", PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy"])))
			peers["observer"] = observer
			_check(observer > 0, "owned late observer starts after actual origin commit")
			# The host waits for this observer before either crew chair route.
			# Give its cold Main the same startup gate as the initial clients,
			# before starting their unchanged 120-second completion budget.
			if observer > 0:
				await _wait_file("observer.main_ready", 60.0)
		var finished := true
		if _shared_cruise or not profile.is_empty():
			if not profile.is_empty():
				finished = shared_clients_ready
			for role in client_roles:
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
			_profile_deadline = 0 # Owned process cleanup has its separate exit grace.
			for role in peers:
				await _abort_peer(role)
	else:
		_profile_deadline = 0
		await _abort_peer("host")
	_profile_deadline = 0
	for role in peers:
		var result := _read(role + ".done")
		_check(not result.is_empty() and (result.get("failures", []) as Array).is_empty(), "%s ordinary production route passes" % role)
		if _ordinary_two_client_board:
			_check(bool(result.get("complete", false)), "%s selected ordinary scenario completed" % role)
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
		_print_peer_success()
	quit(0 if _failures.is_empty() else 1)

func _print_peer_success() -> void:
	if _ordinary_two_client_passenger_loss:
		print("HALYARD_ORDINARY_TWO_CLIENT_PASSENGER_LOSS_OK checks=%d" % _checks)
	elif _ordinary_two_client_pilot_loss:
		print("HALYARD_ORDINARY_TWO_CLIENT_PILOT_LOSS_OK checks=%d" % _checks)
	elif _ordinary_two_client_authority_stop:
		print("HALYARD_ORDINARY_TWO_CLIENT_AUTHORITY_STOP_OK checks=%d" % _checks)
	elif _ordinary_two_client_moving:
		print("HALYARD_ORDINARY_TWO_CLIENT_MOVING_OK checks=%d" % _checks)
	elif _ordinary_two_client_board:
		print("HALYARD_ORDINARY_TWO_CLIENT_BOARD_OK checks=%d" % _checks)
	elif _ember_surface:
		print("HALYARD_NETWORK_EMBER_PASSENGER_TERRAIN_OK checks=%d" % _checks)
	else:
		print("HALYARD_NETWORK_PASSENGER_ROUTE_TEST_OK checks=%d" % _checks)

func _abort_peer(role: String) -> void:
	var profile_exit_grace: float = float(_peer_profile().get("abort_exit_grace_seconds", 0.0))
	if profile_exit_grace > 0.0:
		# Opt-in callers retain failure capture and teardown before force-kill.
		# Their .exit waiter must ignore gameplay abort and profile deadlines.
		if await _wait_file(role + ".exit", profile_exit_grace):
			return
	elif FileAccess.file_exists(_directory.path_join(role + ".done")):
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
	var script: String = _peer_profile().get("script", "res://tests/network/halyard_network_passenger_route_test.gd")
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
	if _ordinary_two_client_passenger_loss:
		args.append("--ordinary-two-client-passenger-loss")
	elif _ordinary_two_client_pilot_loss:
		args.append("--ordinary-two-client-pilot-loss")
	elif _ordinary_two_client_authority_stop:
		args.append("--ordinary-two-client-authority-stop")
	elif _ordinary_two_client_moving:
		args.append("--ordinary-two-client-moving")
	elif _ordinary_two_client_board:
		args.append("--ordinary-two-client-board")
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
	if _navigator_rejection:
		args.append("--navigator-rejection")
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
	if bool(_peer_profile().get("private_environment", false)):
		var profile := _directory.path_join(role + "-profile")
		for folder in ["data", "config", "cache", "state", "runtime", "tmp", "data-dirs", "config-dirs"]:
			DirAccess.make_dir_recursive_absolute(profile.path_join(folder))
			_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile.path_join(folder)])) == 0, "private peer directory: " + role + "/" + folder)
		_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile])) == 0, "private peer profile root: " + role)
		# Preserve HOME/CODEX_HOME exactly. XDG homes/search paths and TMPDIR
		# are private; only this Xvfb's display is passed into its Godot actor.
		command = 'trap \'kill "$child" 2>/dev/null; wait "$child"; exit 143\' TERM INT HUP; /usr/bin/env -i DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$@" > "$0.log" 2>&1 & child=$!; printf "%s" "$child" > "$0.pid"; wait "$child"; status=$?; printf "%s" "$status" > "$0.exit"; exit "$status"'
		wrapper = PackedStringArray(["-a", "--server-args=-screen 0 1280x720x24 -nolisten unix -nolisten tcp", "/bin/sh", "-c", command, _directory.path_join(role), "/usr/bin/env", "PATH=/usr/local/bin:/usr/bin:/bin", "XDG_DATA_HOME=" + profile.path_join("data"), "XDG_CONFIG_HOME=" + profile.path_join("config"), "XDG_CACHE_HOME=" + profile.path_join("cache"), "XDG_STATE_HOME=" + profile.path_join("state"), "XDG_RUNTIME_DIR=" + profile.path_join("runtime"), "XDG_DATA_DIRS=" + profile.path_join("data-dirs"), "XDG_CONFIG_DIRS=" + profile.path_join("config-dirs"), "TMPDIR=" + profile.path_join("tmp")])
		for key in ["HOME", "CODEX_HOME", "GODOT_SILENCE_ROOT_WARNING"]:
			if OS.has_environment(key):
				wrapper.append(key + "=" + OS.get_environment(key))
		wrapper.append(OS.get_executable_path())
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
	await _walk(Vector3(-1.85, -0.86, -1.7) if _cinder else Vector3(0.0, 0.52, HalyardCrewTransport.AIRSTAIR_Z), 0.10 if _navigator else 0.30)
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
	if _navigator_rejection:
		await _host_navigator_refusals()
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
	if _navigator:
		_game.network_session.crew_snapshot_applied.connect(_capture_navigator_applied)
		_game.network_session.navigator_request_result_received.connect(func(packet: Dictionary):
			_navigator_result_packets.append(packet.duplicate(true)))
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
		if _navigator_rejection:
			await _client_navigator_refusals()
		await _press(&"fire")
		_check(await _until(func(): return _role_effect_ready(_game.network_session.get_passenger_replica_snapshot().get("navigator" if _navigator else "manifest", {})), 5.0), "remote ordinary seated FIRE reaches host manifest consumer and confirms receipt")
		if _navigator:
			_check(await _until(func(): return _navigator_request_count(&"cinder_navigator_ping_accepted") == 1 and _navigator_records.size() >= 1, 5.0), "client first real chair FIRE receives exactly one confirmation request from applied crew command")
			_check_navigator_feedback(1, 0, "first ordinary chair FIRE")
			_navigator_first_claim_sequence = int((_game.network_session.get_passenger_replica_snapshot().get("assignment", {}) as Dictionary).get("claim_sequence", 0))
			_check(_navigator_first_claim_sequence > 0, "first accepted client receipt belongs to actual confirmed passenger claim")
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
	if _navigator:
		_check(await _until(func(): return _navigator_request_count(&"cinder_navigator_ping_cleared") == 1, 5.0), "client ordinary stand receives one real matching clear")
		_check((_game.network_session.get_passenger_replica_snapshot().get("assignment", {}) as Dictionary).is_empty(), "client clear survives already empty passenger assignment")
		_check_navigator_feedback(1, 1, "ordinary stand")
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
		_check(await _until(func(): return _navigator_request_count(&"cinder_navigator_ping_accepted") == 2, 5.0), "client actual reseat FIRE receives distinct accepted receipt")
		_check_navigator_feedback(2, 1, "ordinary reseat FIRE")
		var accepted_records := _navigator_commands(&"passenger_ping")
		var reseated_claim := int((_game.network_session.get_passenger_replica_snapshot().get("assignment", {}) as Dictionary).get("claim_sequence", 0))
		_check(reseated_claim > 0 and reseated_claim != _navigator_first_claim_sequence, "real reseat replaces the first confirmed passenger claim sequence")
		_check(accepted_records.size() == 2 and accepted_records[0] != accepted_records[1]
			and (accepted_records[0].request_sequence != accepted_records[1].request_sequence or accepted_records[0].ship_generation != accepted_records[1].ship_generation or accepted_records[0].server_tick != accepted_records[1].server_tick), "two pre-migration accepted commands retain distinct actual request/publication identities")
	print("PASSENGER_RESEAT_DEBUG: local=", _craft.to_local(_player.global_position), " floor=", _player.is_on_floor(), " control=", _player.is_control_enabled(), " candidate=", _game.station_interaction_candidate, " view=", _game.network_session.get_passenger_replica_snapshot(), " body_source=", _game.get_network_remote_body_intent_source().get_audit())
	_write("client.reseated", {})
	if not await _wait_file("host.reseat_checked", 10.0):
		return
	if _navigator:
		_check(await _until(func(): return _navigator_request_count(&"cinder_navigator_ping_cleared") == 2, 5.0), "client retained publication delivers exactly one clear after real host row revocation")
		_check_navigator_feedback(2, 2, "host retained-publication retirement")
		var replay_requests := (_game.audio as NavigatorRequestSpy).navigator_requests.size()
		var replay_captions := _navigator_captions.size()
		var replay_callback: Callable = _game._client_navigator_audio_callback
		for applied: Dictionary in _navigator_applied:
			var original := applied.duplicate(true)
			replay_callback.call(applied)
			_check(applied == original, "actual applied accepted/clear replay preserves unchanged transported records")
		_check((_game.audio as NavigatorRequestSpy).navigator_requests.size() == replay_requests and _navigator_captions.size() == replay_captions, "old actual accepted and clear command replay produces no sound or caption")
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
	if _navigator:
		_check(await _until(func(): return _navigator_request_count(&"cinder_navigator_ping_accepted") == 3, 5.0), "actual migration stream-2 rebind/reseat/FIRE produces new client acceptance")
		_check_navigator_feedback(3, 2, "post-migration rebind and reseat FIRE")
		var accepted_records := _navigator_commands(&"passenger_ping")
		_check(accepted_records.size() == 3 and int(accepted_records[2].migration_generation) > int(accepted_records[1].migration_generation), "post-migration accepted command carries actual newer transported epoch")
	_write("client.disconnect_seated", {})
	if not await _wait_file("host.disconnect_ready", 10.0):
		return
	var retiring_adapter: NetworkEnetSessionAdapter = _game.network_session
	var retiring_callback: Callable = _game._client_navigator_audio_callback
	var retiring_source: Node = _game.optional_semantic_audio_composition._client_navigator_composition._binding if _navigator else null
	var retired_request_count := (_game.audio as NavigatorRequestSpy).navigator_requests.size() if _navigator else 0
	if _navigator:
		_check(is_instance_valid(retiring_source), "real disconnect has the exact current navigator source to retire")
	_game.shutdown_network_session(&"passenger_client_disconnect")
	if _navigator:
		_check(not retiring_adapter.crew_snapshot_applied.is_connected(retiring_callback) and not bool(_game.optional_semantic_audio_composition.get_snapshot().client_navigator.attached), "real disconnect retires exact current client callback and source flags")
		if is_instance_valid(retiring_source):
			retiring_source.semantic_navigator_ping_cue_emitted.emit(&"cinder_navigator_ping_accepted", 0.7)
		for applied: Dictionary in _navigator_applied:
			retiring_callback.call(applied)
		_check((_game.audio as NavigatorRequestSpy).navigator_requests.size() == retired_request_count, "real disconnect leaves old adapter callbacks and exact unbound source silent")
		_check(bool(_game.audio.get_audit_report().get("valid", false)), "client route request spy preserves real Dummy playback/backend lifecycle")
	_check(not _player.is_seated() and _player.is_control_enabled(), "disconnect leaves local passenger awake with controls")
	_write("client.disconnected", {})


## Separate opt-in refusal episode; all original walk/chair/accepted/clear/
## reseat/migration/disconnect stages and their caps remain unchanged.
func _host_navigator_refusals() -> void:
	if not await _wait_file("client.refusal_ready", 60.0):
		return
	var binding := _game._network_engineer_binding.loadmaster
	var original: Callable = binding.navigator_submit
	var before := _navigator_request_count(&"cinder_navigator_ping_rejected")
	var receipt: Dictionary = _craft.get_navigator_ping_snapshot().get("receipt", {}).duplicate(true)
	_check(receipt.is_empty(), "refusal episode begins before the client's first accepted receipt")
	binding.navigator_submit = Callable()
	_write("host.missing_ready", {})
	if not await _wait_file("client.missing_done", 10.0):
		binding.navigator_submit = original
		return
	binding.navigator_submit = original
	var bridge := binding._navigator_bridge
	bridge.detach(&"test_actual_consumer_unavailable")
	_write("host.detached_ready", {})
	if not await _wait_file("client.detached_done", 10.0):
		bridge.attach(_game.network_session, _craft, int(binding._generation))
		return
	_check(_craft.get_navigator_ping_snapshot().get("receipt", {}) == receipt, "actual missing callback and detached bridge refusals do not change navigator gameplay")
	_check(_navigator_request_count(&"cinder_navigator_ping_rejected") == before, "host has no requester-only refusal sound or caption echo")
	# Deliver the captured real response over ENet again, including an actual
	# foreign-recipient envelope. The requester must hear neither delivery.
	var captured := _read("client.detached_done")
	var packet: Dictionary = captured.get("packet", {})
	var peer := int(packet.get("recipient_peer_id", 0))
	if peer > 1:
		_game.network_session._receive_navigator_request_result.rpc_id(peer, packet)
		var foreign := packet.duplicate(true)
		foreign.recipient_peer_id = peer + 1
		_game.network_session._receive_navigator_request_result.rpc_id(peer, foreign)
	bridge.attach(_game.network_session, _craft, int(binding._generation))
	_write("host.refusal_restored", {})
	await _wait_file("client.refusal_replay_checked", 10.0)

func _client_navigator_refusals() -> void:
	_write("client.refusal_ready", {})
	for episode in ["missing", "detached"]:
		if not await _wait_file("host." + episode + "_ready", 10.0):
			return
		var before := _navigator_result_packets.size()
		var requests := _navigator_request_count(&"cinder_navigator_ping_rejected")
		var captions := _navigator_captions.size()
		for press in 2:
			await _press_navigator_refusal_fire()
			_check(await _until(func(): return _navigator_result_packets.size() == before + press + 1, 5.0), "actual " + episode + " FIRE receives one immediate requester response")
		_check(_navigator_request_count(&"cinder_navigator_ping_rejected") == requests + 2 and _navigator_captions.size() == captions + 2, "two distinct " + episode + " presses create two existing alert requests and actual captions")
		_check(_navigator_records.is_empty() and not _role_effect_ready(_game.network_session.get_passenger_replica_snapshot().get("navigator", {})), "actual " + episode + " refusals create no accepted navigator command or gameplay receipt")
		var first: Dictionary = _navigator_result_packets[before]
		var second: Dictionary = _navigator_result_packets[before + 1]
		_check(first.result == second.result and first.request.request_sequence != second.request.request_sequence, "equal actual refusal statuses preserve two original client sequences")
		_check(first.result.status == (&"navigator_consumer_unavailable" if episode == "missing" else &"detached"), "real " + episode + " owner returns its actual refusal status")
		_check(not first.request.has("ship_generation") and not second.request.has("ship_generation"), "pre-acceptance refusal never fabricates a transported ship generation")
		for index in range((_game.audio as NavigatorRequestSpy).navigator_requests.size() - 2, (_game.audio as NavigatorRequestSpy).navigator_requests.size()):
			var item: Dictionary = (_game.audio as NavigatorRequestSpy).navigator_requests[index]
			_check(item.stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY and item.bus == &"UI" and _navigator_captions[index].caption == "Navigator ping rejected", "actual refusal retains existing UI alert and real caption")
		var callback: Callable = _game._client_navigator_result_callback
		callback.call(first)
		callback.call(second)
		var old_input: Dictionary = first.request.duplicate(true)
		old_input.erase("ship_id")
		old_input.erase("seat_id")
		_game.network_session.send_engineer_intent(old_input)
		var foreign_input := old_input.duplicate(true)
		foreign_input.avatar_id = &"foreign_navigator"
		foreign_input.request_sequence = int(second.request.request_sequence) + 1
		_game.network_session.send_engineer_intent(foreign_input)
		await _ticks(12)
		_check(_navigator_result_packets.size() == before + 2, "actual replayed and foreign original ENet inputs remain silent")
		_check(_navigator_request_count(&"cinder_navigator_ping_rejected") == requests + 2, "same original result replay remains silent")
		_write("client." + episode + "_done", {"packet": second})
	if not await _wait_file("host.refusal_restored", 10.0):
		return
	await _ticks(12)
	_check(_navigator_request_count(&"cinder_navigator_ping_rejected") == 4 and _navigator_captions.size() == 4, "actual reliable replay and foreign-recipient delivery stay silent")
	_check(_game._client_navigator_pending.is_empty(), "all four real refusal terminals retire their own pending records")
	_write("client.refusal_replay_checked", {})

func _capture_navigator_cue(source: StringName, cue: StringName, _intensity: float, _position: Vector3) -> void:
	_navigator_cues.append(cue)
	if source != &"navigator":
		return
	# Main's existing semantic callback ran first; inspect its actual presenter.
	var presenter: RefCounted = _game.hud.get("_semantic_audio_cue_presenter") as RefCounted
	var caption: Dictionary = presenter.call(&"get_snapshot")
	_check(caption.get("cue_id") == cue and caption.get("source") == &"navigator", "real Main semantic presenter consumes navigator event")
	_navigator_captions.append(caption.duplicate(true))


func _capture_navigator_applied(result: Dictionary) -> void:
	if result.get("accepted") != true or result.get("status") != &"crew_snapshot_applied":
		return
	var commands: Array = (result.get("snapshot", {}) as Dictionary).get("commands", [])
	for command: Dictionary in commands:
		if command.get("action") not in [&"passenger_ping", &"passenger_ping_clear"]:
			continue
		if not _navigator_records.has(command):
			_navigator_records.append(command.duplicate(true))
		# Fixture observations only: never dispatch, rewrite, or replace a command.
		# The immediate signal listener survives Main's context-driven rebinds;
		# retain its actual connection order rather than assuming it runs first.
		_navigator_observed_events += 1
		var observation := {
			"kind": "fixture_navigator_presentation_diagnostic",
			"event": _navigator_observed_events,
			"revision": result.get("revision"),
			"snapshot_epoch": _navigator_diagnostic_fields(result.snapshot, ["migration_generation", "server_tick", "ship_generation"]),
			"snapshot_roles": _navigator_diagnostic_json(result.snapshot.get("roles", [])),
			"command": command.duplicate(true),
			"command_json_at_signal": JSON.stringify(command),
			"before_dispatch_observation": _navigator_presentation_observation(),
		}
		var name := "%s.navigator-event-%04d.json" % [_role, _navigator_observed_events]
		_write(name, observation)
		_capture_navigator_after_dispatch.call_deferred(name, observation, command)
	if not commands.is_empty():
		_navigator_applied.append(result.duplicate(true))


func _capture_navigator_after_dispatch(name: String, observation: Dictionary, command: Dictionary) -> void:
	# Deferred from this exact applied event, after every synchronous production
	# listener. Keep the original command copy and compare the live record bytes.
	observation["command_json_after_dispatch"] = JSON.stringify(command)
	observation["command_unchanged"] = observation.command_json_at_signal == JSON.stringify(command)
	observation["after_dispatch_observation"] = _navigator_presentation_observation()
	_write(name, observation)


func _navigator_presentation_observation() -> Dictionary:
	var adapter := _game.network_session
	var offer: Dictionary = adapter.get_server_offer()
	var admission: Dictionary = offer.get("admission", {})
	var composition: Node = _game.optional_semantic_audio_composition
	var source: Node = composition._client_navigator_composition if is_instance_valid(composition) else null
	var binding: Node = source._binding if is_instance_valid(source) else null
	var callback: Callable = _game._client_navigator_audio_callback
	var listeners: Array = []
	for connection: Dictionary in adapter.crew_snapshot_applied.get_connections():
		var listener: Callable = connection.callable
		listeners.append({"object_id": listener.get_object_id(), "method": str(listener.get_method()),
			"bound_arguments": _navigator_diagnostic_json(listener.get_bound_arguments()), "flags": connection.flags})
	return {
		"physics_frame": Engine.get_physics_frames(), "ticks_msec": Time.get_ticks_msec(),
		"adapter_id": adapter.get_instance_id(), "adapter_inside_tree": adapter.is_inside_tree(),
		"session_mode": _game._network_session_mode, "session_live": _game._network_session_is_live(),
		"is_server": adapter.is_server(), "client_peer": _game._network_client_peer_id(),
		"latest_requested_peer_generation": int(adapter.get("_next_peer_generation")) - 1,
		"current_transport_peer": _navigator_diagnostic_fields(adapter._transport.get_peer(_game._network_client_peer_id()), ["peer_id", "peer_generation", "active"]),
		"admission": _navigator_diagnostic_fields(admission, ["accepted", "status"]),
		"offered_admission_peer": _navigator_diagnostic_fields(admission.get("peer", {}), ["peer_id", "peer_generation"]),
		"offered_transport": _navigator_diagnostic_fields(offer.get("transport", {}), ["peer_id", "peer_generation", "session_generation"]),
		"offered_epoch": _navigator_diagnostic_fields((offer.get("migration", {}) as Dictionary).get("epoch", {}), ["protocol_version", "package_generation", "session_generation", "migration_generation"]),
		"current_epoch": _navigator_diagnostic_fields(adapter.get_migration_snapshot(), ["protocol_version", "package_generation", "session_generation", "migration_generation"]),
		"main_inside_tree": _game.is_inside_tree(), "phase": _game.phase,
		"route_craft": _navigator_diagnostic_object(_craft),
		"cabin_craft": _navigator_diagnostic_object(_game._cabin_ship),
		"remote_helm_craft": _navigator_diagnostic_object(_game._network_client_remote_helm_ship()),
		"boarding_claim": _navigator_diagnostic_json(_game._network_client_boarding_claim),
		"boarding_holds_route_craft": _game._network_client_boarding_holds(_craft),
		"callback_adapter": _navigator_diagnostic_object(_game._client_navigator_audio_adapter),
		"callback_epoch": _game._client_navigator_audio_epoch,
		"callback_migration": _game._client_navigator_audio_migration,
		"callback_valid": callback.is_valid(), "callback_bound_arguments": _navigator_diagnostic_json(callback.get_bound_arguments()),
		"callback_connected": adapter.crew_snapshot_applied.is_connected(callback), "signal_listener_order": listeners,
		"captured_context": _navigator_diagnostic_json(_game._client_navigator_audio_context),
		"current_context": _navigator_diagnostic_json(_game._current_client_navigator_audio_context()),
		"seen_receipts": _navigator_diagnostic_json(_game._client_navigator_audio_seen),
		"composition": _navigator_diagnostic_object(composition),
		"composition_attached": bool(composition._attached) if is_instance_valid(composition) else false,
		"composition_context": _navigator_diagnostic_json(composition._client_navigator_context) if is_instance_valid(composition) else {},
		"composition_generation": int(composition._client_navigator_generation) if is_instance_valid(composition) else 0,
		"source": _navigator_diagnostic_object(source),
		"source_attached": bool(source._attached) if is_instance_valid(source) else false,
		"binding": _navigator_diagnostic_object(binding),
		"binding_snapshot": _navigator_diagnostic_json(binding.get_snapshot()) if is_instance_valid(binding) else {},
		"real_director_requests": _navigator_diagnostic_json((_game.audio as NavigatorRequestSpy).navigator_requests),
		"real_captions": _navigator_diagnostic_json(_navigator_captions),
	}


func _navigator_diagnostic_fields(value: Dictionary, fields: Array) -> Dictionary:
	var selected: Dictionary = {}
	for field in fields:
		if value.has(field):
			selected[field] = _navigator_diagnostic_json(value[field])
	return selected


func _navigator_diagnostic_object(value: Variant) -> Dictionary:
	if not is_instance_valid(value):
		return {"exists": false}
	var observed := {"exists": true, "instance_id": value.get_instance_id(), "class": value.get_class()}
	if value is Node:
		observed["inside_tree"] = value.is_inside_tree()
		observed["queued_for_deletion"] = value.is_queued_for_deletion()
	if value is HeroShip:
		observed["ship_id"] = str(value.get_ship_id())
		observed["destroyed"] = value.is_destroyed()
	return observed


func _navigator_diagnostic_json(value: Variant) -> Variant:
	# Only called on the selected observation fields above. Nodes in recipient
	# contexts become IDs, never Godot object strings or serialized instances.
	if value is Object:
		return _navigator_diagnostic_object(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[str(key)] = _navigator_diagnostic_json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_navigator_diagnostic_json(item))
		return result
	if value is StringName:
		return str(value)
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	return {"unsupported_variant_type": type_string(typeof(value))}


func _navigator_request_count(cue: StringName) -> int:
	var count := 0
	for request: Dictionary in (_game.audio as NavigatorRequestSpy).navigator_requests:
		if request.cue_id == cue:
			count += 1
	return count


func _navigator_commands(action: StringName) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for command: Dictionary in _navigator_records:
		if command.action == action:
			records.append(command)
	return records


func _check_navigator_feedback(accepted: int, cleared: int, stage: String) -> void:
	var all_requests: Array[Dictionary] = (_game.audio as NavigatorRequestSpy).navigator_requests
	var expected_refusals := 4 if _navigator_rejection else 0
	_check(_navigator_request_count(&"cinder_navigator_ping_rejected") == expected_refusals, stage + " retains the exact selected zero/four refusal count")
	_check(all_requests.size() == accepted + cleared + expected_refusals and _navigator_captions.size() == all_requests.size(), stage + " retains the full exact request and real caption cardinality")
	if _navigator_captions.size() != all_requests.size():
		return
	var requests: Array[Dictionary] = []
	var captions: Array[Dictionary] = []
	for index in (_game.audio as NavigatorRequestSpy).navigator_requests.size():
		var item: Dictionary = (_game.audio as NavigatorRequestSpy).navigator_requests[index]
		if item.cue_id != &"cinder_navigator_ping_rejected":
			requests.append(item)
			captions.append(_navigator_captions[index])
	_check(requests.size() == accepted + cleared and captions.size() == requests.size(), stage + " has exactly one navigator request and real caption per outcome")
	_check(_navigator_commands(&"passenger_ping").size() == accepted and _navigator_commands(&"passenger_ping_clear").size() == cleared, stage + " correlates with successfully applied actual crew commands")
	for index in requests.size():
		var request: Dictionary = requests[index]
		var is_accept: bool = request.cue_id == &"cinder_navigator_ping_accepted"
		_check(request.stream_id == (Director.STREAM_UI_CONFIRM if is_accept else Director.STREAM_CANOPY_CLOSE) and request.bus == &"UI", stage + " selects existing navigator confirmation/clear UI resident stream")
		_check(captions[index].get("caption", "") == ("Navigator ping accepted" if is_accept else "Navigator ping cleared"), stage + " preserves real accepted/clear caption text")


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
	if _ordinary_two_client_board:
		# Same real cockpit walk/aim/Interact seam, stopping before flight demand.
		var pilot_anchor := _craft.get_pilot_seat_anchor()
		if not await _ordinary_walk_to(_craft.to_global(_craft.to_local(pilot_anchor.global_position) + Vector3(-0.6, 0.0, 0.6)), true):
			return
		await _ordinary_look(pilot_anchor.global_position)
		await _ordinary_press(&"interact")
		await _ordinary_boundary(_ordinary_local_pilot_is_current, 8.0,
			"ordinary cockpit Interact confirms actual pilot seat and enabled owner without thrust")
		return
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

func _walk(target_local: Vector3, arrival_tolerance: float = 0.30) -> void:
	var start := _player.global_position
	var furthest := 0.0
	var source := _game.get_network_remote_body_intent_source()
	# Ordinary Halyard prediction can arrive before reconciliation moves it
	# away again before the blind final sample. Reuse the same bounded settlement.
	var settle_authoritative := (_ember_surface or _shared_cruise \
		or _craft.get_ship_id() == GameFlow.HALYARD_SHIP_ID) and _role in ["client", "client_b"] \
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
		if delta.length() < arrival_tolerance and (not settle_authoritative or not current or authoritative_delta.length() < arrival_tolerance):
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
			var settled: bool = delta.length() < arrival_tolerance and current \
				and authoritative_delta.length() < arrival_tolerance \
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
		if settle_authoritative:
			# A delayed host pose can restart feedback after predicted arrival.
			# Keep this ordinary analog correction just above the authored 0.18
			# deadzone; the former 0.6 floor drove nearly 3 m/s at the waypoint
			# and could repeatedly overshoot before the host pose caught up.
			axis *= clampf(delta.length() / 1.5, 0.2, 1.0)
		elif _cinder or _host_gunner_flight or _shared_cruise or _ember_surface:
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

## Identical remapped key edges and ticks to ordinary FIRE. This episode's
## actual correlated refusal and caption checks own its expected outcome.
func _press_navigator_refusal_fire() -> void:
	_fire_key(true)
	await _ticks(2)
	_fire_key(false)
	await _ticks(3)

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
		if _profile_deadline > 0 and Time.get_ticks_msec() >= _profile_deadline:
			return false
		if _ordinary_two_client_board and _ordinary_aborted():
			return false
		await _ticks(1)
	return false

func _ember_surface_seconds_remaining() -> float:
	return clampf(_ember_surface_total_deadline_unix - Time.get_unix_time_from_system(),
		0.0, EMBER_SURFACE_TOTAL_SECONDS)

func _ticks(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame
		if _ordinary_motion_active and is_instance_valid(_craft):
			_ordinary_motion_min_speed = minf(_ordinary_motion_min_speed, _craft.velocity.length())
			_ordinary_motion_samples += 1

func _wait_file(name: String, seconds: float) -> bool:
	if _ordinary_two_client_board:
		# Actual wrapper exits retain the full independent 10s cleanup grace.
		if name.ends_with(".exit"):
			var exit_deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
			while Time.get_ticks_msec() < exit_deadline and not FileAccess.file_exists(_directory.path_join(name)):
				await _ticks(1)
			return _ordinary_require(FileAccess.file_exists(_directory.path_join(name)), "actual owned OS exit receipt: " + name)
		return await _ordinary_boundary(func(): return FileAccess.file_exists(_directory.path_join(name)), seconds,
			"peer boundary arrives: " + name)
	# A finished host cannot reach further gameplay boundaries, but its shell
	# still needs the full existing exit deadline to reap the actual process.
	var host_gameplay_boundary := name in ["host.ready", "host.rebased"] \
		or (_ember_surface and name.begins_with("host.") and name != "host.exit")
	var result := await _until(func(): return FileAccess.file_exists(_directory.path_join(name)) or (host_gameplay_boundary and FileAccess.file_exists(_directory.path_join("host.done"))), seconds)
	result = result and FileAccess.file_exists(_directory.path_join(name))
	_check(result, "peer boundary arrives: " + name)
	return result

func _test_exit_receipt_wait() -> void:
	_ember_surface = true
	_directory = "/tmp/mudds-passenger-exit-receipt-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(_directory)
	_write("host.done", {})
	# Gameplay completion precedes the wrapper's actual OS exit receipt.
	var delayed_exit := create_timer(0.2)
	delayed_exit.timeout.connect(func(): _write("host.exit", {}))
	var received := await _wait_file("host.exit", 10.0)
	_check(received, "host completion still waits for the separately published exit receipt")
	if delayed_exit.time_left > 0.0:
		await delayed_exit.timeout
	for name in ["host.done", "host.exit"]:
		DirAccess.remove_absolute(_directory.path_join(name))
	DirAccess.remove_absolute(_directory)
	for failure in _failures:
		push_error(failure)
	print("PASSENGER_EXIT_RECEIPT: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

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
		if _navigator_rejection and not _role.is_empty() and not FileAccess.file_exists(_directory.path_join(_role + ".first_failure")):
			_write(_role + ".first_failure", {"description": description})
			print("NAVIGATOR_FIRST_FAILURE: ", _role, " ", description)
		if _ordinary_two_client_board and not _role.is_empty() and not _ordinary_first_failure:
			_ordinary_first_failure = true
			var first_abort := DirAccess.make_dir_absolute(_directory.path_join("abort-owner")) == OK
			_write(_role + ".first_failure", _ordinary_failure_snapshot(description))
			if first_abort:
				_write("abort", {"role": _role, "description": description, "snapshot": _role + ".first_failure"})

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
	# Finish the ordinary cockpit approach before admitting independent peers.
	# Their unchanged preparation deadline must not pay for host setup walking.
	var pilot := _craft.get_pilot_seat_anchor()
	await _walk(Vector3(0.0, 0.52, -9.2))
	await _walk(_craft.to_local(pilot.global_position) + Vector3(-0.6, 0.0, 0.6))
	await _look(pilot.global_position)
	_game._refresh_interaction_targets()
	print("SHARED_HOST_COCKPIT_APPROACH: local=", _craft.to_local(_player.global_position), " phase=", _game.phase, " boarding=", _game.boarding_candidate, " candidate=", _game.station_interaction_candidate, " near=", _player.get_nearby_interactables(), " floor=", _player.is_on_floor())
	_write("host.ready", {})
	if not await _wait_file("client.cabin", 60.0) or not await _wait_file("client_b.cabin", 60.0):
		return
	# Leave the physical hatch open until both crew have actually boarded.
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


## Selected ordinary boarding helpers reuse the accepted Jovian input contracts.
func _ordinary_observe_supported_cabin(role: String, peer: int) -> bool:
	var receipt := _read(role + ".cabin")
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var record := simulation.get_body_record(avatar)
	return _ordinary_require(body != null and body.is_on_floor() and not body.is_seated()
		and int(record.get("owner_peer_id", 0)) == peer
		and int(record.get("entity_generation", 0)) == int(receipt.get("entity_generation", -1))
		and str(receipt.get("entity_id", "")) == str(avatar)
		and body.get_cabin_containment_report().get("frame") == _craft,
		"server observes supported real remote body with same admitted peer/entity generation: " + role)

func _ordinary_publication(avatar: StringName) -> Dictionary:
	return (_game.get("_network_moving_interior_records") as Dictionary).get(avatar, {})

func _ordinary_pilot_is_current(peer: int) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var publication := _ordinary_publication(avatar)
	var wire := publication.get("wire", {}) as Dictionary
	var initial := _read("client.cabin")
	var remote := (_game.get("_network_remote_pilots") as Dictionary).get(_craft.get_ship_id(), {}) as Dictionary
	var occupancy := false
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == peer and held.get("avatar_id") == avatar \
			and held.get("ship_id") == _craft.get_ship_id() and held.get("role") == &"pilot" \
			and held.get("seat_id") == StringName("%s_pilot" % _craft.get_ship_id()):
			occupancy = true
	return occupancy and _craft.is_remote_piloted() and int(remote.get("peer_id", 0)) == peer \
		and publication.get("occupant") == _craft.get_pilot_seat_anchor() and bool(publication.get("seated", false)) \
		and int(publication.get("remote_pilot_peer_id", 0)) == peer and int(publication.get("owner_peer_id", 0)) == peer \
		and wire.get("entity_id") == avatar and int(wire.get("entity_generation", 0)) == int(initial.get("entity_generation", -1)) \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED \
		and int(publication.get("published_tick", -1)) > 0

func _ordinary_passenger_is_current(peer: int) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if body == null or owner == null:
		return false
	var assignment: Dictionary = owner.get_assignment(peer, avatar)
	var seat := simulation.get_body_crew_seat(avatar)
	var identity := _read("client_b.cabin")
	var publication := _ordinary_publication(avatar)
	return body.is_seated_at(_station_anchor()) \
		and seat != null and seat.get_seat_anchor() == _station_anchor() \
		and assignment.get("role") == &"passenger" and assignment.get("seat_id") == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 and int(assignment.get("claim_sequence", 0)) > 0 \
		and int(simulation.get_body_record(avatar).get("entity_generation", 0)) == int(identity.get("entity_generation", -1)) \
		and publication.get("occupant") == body and int(publication.get("owner_peer_id", 0)) == peer \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_SEATED \
		and int(publication.get("published_tick", -1)) > 0

func _ordinary_local_pilot_is_current() -> bool:
	var claim: Dictionary = _game.get("_network_client_boarding_claim") as Dictionary
	var source: LocalShipInputSource = _craft.get_local_input_source()
	return _ordinary_same_identity() and not _game.get("_transition_busy") and _player.is_seated_at(_craft.get_pilot_seat_anchor()) \
		and bool(_game.get("_piloting")) and claim.get("role") == &"pilot" and claim.get("ship_id") == _craft.get_ship_id() \
		and _ordinary_walking_identity_is_preserved() \
		and _ordinary_hud_role_is_current(&"pilot") and source != null \
		and source.is_enabled_owner() and source.get_authority_peer_id() == _ordinary_peer_id

func _ordinary_walking_identity_is_preserved() -> bool:
	# The local claim owns only ship/seat/role. The host's body observation and
	# _ordinary_pilot_is_current tie this saved entity generation to its real publication.
	return int(_ordinary_walking_identity.get("peer_id", 0)) == _ordinary_peer_id \
		and StringName(_ordinary_walking_identity.get("entity_id", "")) == GameFlow.network_client_boarding_avatar_id(_ordinary_peer_id) \
		and int(_ordinary_walking_identity.get("entity_generation", 0)) > 0 \
		and str(_ordinary_walking_identity.get("player_id", "")) == str(_ordinary_player_id) \
		and _player.get_instance_id() == _ordinary_player_id

func _ordinary_local_passenger_is_current() -> bool:
	var view := _game.network_session.get_passenger_replica_snapshot()
	var assignment := view.get("assignment", {}) as Dictionary
	return _ordinary_same_identity() and not _game.get("_transition_busy") \
		and _player.is_seated_at(_station_anchor()) \
		and _player.is_station_seated() and _player.is_control_enabled() and not bool(_game.get("_piloting")) \
		and bool(view.get("seated", false)) and view.get("ship_id") == _craft.get_ship_id() \
		and assignment.get("seat_id") == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID \
		and int(assignment.get("seat_generation", 0)) > 0 and int(assignment.get("claim_sequence", 0)) > 0 \
		and _ordinary_hud_role_is_current(&"passenger") and _objective_text().contains("PASSENGER ABOARD") \
		and _craft.get_crew_role_authority() == null and _game.get("_network_engineer_source") == null

func _ordinary_hud_role_is_current(role: StringName) -> bool:
	# Read the actual HUD presenter's consumed snapshot, not a freshly computed
	# GameFlow role. Rendering/pixel visibility is outside this input-only suite.
	var presenter := _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	var snapshot := presenter.get_snapshot()
	return snapshot.get("local_role") == role and str(snapshot.get("ownership_text", "")) == str(role).to_upper() \
		and str(snapshot.get("controlled_craft", "")) == _craft.get_display_name()

func _ordinary_supported_cabin() -> bool:
	var source := _game.get_network_remote_body_intent_source()
	return _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN and not _game.get("_transition_busy") \
		and _player.is_control_enabled() and _player.is_on_floor() and source != null and source.is_bound() \
		and bool(source.get_audit().get("opening_confirmed", false))

func _ordinary_authenticated() -> bool:
	var session := _game.network_session
	if not is_instance_valid(session) or not session.is_session_active():
		return false
	var offer := session.get_server_offer()
	var admission := offer.get("admission", {}) as Dictionary
	var peer := admission.get("peer", {}) as Dictionary
	var transport := offer.get("transport", {}) as Dictionary
	var epoch := (offer.get("migration", {}) as Dictionary).get("epoch", {}) as Dictionary
	var current := session.get_migration_snapshot()
	var identity := session.multiplayer.get_unique_id()
	if not bool(admission.get("accepted", false)) or identity <= 1 or int(peer.get("peer_id", 0)) != identity \
		or int(peer.get("peer_generation", 0)) <= 0 or int(transport.get("peer_id", 0)) != identity \
		or int(transport.get("peer_generation", 0)) != int(peer.get("peer_generation", 0)) \
		or str(transport.get("auth_token", "")).is_empty():
		return false
	for key in ["package_generation", "session_generation", "migration_generation"]:
		if int(epoch.get(key, 0)) <= 0 or epoch.get(key) != current.get(key):
			return false
	return true

func _ordinary_same_identity() -> bool:
	var peer := ((_game.network_session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary)
	return _ordinary_authenticated() and _game.network_session.multiplayer.get_unique_id() == _ordinary_peer_id \
		and int(peer.get("peer_generation", 0)) == _ordinary_initial_peer_generation

func _ordinary_peer_generation(peer_id: int) -> int:
	for peer: Dictionary in (_game.network_session.get_snapshot().get("lifecycle", {}) as Dictionary).get("peers", []):
		if int(peer.get("peer_id", 0)) == peer_id:
			return int(peer.get("peer_generation", 0))
	return 0

func _ordinary_walk_to(target: Vector3, cabin: bool) -> bool:
	var moving_target := _craft.to_local(target) if _ordinary_two_client_moving and cabin else Vector3.ZERO
	await _ordinary_look(target + Vector3.UP * 1.4)
	var deadline := Time.get_ticks_msec() + 15000
	var settled := 0
	while Time.get_ticks_msec() < deadline and not _ordinary_aborted():
		if _ordinary_two_client_moving and cabin:
			target = _craft.to_global(moving_target)
		var delta := (target - _player.global_position).slide(Vector3.UP)
		var authoritative_delta := delta
		var current := true
		if cabin:
			var source := _game.get_network_remote_body_intent_source()
			current = source != null and source.is_bound() and source.get_entity_id() == StringName(_ordinary_walking_identity.entity_id) \
				and source.get_entity_generation() == int(_ordinary_walking_identity.entity_generation)
			if current:
				var latest := _game.network_session.get_moving_interior_latest_relationship(source.get_entity_id())
				current = int(latest.get("entity_generation", 0)) == source.get_entity_generation() \
					and latest.get("parent_frame_id") == StringName("frame_%s" % _craft.get_ship_id())
				var pose := latest.get("frame_local_transform", Transform3D.IDENTITY) as Transform3D
				authoritative_delta = (target - _craft.to_global(pose.origin)).slide(Vector3.UP)
		if delta.length() <= 0.30 and current and authoritative_delta.length() <= 0.30:
			_ordinary_release_walk()
			await _ticks(1)
			settled = settled + 1 if _player.is_on_floor() and _player.velocity.slide(Vector3.UP).length() < 0.1 else 0
			if settled >= 15:
				print("HALYARD_ORDINARY_WAYPOINT: role=", _role, " target=", target, " actual=", _player.global_position)
				return _ordinary_require(absf(target.y - _player.global_position.y) < 0.8 and _ordinary_same_identity()
					and _player.get_instance_id() == _ordinary_player_id, "ordinary supported continuous walk reaches goal: " + str(target))
			continue
		settled = 0
		if cabin and current:
			delta = (delta + authoritative_delta) * 0.5
		var forward := (-_player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var axis := Vector2(delta.normalized().dot(right), -delta.normalized().dot(forward))
		axis *= clampf(delta.length() / 1.5, 0.35, 1.0)
		for action in ORDINARY_WALK_ACTIONS:
			_ordinary_action(action, false)
		_ordinary_action(&"move_left" if axis.x < 0.0 else &"move_right", true, absf(axis.x))
		_ordinary_action(&"move_forward" if axis.y < 0.0 else &"move_back", true, absf(axis.y))
		await _ticks(1)
	_ordinary_release_walk()
	print("HALYARD_ORDINARY_WALK_STOP: role=", _role, " target=", target, " actual=", _player.global_position,
		" floor=", _player.is_on_floor(), " velocity=", _player.velocity, " phase=", _game.phase)
	return _ordinary_require(false, "ordinary walk reaches supported goal within existing bounded route: " + str(target))

func _ordinary_release_walk() -> void:
	for action in ORDINARY_WALK_ACTIONS:
		_ordinary_action(action, false)

func _ordinary_look(target: Vector3) -> void:
	var local_target := _craft.to_local(target) if _ordinary_two_client_moving else Vector3.ZERO
	for _index in 4:
		if _ordinary_two_client_moving:
			target = _craft.to_global(local_target)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			Input.parse_input_event(click)
			await _ticks(1)
			click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = false
			Input.parse_input_event(click)
		var desired := _player.global_basis.inverse() * (target - _player.get_interaction_origin()).normalized()
		var current := _player.global_basis.inverse() * _player.get_interaction_direction().normalized()
		var yaw := wrapf(atan2(-desired.x, -desired.z) - atan2(-current.x, -current.z), -PI, PI)
		var pitch := asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-yaw, pitch * (1.0 if _player.invert_mouse_y else -1.0)) / _player.mouse_sensitivity
		Input.parse_input_event(event)
		await _ticks(1)

func _ordinary_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)

func _ordinary_press(action: StringName) -> void:
	_ordinary_action(action, true)
	await _ticks(2)
	_ordinary_action(action, false)
	await _ticks(3)


## Reused real-HUD focus/ui_accept pattern from the live browser integration.

func _ordinary_button(node_name: String) -> bool:
	if not await _ordinary_boundary(func():
		var button := _game.hud.find_child(node_name, true, false) as Button
		return button != null and button.is_visible_in_tree() and not button.disabled,
		5.0, "visible enabled HUD action: " + node_name):
		return false
	return await _ordinary_activate(_game.hud.find_child(node_name, true, false) as Button)

func _ordinary_activate(button: Button) -> bool:
	var button_name := str(button.name)
	root.grab_focus()
	button.grab_focus()
	await process_frame
	if not _ordinary_require(root.gui_get_focus_owner() == button, "actual HUD button receives keyboard/controller focus"):
		return false
	var activated := [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	_ordinary_action(&"ui_accept", true)
	await process_frame
	_ordinary_action(&"ui_accept", false)
	await process_frame
	return await _ordinary_boundary(func(): return activated[0], 5.0, "focused ui_accept activates real HUD Button: " + button_name)


func _ordinary_run(args: PackedStringArray) -> void:
	if args.size() < 3:
		await _orchestrate()
		return
	_role = args[0]
	_directory = args[1]
	_port = int(args[2])
	_profile_deadline = Time.get_ticks_msec() + 300000
	_write(_role + ".script_ready", {"pid": OS.get_process_id(), "display": OS.get_environment("DISPLAY"),
		"data": OS.get_environment("XDG_DATA_HOME"), "config": OS.get_environment("XDG_CONFIG_HOME"),
		"cache": OS.get_environment("XDG_CACHE_HOME"), "runtime": OS.get_environment("XDG_RUNTIME_DIR"),
		"state": OS.get_environment("XDG_STATE_HOME"), "tmp": OS.get_environment("TMPDIR"),
		"wayland_display": OS.get_environment("WAYLAND_DISPLAY")})
	_game = Main.instantiate() as GameFlow
	_store_path = "user://halyard-ordinary-boarding-peer.json"
	var store := UserDataStore.new(_store_path)
	store.load()
	_game.configure_runtime_settings_persistence(store)
	root.add_child(_game)
	await _ticks(4)
	_craft = _game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	_player = _game.get_node("Player") as PlayerController
	_ordinary_player_id = _player.get_instance_id()
	_write(_role + ".main_ready", {"pid": OS.get_process_id(), "player_id": str(_ordinary_player_id)})
	if _ordinary_require(_game.hud is GameHUD and _game.phase == GameFlow.Phase.INTRO,
		"fresh Main starts with real HUD and original Player at Intro"):
		if _role == "host":
			await _ordinary_host()
		else:
			await _ordinary_client()
	# A coroutine that errors/returns before its final handshake cannot qualify.
	_ordinary_require(_ordinary_complete, "selected ordinary boarding reaches explicit terminal handshake")
	if not _failures.is_empty():
		# Let each retained actor capture the first failure before disconnect can
		# retire the authoritative bodies. This is inside owned exit grace.
		var capture_deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < capture_deadline:
			if FileAccess.file_exists(_directory.path_join("host.first_failure")) \
				and FileAccess.file_exists(_directory.path_join("client.first_failure")) \
				and FileAccess.file_exists(_directory.path_join("client_b.first_failure")):
				break
			await _ticks(1)
	for action in ORDINARY_WALK_ACTIONS + [&"interact", &"sprint_boost", &"brake", &"ui_accept", &"fire"]:
		_ordinary_action(action, false)
		Input.action_release(action)
	if _ordinary_two_client_authority_stop or _ordinary_two_client_pilot_loss or _ordinary_two_client_passenger_loss:
		_ordinary_action(&"pause", false)
		Input.action_release(&"pause")
		# A failed new UI boundary must not leave this owned actor paused.
		paused = false
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	# In authority-stop the host already stopped once and each client already
	# received its actual transport event. Teardown cannot become another stop
	# or a client-initiated leave. Failed pre-stop routes still close normally.
	if not (_ordinary_two_client_authority_stop or _ordinary_two_client_pilot_loss or _ordinary_two_client_passenger_loss) or (is_instance_valid(_game.network_session) \
		and _game.network_session.is_session_active()):
		_game.shutdown_network_session(&"halyard_ordinary_boarding_done")
	_game.release_mouse_capture()
	_game.queue_free()
	await _ticks(3)
	DirAccess.remove_absolute(_store_path)
	_write(_role + ".done", {"checks": _checks, "failures": _failures,
		"complete": _ordinary_complete, "pid": OS.get_process_id()})
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() and _ordinary_complete else 1)


func _ordinary_host() -> void:
	if not _ordinary_require(_game.host_network_session(_port).accepted,
		"non-playing Main authority starts existing ENet session"):
		return
	if not _ordinary_require(_game.phase == GameFlow.Phase.INTRO and not _player.is_seated()
		and not _player.is_control_enabled(), "authority remains non-playing at Intro"):
		return
	_write("host.ready", {"pid": OS.get_process_id(), "ship_id": str(_craft.get_ship_id())})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".main_ready", 60.0) or not await _wait_file(role + ".admitted", 20.0):
			return
	var first := _read("client.admitted")
	var second := _read("client_b.admitted")
	var pilot_peer := int(first.get("peer_id", 0))
	var passenger_peer := int(second.get("peer_id", 0))
	if not _ordinary_require(pilot_peer > 1 and passenger_peer > 1 and pilot_peer != passenger_peer
		and int(first.pid) != int(second.pid) and int(first.pid) != OS.get_process_id()
		and int(second.pid) != OS.get_process_id()
		and _ordinary_peer_generation(pilot_peer) == int(first.peer_generation)
		and _ordinary_peer_generation(passenger_peer) == int(second.peer_generation)
		and _game.network_session.get_admitted_peer_ids().size() == 2,
		"authority authenticates two distinct original independent clients and peer generations"):
		return
	for role in ["client", "client_b"]:
		var peer := pilot_peer if role == "client" else passenger_peer
		if not await _wait_file(role + ".cabin", 120.0):
			return
		if not _ordinary_observe_supported_cabin(role, peer):
			return
		_write("host." + role + "_body", {})
		if not await _wait_file(role + ".seated", 30.0):
			return
		if role == "client":
			if not await _ordinary_boundary(func(): return _ordinary_pilot_is_current(pilot_peer), 8.0,
				"authority confirms original pilot's real seat, body generation and ownership"):
				return
			_write("host.pilot_seated", {})
	if not await _ordinary_boundary(func():
		return _ordinary_pilot_is_current(pilot_peer) and _ordinary_passenger_is_current(passenger_peer),
		8.0, "authority retains distinct real pilot and crew_port_00 passenger seats together"):
		return
	var manifest := _ordinary_manifest(pilot_peer, passenger_peer)
	if not _ordinary_require(_ordinary_manifest_current(manifest),
		"authority retains exact original peer/body/frame/seat and ownership generations without flight"):
		return
	_write("host.seats_confirmed", manifest)
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".retained", 12.0):
			return
	if not _ordinary_require(_ordinary_manifest_current(manifest),
		"both consumed client confirmations preserve authoritative distinct seats and stationary craft"):
		return
	if _ordinary_two_client_moving and not await _ordinary_moving_host(manifest):
		return
	if _ordinary_two_client_authority_stop and not await _ordinary_authority_stop_host(manifest):
		return
	if _ordinary_two_client_pilot_loss and not await _ordinary_pilot_loss_host(manifest):
		return
	if _ordinary_two_client_passenger_loss and not await _ordinary_passenger_loss_host(manifest):
		return
	_write("host.release", {})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".leaving", 12.0):
			return
	_write("host.leaving", {})
	_ordinary_complete = true


func _ordinary_client() -> void:
	if not await _ordinary_button("IntroServerBrowserButton"):
		return
	(_game.hud.get("_server_browser_address") as LineEdit).text = "127.0.0.1"
	(_game.hud.get("_server_browser_port") as LineEdit).text = str(_port)
	(_game.hud.get("_server_browser_player_name") as LineEdit).text = "Halyard " + _role
	if not await _ordinary_button("ServerBrowserManualJoinButton") or not await _ordinary_boundary(
		_ordinary_authenticated, 20.0, "real HUD Manual Join authenticates original independent client"):
		return
	_ordinary_peer_id = _game.network_session.multiplayer.get_unique_id()
	var admitted := (_game.network_session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	_ordinary_initial_peer_generation = int(admitted.get("peer_generation", 0))
	_write(_role + ".admitted", {"pid": OS.get_process_id(), "peer_id": _ordinary_peer_id,
		"peer_generation": _ordinary_initial_peer_generation, "player_id": str(_ordinary_player_id)})
	if not await _ordinary_button("ServerBrowserBackButton") or not await _ordinary_button("IntroBeginShiftButton"):
		return
	if not await _ordinary_boundary(func():
		return _game.phase == GameFlow.Phase.APPROACH_SHIP and _player.is_control_enabled() and _player.is_on_floor(),
		5.0, "ordinary Begin Shift starts supported authored station spawn"):
		return
	var dismiss := _game.hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		if not await _ordinary_activate(dismiss):
			return
	var spawn: Transform3D = _game.world.get_player_spawn()
	if not _ordinary_require(_player.global_position.distance_to(spawn.origin) < 0.8
		and _player.get_instance_id() == _ordinary_player_id, "same actual Player begins at normal authored spawn"):
		return
	for target: Vector3 in ORDINARY_HALYARD_APPROACH:
		if not await _ordinary_walk_to(target, false):
			return
	if not await _ordinary_walk_to(_craft.get_boarding_position(), false):
		return
	if _role == "client_b" and not await _wait_file("host.pilot_seated", 120.0):
		return
	await _ordinary_look(_craft.get_boarding_position() + Vector3.UP * 1.2)
	var area := _craft.get_node("ShipBoardingArea") as ShipBoardingArea
	if not await _ordinary_boundary(func():
		return _game.boarding_candidate == _craft and bool(_game.get("_near_ship")) \
			and _player.get_nearby_interactables().has(area),
		5.0, "ordinary exterior approach discovers actual Halyard boarding candidate and ShipBoardingArea"):
		return
	await _ordinary_press(&"interact")
	if not await _ordinary_boundary(_ordinary_supported_cabin, 12.0,
		"ordinary exterior Interact admits same supported Player with bound authenticated body intent"):
		return
	var source := _game.get_network_remote_body_intent_source()
	_ordinary_walking_identity = {"peer_id": _ordinary_peer_id, "entity_id": str(source.get_entity_id()),
		"entity_generation": source.get_entity_generation(), "player_id": str(_ordinary_player_id)}
	_write(_role + ".cabin", _ordinary_walking_identity)
	if not await _wait_file("host." + _role + "_body", 8.0):
		return
	if _role == "client":
		await _client_loadmaster_pilot()
		if not _failures.is_empty() or not _ordinary_local_pilot_is_current():
			return
	else:
		if not await _ordinary_walk_to((_station_contract().entry_transform as Transform3D).origin, true):
			return
		await _ordinary_look(_station_anchor().global_position + Vector3.UP * 1.2)
		if not await _ordinary_boundary(func():
			return _game.station_interaction_candidate is ShipCrewSeat \
				and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor() == _station_anchor(),
			5.0, "ordinary cabin approach discovers authored crew_port_00 passenger chair"):
			return
		await _ordinary_press(&"interact")
		if not await _ordinary_boundary(_ordinary_local_passenger_is_current, 8.0,
			"ordinary chair Interact physically seats same Player with consumed passenger role and controls"):
			return
	_write(_role + ".seated", _ordinary_walking_identity)
	if not await _wait_file("host.seats_confirmed", 60.0):
		return
	var manifest := _read("host.seats_confirmed")
	if not await _ordinary_boundary(func(): return _ordinary_consumed_manifest_current(manifest), 8.0,
		"consumed client body/frame/seat/ownership generations match host and honest role UI"):
		return
	_write(_role + ".retained", {})
	if _ordinary_two_client_moving and not await _ordinary_moving_client(manifest):
		return
	if _ordinary_two_client_authority_stop and not await _ordinary_authority_stop_client():
		return
	if _ordinary_two_client_pilot_loss and not await _ordinary_pilot_loss_client():
		return
	if _ordinary_two_client_passenger_loss and not await _ordinary_passenger_loss_client():
		return
	if not await _wait_file("host.release", 12.0):
		return
	_write(_role + ".leaving", {})
	if not await _wait_file("host.leaving", 12.0):
		return
	_ordinary_complete = true


# This continuation starts only after every original stationary BOARD check.
# Host barriers sample actual authoritative movement during each physical action;
# clients independently prove consumed current state before the next action.
const ORDINARY_MOVING_STAGES := ["stand", "walk", "approach", "sit", "stand_again", "approach_again", "reseat"]

func _ordinary_hull_sample() -> Dictionary:
	var position := _craft.global_position
	return {"position": [position.x, position.y, position.z], "speed": _craft.velocity.length(),
		"tick": Engine.get_physics_frames(), "min_sampled_speed": _ordinary_motion_min_speed,
		"motion_samples": _ordinary_motion_samples}

func _ordinary_motion_begin() -> Dictionary:
	_ordinary_motion_min_speed = _craft.velocity.length()
	_ordinary_motion_samples = 0
	_ordinary_motion_active = true
	return _ordinary_hull_sample()

func _ordinary_motion_end() -> Dictionary:
	var sample := _ordinary_hull_sample()
	_ordinary_motion_active = false
	return sample

func _ordinary_hull_moved(before: Dictionary, after: Dictionary) -> bool:
	var a: Array = before.get("position", [])
	var b: Array = after.get("position", [])
	if a.size() != 3 or b.size() != 3:
		return false
	return Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(
		Vector3(float(b[0]), float(b[1]), float(b[2]))) > 0.01 \
		and float(before.get("speed", 0.0)) > 0.1 and float(after.get("speed", 0.0)) > 0.1 \
		and int(after.get("tick", 0)) > int(before.get("tick", 0)) \
		and int(after.get("motion_samples", 0)) >= 2 and float(after.get("min_sampled_speed", 0.0)) > 0.1

func _ordinary_moving_walker_current(peer: int) -> bool:
	var avatar := GameFlow.network_client_boarding_avatar_id(peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(avatar) as PlayerController
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	var publication := _ordinary_publication(avatar)
	return body != null and owner != null and not body.is_seated() and body.is_on_floor() \
		and body.get_cabin_containment_report().get("frame") == _craft \
		and owner.get_assignment(peer, avatar).is_empty() \
		and publication.get("occupant") == body and int(publication.get("owner_peer_id", 0)) == peer \
		and int(publication.get("published_state", -1)) == NetworkMovingInteriorRelationship.STATE_WALKING

func _ordinary_moving_host_current(baseline: Dictionary, seated: bool, body: PlayerController, helm: NetworkRemotePilotCommandSource) -> bool:
	var pilot := int(baseline.pilot_peer)
	var passenger := int(baseline.passenger_peer)
	var current := _ordinary_manifest(pilot, passenger)
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if owner == null or _game.get_network_remote_body_simulation().get_body(
		GameFlow.network_client_boarding_avatar_id(passenger)) != body \
		or _craft.get_command_source() != helm or not helm.is_holding_command() \
		or int(helm.get_audit().get("pilot_peer_id", 0)) != pilot \
		or float((helm.get_audit().get("controls", {}) as Dictionary).get("throttle", 0.0)) <= 0.0 \
		or _craft.get_last_ship_command().throttle <= 0.0 \
		or _craft.velocity.length() <= 0.1 or _craft.get_telemetry().get("engine_state") != HeroShip.ENGINE_ONLINE:
		return false
	for key in ["pilot_peer", "passenger_peer", "pilot_peer_generation", "passenger_peer_generation",
		"ship_id", "ownership", "pilot_seat", "passenger_boarding"]:
		if current.get(key) != baseline.get(key):
			return false
	var identity_keys := ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"]
	for key in ["pilot_body", "passenger_body"]:
		if _ordinary_fields(current.get(key, {}) as Dictionary, identity_keys) != \
			_ordinary_fields(baseline.get(key, {}) as Dictionary, identity_keys):
			return false
	var assignments: Array = owner.get_snapshot().get("assignments", [])
	var occupancy_count := 0
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if held.get("ship_id") == _craft.get_ship_id():
			occupancy_count += 1
	return occupancy_count == 2 and assignments.size() == (1 if seated else 0) \
		and _ordinary_pilot_is_current(pilot) \
		and (_ordinary_passenger_is_current(passenger) if seated else _ordinary_moving_walker_current(passenger)) \
		and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled()

func _ordinary_moving_host(baseline: Dictionary) -> bool:
	var start := _craft.global_position
	var passenger := int(baseline.passenger_peer)
	var body := _game.get_network_remote_body_simulation().get_body(
		GameFlow.network_client_boarding_avatar_id(passenger)) as PlayerController
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	if not _ordinary_require(body != null and helm != null, "moving continuation retains original authoritative passenger body and remote pilot helm"):
		return false
	_write("host.moving_go", {})
	if not await _ordinary_boundary(func(): return _craft.global_position.distance_to(start) > 5.0 \
		and _ordinary_moving_host_current(baseline, true, body, helm), 8.0,
		"same original sampled remote helm physically departs over five metres with retained seats and current ownership"):
		return false
	_write("host.departed", {"distance": _craft.global_position.distance_to(start), "sample": _ordinary_hull_sample()})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".departure_retained", 8.0):
			return false
	var previous_claim := int((baseline.passenger_seat as Dictionary).claim_sequence)
	for stage: String in ORDINARY_MOVING_STAGES:
		var seated := stage in ["sit", "reseat"]
		var before := _ordinary_motion_begin()
		var body_before := _craft.to_local(body.global_position)
		var delivered := int(helm.get_audit().get("delivered", 0))
		_write("host.moving_" + stage + "_go", {"sample": before})
		if not await _wait_file("client_b.moving_" + stage + "_done", 15.0 if stage in ["walk", "approach", "approach_again"] else 8.0):
			return false
		if not await _ordinary_boundary(func(): return _ordinary_moving_host_current(baseline, seated, body, helm),
			8.0, "moving host retains exact original actors, helm, frames and supported current role after " + stage):
			return false
		var after := _ordinary_motion_end()
		var receipt := _read("client_b.moving_" + stage + "_done")
		if not _ordinary_require(_ordinary_hull_moved(before, after) \
			and _ordinary_hull_moved(receipt.get("before", {}) as Dictionary, receipt.get("after", {}) as Dictionary) \
			and int(helm.get_audit().get("delivered", 0)) > delivered,
			"host and consumed passenger hull samples prove real movement during " + stage + " with fresh sampled helm commands"):
			return false
		if stage == "walk" and not _ordinary_require(_craft.to_local(body.global_position).distance_to(body_before) > 0.6 \
			and float(receipt.get("walk_distance", 0.0)) > 0.6,
			"same authoritative and predicted passenger both walk over point six metres within the moving hull"):
			return false
		var manifest := _ordinary_manifest(int(baseline.pilot_peer), passenger)
		if seated:
			var claim := int((manifest.passenger_seat as Dictionary).get("claim_sequence", 0))
			if not _ordinary_require(claim > previous_claim, "ordinary moving " + stage + " earns a fresh authoritative chair claim"):
				return false
			previous_claim = claim
		_write("host.moving_" + stage + "_checked", manifest)
		for role in ["client", "client_b"]:
			if not await _wait_file(role + ".moving_" + stage + "_retained", 8.0):
				return false
	_write("host.moving_complete", {})
	return await _wait_file("client.moving_complete", 8.0) and await _wait_file("client_b.moving_complete", 8.0)

# Passenger physics retains its offline local simulation. Accepted host engine
# facts are exposed by the production observer presentation getter, with no
# fallback to local telemetry when that accepted presentation is absent.
func _ordinary_moving_engine_online() -> bool:
	if _role == "client_b":
		return _craft.get_network_operation_telemetry_presentation().get("engine_state") == HeroShip.ENGINE_ONLINE
	return _craft.get_telemetry().get("engine_state") == HeroShip.ENGINE_ONLINE

func _ordinary_moving_consumed_current(manifest: Dictionary, seated: bool) -> bool:
	if _craft.velocity.length() <= 0.1 or not _ordinary_moving_engine_online():
		return false
	if seated:
		return _ordinary_consumed_manifest_current(manifest)
	# Preserve the accepted exact ownership, boarding, peer and frame projections.
	# Only the passenger's current role/state differs during a legitimate stand.
	if not _ordinary_same_identity() or not _ordinary_walking_identity_is_preserved():
		return false
	if _role == "client" and not _ordinary_local_pilot_is_current():
		return false
	if _role == "client_b":
		var view := _game.network_session.get_passenger_replica_snapshot()
		if not _ordinary_supported_cabin() or _player.is_seated() or not _ordinary_hud_role_is_current(&"passenger") \
			or _craft.get_crew_role_authority() != null or _game.get("_network_engineer_source") != null \
			or not (view.get("assignment", {}) as Dictionary).is_empty() or bool(view.get("seated", false)):
			return false
		var source := _game.get_network_remote_body_intent_source()
		if source.get_entity_id() != StringName(_ordinary_walking_identity.entity_id) \
			or source.get_entity_generation() != int(_ordinary_walking_identity.entity_generation):
			return false
		for producer in [_craft.get("_default_local_command_source"), _craft.get("_command_source")]:
			if producer is ShipCommandSource and producer.is_enabled_owner():
				return false
	var ownership: Dictionary = {}
	for row: Dictionary in (_game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary).get("ownership", []):
		if row.get("ship_id") == _craft.get_ship_id():
			ownership = row
	if _ordinary_fields(ownership, ["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"]) != manifest.ownership \
		or int(ownership.get("owner_peer_generation", 0)) != int(manifest.pilot_peer_generation):
		return false
	var expected_boarding: Dictionary = manifest.pilot_seat if _role == "client" else manifest.passenger_boarding
	if _ordinary_fields(_game.get("_network_client_boarding_claim") as Dictionary, ["ship_id", "seat_id", "role"]) != \
		_ordinary_fields(expected_boarding, ["ship_id", "seat_id", "role"]):
		return false
	for kind in ["pilot_body", "passenger_body"]:
		var expected: Dictionary = manifest.get(kind, {})
		var latest := _game.network_session.get_moving_interior_latest_relationship(StringName(expected.entity_id))
		var keys := ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"]
		if not (_role == "client" and kind == "pilot_body"):
			keys.append("occupancy_state")
		if _ordinary_fields(latest, keys) != _ordinary_fields(expected, keys):
			return false
	return true

func _ordinary_moving_client(baseline: Dictionary) -> bool:
	if not await _wait_file("host.moving_go", 8.0):
		return false
	if _role == "client":
		# Production LocalShipInputSource samples this ordinary throttle; no
		# command, engine, transform or velocity is set by this fixture.
		_ordinary_action(&"move_forward", true, 0.35)
	if not await _wait_file("host.departed", 8.0):
		return false
	if not await _ordinary_boundary(func(): return _craft.velocity.length() > 0.1 \
		and _ordinary_moving_engine_online() \
		and _ordinary_consumed_manifest_current(baseline), 8.0,
		"original peer consumes genuinely departing craft with unchanged seated identities"):
		return false
	_write(_role + ".departure_retained", {})
	for stage: String in ORDINARY_MOVING_STAGES:
		if _role == "client_b":
			if not await _wait_file("host.moving_" + stage + "_go", 8.0):
				return false
			var before := _ordinary_motion_begin()
			var local_before := _craft.to_local(_player.global_position)
			if stage == "walk":
				if not await _ordinary_walk_to(_craft.to_global(Vector3(0.0, 0.52, -6.80)), true):
					return false
			elif stage in ["approach", "approach_again"]:
				if not await _ordinary_walk_to((_station_contract().entry_transform as Transform3D).origin, true):
					return false
			elif stage in ["stand", "stand_again"]:
				await _ordinary_press(&"interact")
				if not await _ordinary_boundary(func(): return _ordinary_supported_cabin() and not _player.is_seated(),
					8.0, "ordinary Interact restores supported moving passenger stand: " + stage):
					return false
			else:
				await _ordinary_look(_station_anchor().global_position + Vector3.UP * 1.2)
				if not await _ordinary_boundary(func(): return _game.station_interaction_candidate is ShipCrewSeat \
					and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor() == _station_anchor(),
					8.0, "ordinary moving approach discovers same real crew_port_00 chair"):
					return false
				await _ordinary_press(&"interact")
				if not await _ordinary_boundary(_ordinary_local_passenger_is_current, 8.0,
					"ordinary moving chair Interact seats original passenger: " + stage):
					return false
			var after := _ordinary_motion_end()
			if not _ordinary_require(_ordinary_hull_moved(before, after), "consumed hull genuinely moves throughout passenger " + stage):
				return false
			_write("client_b.moving_" + stage + "_done", {"before": before, "after": after,
				"walk_distance": _craft.to_local(_player.global_position).distance_to(local_before)})
		if not await _wait_file("host.moving_" + stage + "_checked", 30.0):
			return false
		var manifest := _read("host.moving_" + stage + "_checked")
		if not await _ordinary_boundary(func(): return _ordinary_moving_consumed_current(manifest, stage in ["sit", "reseat"]),
			8.0, "both peers consume current host body/frame/ownership and legitimate role after moving " + stage):
			return false
		_write(_role + ".moving_" + stage + "_retained", {})
	if not await _wait_file("host.moving_complete", 8.0):
		return false
	if _role == "client":
		_ordinary_action(&"move_forward", false)
	_write(_role + ".moving_complete", {})
	return true


# Pilot loss starts after the full moving/reseat handshake. Only the original
# pilot closes its real transport; the authority and passenger keep their session.
func _ordinary_pilot_loss_arm(departing_peer: int) -> void:
	_ordinary_authority_adapter = _game.network_session
	_ordinary_pilot_loss_events = {"transport_peer_disconnected": 0, "adapter_peer_disconnected": 0,
		"server_disconnected": 0, "session_stopped": 0, "reason": ""}
	_ordinary_authority_adapter.multiplayer.peer_disconnected.connect(func(peer: int):
		if peer == departing_peer:
			_ordinary_pilot_loss_events.transport_peer_disconnected += 1)
	_ordinary_authority_adapter.peer_disconnected.connect(func(peer: int, receipt: Dictionary):
		if peer == departing_peer:
			_ordinary_pilot_loss_events.adapter_peer_disconnected += 1
			_ordinary_pilot_loss_events.receipt = receipt.duplicate(true))
	_ordinary_authority_adapter.multiplayer.server_disconnected.connect(func():
		_ordinary_pilot_loss_events.server_disconnected += 1)
	_ordinary_authority_adapter.session_stopped.connect(func(reason: StringName):
		_ordinary_pilot_loss_events.session_stopped += 1
		_ordinary_pilot_loss_events.reason = str(reason))


func _ordinary_pilot_loss_host_current(baseline: Dictionary, seated: bool) -> bool:
	var pilot := int(baseline.pilot_peer)
	var passenger := int(baseline.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(pilot)
	var passenger_avatar := GameFlow.network_client_boarding_avatar_id(passenger)
	var simulation := _game.get_network_remote_body_simulation()
	var body := _ordinary_pilot_loss_retained.body as PlayerController
	var owner := _ordinary_pilot_loss_retained.owner as CrewSeatRoleAuthority
	var old_helm: WeakRef = _ordinary_pilot_loss_retained.helm as WeakRef
	if not is_instance_valid(body) or owner == null or old_helm == null:
		return false
	var admitted := _ordinary_authority_adapter.get_admitted_peer_ids()
	var current := _ordinary_manifest(pilot, passenger)
	var commands := _ordinary_authority_adapter.get_remote_ship_command_snapshot()
	var ownership := _ordinary_authority_adapter.get_owned_ship(_craft.get_ship_id())
	return (_game.network_session == _ordinary_authority_adapter and _ordinary_authority_adapter.is_server()
		and _ordinary_authority_adapter.is_session_active() and admitted.size() == 1 and admitted.has(passenger)
		and _ordinary_peer_generation(passenger) == int(baseline.passenger_peer_generation)
		and int(_ordinary_pilot_loss_events.transport_peer_disconnected) == 1
		and int(_ordinary_pilot_loss_events.adapter_peer_disconnected) == 1
		and int(_ordinary_pilot_loss_events.session_stopped) == 0
		and old_helm.get_ref() == null and not _craft.is_remote_piloted() and not _craft.is_piloted()
		and _craft.get_command_source() == _ordinary_pilot_loss_retained.source
		and not (_game.get("_network_remote_pilots") as Dictionary).has(_craft.get_ship_id())
		and int(commands.get("pilot_count", -1)) == 0 and (commands.get("pilots", []) as Array).is_empty()
		and int(ownership.get("owner_peer_id", -1)) == 0
		and ownership.get("ship_generation") == (baseline.ownership as Dictionary).get("ship_generation")
		and int(ownership.get("ownership_generation", 0)) > int((baseline.ownership as Dictionary).ownership_generation)
		and simulation.get_body(avatar) == null and simulation.get_body_record(avatar).is_empty()
		and _ordinary_publication(avatar).is_empty() and (current.pilot_seat as Dictionary).is_empty()
		and owner.get_assignment(pilot, avatar).is_empty()
		and simulation.get_body(passenger_avatar) == body and _craft.get_crew_role_authority() == owner
		and body.get_cabin_containment_report().get("frame") == _craft
		and current.passenger_boarding == baseline.passenger_boarding
		and _ordinary_fields(current.passenger_body, ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"])
			== _ordinary_fields(baseline.passenger_body, ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"])
		and (_ordinary_passenger_is_current(passenger) if seated else _ordinary_moving_walker_current(passenger))
		and _player.get_instance_id() == _ordinary_player_id and _game.phase == GameFlow.Phase.INTRO
		and not _player.is_seated() and not _player.is_control_enabled())


func _ordinary_pilot_loss_host(baseline: Dictionary) -> bool:
	var final_manifest := _read("host.moving_reseat_checked")
	var pilot := int(baseline.pilot_peer)
	var passenger := int(baseline.passenger_peer)
	var simulation := _game.get_network_remote_body_simulation()
	var body := simulation.get_body(GameFlow.network_client_boarding_avatar_id(passenger)) as PlayerController
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if not _ordinary_require(body != null and helm != null and owner != null,
		"pilot-loss retains the original authoritative passenger body, crew owner and current remote helm"):
		return false
	var old_helm: WeakRef = weakref(helm)
	_ordinary_pilot_loss_retained = {"body": body, "owner": owner, "helm": old_helm,
		"source": _craft.get_local_input_source()}
	_ordinary_pilot_loss_arm(pilot)
	_write("host.pilot_loss_ready", {})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".pilot_loss_ready", 8.0):
			return false
	if not _ordinary_require(_ordinary_pilot_is_current(pilot) and _ordinary_passenger_is_current(passenger)
		and simulation.get_body(GameFlow.network_client_boarding_avatar_id(passenger)) == body
		and _craft.get_command_source() == helm and _craft.get_crew_role_authority() == owner
		and _ordinary_manifest(pilot, passenger).passenger_seat == final_manifest.passenger_seat,
		"all three actors arm real transport signals after full moving completion while both original occupants remain aboard"):
		return false
	_write("host.pilot_loss_go", {})
	if not await _ordinary_boundary(func(): return _ordinary_pilot_loss_host_current(final_manifest, true), 8.0,
		"actual pilot transport loss retires only its helm, claims, publication and command queue while preserving server and original passenger"):
		return false
	var released := _ordinary_manifest(pilot, passenger)
	if not _ordinary_require(released.passenger_seat == final_manifest.passenger_seat,
		"pilot departure preserves the passenger's exact original chair claim before further input"):
		return false
	released["pose_tick"] = int(_game.get("_network_boarding_server_tick"))
	_write("host.pilot_loss_released", released)
	if not await _wait_file("client_b.pilot_loss_consumed", 8.0):
		return false
	var old_claim := int((released.passenger_seat as Dictionary).claim_sequence)
	for stage: String in ["stand", "reseat"]:
		var seated := stage == "reseat"
		_write("host.pilot_loss_" + stage + "_go", {})
		if not await _wait_file("client_b.pilot_loss_" + stage + "_done", 8.0):
			return false
		if not await _ordinary_boundary(func(): return _ordinary_pilot_loss_host_current(final_manifest, seated), 8.0,
			"surviving server retains the same supported passenger body and retired pilot after ordinary " + stage):
			return false
		var current := _ordinary_manifest(pilot, passenger)
		if seated and not _ordinary_require(int((current.passenger_seat as Dictionary).claim_sequence) > old_claim
			and (current.passenger_seat as Dictionary).seat_generation == (released.passenger_seat as Dictionary).seat_generation,
			"surviving passenger's ordinary reseat earns a fresh claim on the same authored chair generation"):
			return false
		current["pose_tick"] = int(_game.get("_network_boarding_server_tick"))
		_write("host.pilot_loss_" + stage + "_checked", current)
		if not await _wait_file("client_b.pilot_loss_" + stage + "_retained", 8.0):
			return false
	if not await _wait_file("client.pilot_loss_recovered", 30.0):
		return false
	if not _ordinary_require(_ordinary_pilot_loss_host_current(final_manifest, true),
		"departing pilot's usable local controls cannot revive the retired host helm or disconnect the surviving passenger"):
		return false
	_write("host.pilot_loss_complete", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	return await _wait_file("client.pilot_loss_complete", 8.0) and await _wait_file("client_b.pilot_loss_complete", 8.0)


func _ordinary_pilot_loss_passenger_current(manifest: Dictionary, seated: bool) -> bool:
	var session := _game.network_session
	var pilot_avatar := GameFlow.network_client_boarding_avatar_id(int(manifest.pilot_peer))
	var source := _game.get_network_remote_body_intent_source()
	var presenter := _game.get_network_moving_interior_presenter()
	if not is_instance_valid(source) or not is_instance_valid(presenter):
		return false
	var default_source := _craft.get("_default_local_command_source") as ShipCommandSource
	var active_source := _craft.get("_command_source") as ShipCommandSource
	var pose: Dictionary = _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id())
	var ownership: Dictionary = {}
	for row: Dictionary in (session.get_authoritative_snapshot().get("sections", {}) as Dictionary).get("ownership", []):
		if row.get("ship_id") == _craft.get_ship_id():
			ownership = row
	var latest := session.get_moving_interior_latest_relationship(StringName(_ordinary_walking_identity.entity_id))
	var view := session.get_passenger_replica_snapshot()
	var assignment := view.get("assignment", {}) as Dictionary
	# Coasting pose headers retain handoff attribution. Current ownership and a
	# fresh same-hull pose establish the surviving consumer's actual state.
	return (session == _ordinary_authority_adapter and _ordinary_same_identity() and _ordinary_walking_identity_is_preserved()
		and int(_ordinary_pilot_loss_events.session_stopped) == 0 and int(_ordinary_pilot_loss_events.server_disconnected) == 0
		and source == _ordinary_pilot_loss_retained.body_source and source.is_bound()
		and source.get_entity_id() == StringName(_ordinary_walking_identity.entity_id)
		and source.get_entity_generation() == int(_ordinary_walking_identity.entity_generation)
		and (default_source == null or not default_source.is_enabled_owner())
		and (active_source == null or not active_source.is_enabled_owner()) and not _game.get("_piloting")
		and (_craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame) == _ordinary_pilot_loss_retained.frame
		and _ordinary_fields(ownership, ["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"]) == manifest.ownership
		and int(ownership.get("owner_peer_id", -1)) == 0
		and str(pose.get("ship_id", "")) == str(_craft.get_ship_id())
		and int(manifest.get("pose_tick", 0)) > 0 and int(pose.get("pose_tick", 0)) >= int(manifest.pose_tick)
		and session.get_moving_interior_latest_relationship(pilot_avatar).is_empty()
		and presenter != null and pilot_avatar not in presenter.get_drawn_entity_ids()
		and _ordinary_fields(_game.get("_network_client_boarding_claim") as Dictionary, ["ship_id", "seat_id", "role"])
			== _ordinary_fields(manifest.passenger_boarding, ["ship_id", "seat_id", "role"])
		and _ordinary_fields(latest, ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state"])
			== manifest.passenger_body
		and (_ordinary_local_passenger_is_current() if seated else (_ordinary_supported_cabin() and not _player.is_seated() and assignment.is_empty()))
		and (not seated or _ordinary_fields(assignment,
			["occupant_peer_id", "avatar_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence"]) == manifest.passenger_seat))


func _ordinary_pilot_loss_client() -> bool:
	var final_manifest := _read("host.moving_reseat_checked")
	var body_source := _game.get_network_remote_body_intent_source()
	var frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	var source := _craft.get_local_input_source()
	var saved_helm := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
	if not _ordinary_require(_ordinary_consumed_manifest_current(final_manifest) and body_source != null and frame != null and source != null,
		"original client arms pilot loss only after consuming every moving stage and final seated manifest"):
		return false
	_ordinary_pilot_loss_retained = {"body_source": body_source, "frame": frame}
	var prediction_grant := ((frame.get("_occupants") as Dictionary).get(_player.get_instance_id(), {}) as Dictionary).duplicate()
	var old_prediction: Callable = prediction_grant.get("prediction_admission", Callable())
	_ordinary_pilot_loss_arm(int(final_manifest.pilot_peer))
	_write(_role + ".pilot_loss_ready", {"peer_id": _ordinary_peer_id, "player_id": str(_ordinary_player_id)})
	if not await _wait_file("host.pilot_loss_ready", 8.0) or not await _wait_file("host.pilot_loss_go", 8.0):
		return false
	if _role == "client":
		if not _ordinary_require(saved_helm.get("source") == source and saved_helm.get("capture", Callable()).is_valid()
			and source.command_produced.is_connected(saved_helm.capture), "departing pilot retains its exact original network helm callback before closing transport"):
			return false
		var stopped := _game.shutdown_network_session(&"halyard_ordinary_pilot_loss")
		if not _ordinary_require(bool(stopped.get("accepted", false)) and int(_ordinary_pilot_loss_events.session_stopped) == 1
			and _ordinary_pilot_loss_events.reason == "halyard_ordinary_pilot_loss",
			"original pilot closes its real session once through production shutdown"):
			return false
		if not await _wait_file("host.pilot_loss_released", 8.0):
			return false
		var presenter := _game.get_network_moving_interior_presenter()
		if not await _ordinary_boundary(func():
			return (_player.get_instance_id() == _ordinary_player_id and not _game.get("_transition_busy")
				and not _ordinary_authority_adapter.is_session_active() and _ordinary_authority_adapter.multiplayer.get_unique_id() == 1
				and str(_game.get("_network_session_mode")).is_empty() and _ordinary_authority_adapter.get_server_offer().is_empty()
				and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty()
				and (_game.get("_network_remote_helm") as Dictionary).is_empty()
				and (_game.get("_network_client_helm_input_sources") as Dictionary).is_empty()
				and _game.get("_network_engineer_client_seat") == null and _game.get("_network_engineer_source") == null
				and not body_source.is_bound() and (not old_prediction.is_valid() or not bool(old_prediction.call()))
				and not frame._local_prediction_is_current(_player)
				and presenter != null and not bool(presenter.get_presentation_audit().get("attached", true))
				and presenter.get_drawn_entity_ids().is_empty()
				and _ordinary_authority_adapter.get_passenger_replica_snapshot().is_empty()
				and _ordinary_authority_adapter.get_moving_interior_latest_relationship(StringName(_ordinary_walking_identity.entity_id)).is_empty()),
			8.0, "departing pilot retires actual old boarding, body, prediction, presenter and network helm grants"):
			return false
		if not _ordinary_require(source == _craft.get_command_source() and source.is_enabled_owner()
			and source.get_authority_peer_id() == int(saved_helm.authority) and source.get_local_peer_id() == 1
			and not source.command_produced.is_connected(saved_helm.capture)
			and _game.get("_piloting") and _player.is_seated_at(_craft.get_pilot_seat_anchor()),
			"departing original pilot keeps the actual local cockpit with restored ordinary input authority"):
			return false
		var sampled := {"local_throttle": false}
		var observe := func(command: ShipCommand, peer: int):
			if peer == 1 and command.throttle > 0.15:
				sampled.local_throttle = true
		source.command_produced.connect(observe)
		_ordinary_action(&"move_forward", true, 0.25)
		var usable: bool = await _ordinary_boundary(func(): return (bool(sampled.local_throttle)
			and _craft.get_last_ship_command().throttle > 0.15 and source.is_enabled_owner()),
			8.0, "departing pilot's ordinary throttle reaches its real recovered solo source and ship consumer")
		_ordinary_action(&"move_forward", false)
		source.command_produced.disconnect(observe)
		if not usable or not await _ordinary_authority_solo_ui("Session closed: halyard_ordinary_pilot_loss"):
			return false
		if not _ordinary_require(int(_ordinary_pilot_loss_events.session_stopped) == 1
			and int(_ordinary_pilot_loss_events.server_disconnected) == 0 and not body_source.is_bound(),
			"local input and UI preserve the one intentional stop and cannot revive its retired body source"):
			return false
		_write("client.pilot_loss_recovered", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	else:
		if not await _wait_file("host.pilot_loss_released", 8.0):
			return false
		var released := _read("host.pilot_loss_released")
		if not await _ordinary_boundary(func(): return _ordinary_pilot_loss_passenger_current(released, true), 8.0,
			"surviving original passenger consumes pilot retirement and current owner zero without losing its seat or session"):
			return false
		_write("client_b.pilot_loss_consumed", {})
		for stage: String in ["stand", "reseat"]:
			if not await _wait_file("host.pilot_loss_" + stage + "_go", 8.0):
				return false
			if stage == "reseat":
				await _ordinary_look(_station_anchor().global_position + Vector3.UP * 1.2)
				if not await _ordinary_boundary(func(): return (_game.station_interaction_candidate is ShipCrewSeat
					and (_game.station_interaction_candidate as ShipCrewSeat).get_seat_anchor() == _station_anchor()),
					8.0, "surviving passenger's ordinary aim rediscovers its same authored chair"):
					return false
			await _ordinary_press(&"interact")
			if not await _ordinary_boundary(func(): return (_ordinary_local_passenger_is_current() if stage == "reseat"
				else (_ordinary_supported_cabin() and not _player.is_seated())), 8.0,
				"surviving passenger's ordinary Interact completes " + stage):
				return false
			_write("client_b.pilot_loss_" + stage + "_done", {})
			if not await _wait_file("host.pilot_loss_" + stage + "_checked", 8.0):
				return false
			var checked := _read("host.pilot_loss_" + stage + "_checked")
			if not await _ordinary_boundary(func(): return _ordinary_pilot_loss_passenger_current(checked, stage == "reseat"),
				8.0, "same connected passenger consumes the authoritative fresh " + stage + " result"):
				return false
			_write("client_b.pilot_loss_" + stage + "_retained", {})
	if not await _wait_file("host.pilot_loss_complete", 30.0):
		return false
	if _role == "client_b":
		if not _ordinary_require(_ordinary_pilot_loss_passenger_current(_read("host.pilot_loss_reseat_checked"), true),
			"surviving passenger retains its consumed fresh chair claim and live session through the departing pilot's solo checks"):
			return false
	_write(_role + ".pilot_loss_complete", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	return true


# Passenger loss retains the original pilot and hull after every BOARD/MOVING
# barrier. Only client_b intentionally closes its public production session.
func _ordinary_passenger_loss_host_current(baseline: Dictionary) -> bool:
	var pilot := int(baseline.pilot_peer)
	var passenger := int(baseline.passenger_peer)
	var avatar := GameFlow.network_client_boarding_avatar_id(passenger)
	var simulation := _game.get_network_remote_body_simulation()
	var owner := _ordinary_passenger_loss_retained.owner as CrewSeatRoleAuthority
	var helm := _ordinary_passenger_loss_retained.helm as NetworkRemotePilotCommandSource
	var old_body := _ordinary_passenger_loss_retained.body as WeakRef
	var current := _ordinary_manifest(pilot, passenger)
	var commands := _game.network_session.get_remote_ship_command_snapshot()
	var admitted := _game.network_session.get_admitted_peer_ids()
	return (_game.network_session == _ordinary_authority_adapter and _ordinary_authority_adapter.is_server()
		and _ordinary_authority_adapter.is_session_active() and admitted.size() == 1 and admitted.has(pilot)
		and _ordinary_peer_generation(pilot) == int(baseline.pilot_peer_generation)
		and int(_ordinary_pilot_loss_events.transport_peer_disconnected) == 1
		and int(_ordinary_pilot_loss_events.adapter_peer_disconnected) == 1
		and int(_ordinary_pilot_loss_events.server_disconnected) == 0 and int(_ordinary_pilot_loss_events.session_stopped) == 0
		and _ordinary_pilot_is_current(pilot) and _craft.get_command_source() == helm
		and int(commands.get("pilot_count", -1)) == 1
		and int((commands.get("audit", {}) as Dictionary).get("resets", -1)) == int(_ordinary_passenger_loss_retained.helm_resets)
		and current.ownership == baseline.ownership and current.pilot_seat == baseline.pilot_seat
		and current.pilot_body == baseline.pilot_body
		and _craft.get_crew_role_authority() == owner and owner.get_assignment(passenger, avatar).is_empty()
		and (owner.get_snapshot().get("assignments", []) as Array).is_empty()
		and (owner.get_snapshot().get("intents", []) as Array).is_empty()
		and int(owner.get_snapshot().get("event_sequence", -1)) == int(_ordinary_passenger_loss_retained.role_sequence) + 1
		and _game.network_session.get_crew_assignment(passenger, avatar).is_empty()
		and _game.network_session.get_crew_moving_interior_relationship(passenger, avatar).is_empty()
		and int(_game.network_session.get_crew_command_snapshot().get("tracked_stream_count", -1)) == 0
		and (current.passenger_boarding as Dictionary).is_empty() and (current.passenger_seat as Dictionary).is_empty()
		and simulation.get_body(avatar) == null and simulation.get_body_record(avatar).is_empty() and old_body.get_ref() == null
		and int(simulation.get_audit().get("released", -1)) == int(_ordinary_passenger_loss_retained.body_releases) + 1
		and int(_ordinary_pilot_loss_events.frame_unregistered) == 1 and int(_ordinary_pilot_loss_events.body_exited) == 1
		and _ordinary_publication(avatar).is_empty()
		and _player.get_instance_id() == _ordinary_player_id and _game.phase == GameFlow.Phase.INTRO
		and not _player.is_seated() and not _player.is_control_enabled())


func _ordinary_passenger_loss_host(baseline: Dictionary) -> bool:
	var final_manifest := _read("host.moving_reseat_checked")
	var passenger := int(baseline.passenger_peer)
	var body := _game.get_network_remote_body_simulation().get_body(GameFlow.network_client_boarding_avatar_id(passenger)) as PlayerController
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	var frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	if not _ordinary_require(body != null and helm != null and owner != null and frame != null and frame.is_occupant_registered(body),
		"passenger-loss retains the exact seated authoritative body, physical frame, crew owner and surviving remote helm"):
		return false
	_ordinary_passenger_loss_retained = {"body": weakref(body), "helm": helm, "owner": owner,
		"role_sequence": owner.get_snapshot().event_sequence,
		"body_releases": _game.get_network_remote_body_simulation().get_audit().released,
		"helm_resets": (_game.network_session.get_remote_ship_command_snapshot().audit as Dictionary).resets}
	_ordinary_pilot_loss_arm(passenger)
	_ordinary_pilot_loss_events["frame_unregistered"] = 0
	_ordinary_pilot_loss_events["body_exited"] = 0
	var body_id := body.get_instance_id()
	frame.occupant_unregistered.connect(func(occupant: Node3D, _velocity: Vector3, _reason: StringName):
		if occupant.get_instance_id() == body_id:
			_ordinary_pilot_loss_events.frame_unregistered += 1)
	body.tree_exited.connect(func(): _ordinary_pilot_loss_events.body_exited += 1)
	_write("host.passenger_loss_ready", {})
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".passenger_loss_ready", 8.0):
			return false
	if not _ordinary_require(_ordinary_pilot_is_current(int(baseline.pilot_peer)) and _ordinary_passenger_is_current(passenger)
		and _ordinary_manifest(int(baseline.pilot_peer), passenger) == final_manifest,
		"all original actors arm transport observation after the complete moving prefix with both exact seated claims intact"):
		return false
	_write("host.passenger_loss_go", {})
	if not await _ordinary_boundary(func(): return _ordinary_passenger_loss_host_current(final_manifest), 8.0,
		"actual passenger disconnect retires body, frame, seat, claim and commands once while retaining the connected original pilot and ownership"):
		return false
	var released := _ordinary_manifest(int(baseline.pilot_peer), passenger)
	_write("host.passenger_loss_released", released)
	if not await _wait_file("client.passenger_loss_consumed", 8.0):
		return false
	var delivered := int(helm.get_audit().get("delivered", 0))
	_write("host.passenger_loss_throttle_go", {})
	if not await _ordinary_boundary(func(): return (_ordinary_passenger_loss_host_current(final_manifest)
		and int(helm.get_audit().get("delivered", 0)) > delivered and helm.is_holding_command()
		and float((helm.get_audit().get("controls", {}) as Dictionary).get("throttle", 0.0)) > 0.15
		and _craft.get_last_ship_command().throttle > 0.15 and _craft.velocity.length() > 0.1), 8.0,
		"surviving original pilot's fresh ordinary throttle reaches the retained remote helm and actual moving authoritative hull"):
		return false
	_write("host.passenger_loss_throttle_checked", {})
	if not await _wait_file("client.passenger_loss_controls", 8.0) or not await _wait_file("client_b.passenger_loss_recovered", 30.0):
		return false
	if not _ordinary_require(_ordinary_passenger_loss_host_current(final_manifest),
		"departing passenger's usable solo walk and UI preserve exactly one release and the surviving authority, pilot and helm grants"):
		return false
	_write("host.passenger_loss_complete", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	return await _wait_file("client.passenger_loss_complete", 8.0) and await _wait_file("client_b.passenger_loss_complete", 8.0)


func _ordinary_passenger_loss_pilot_current(manifest: Dictionary) -> bool:
	var session := _game.network_session
	var passenger_avatar := GameFlow.network_client_boarding_avatar_id(int(manifest.passenger_peer))
	var source := _craft.get_local_input_source()
	var saved := _ordinary_passenger_loss_retained.helm_grant as Dictionary
	var presenter := _game.get_network_moving_interior_presenter()
	var ownership: Dictionary = {}
	for row: Dictionary in (session.get_authoritative_snapshot().get("sections", {}) as Dictionary).get("ownership", []):
		if row.get("ship_id") == _craft.get_ship_id():
			ownership = row
	return (session == _ordinary_authority_adapter and _ordinary_authenticated() and _ordinary_local_pilot_is_current()
		and int(_ordinary_pilot_loss_events.session_stopped) == 0 and int(_ordinary_pilot_loss_events.server_disconnected) == 0
		and source == _ordinary_passenger_loss_retained.source and source.command_produced.is_connected(saved.capture)
		and (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) == saved
		and _ordinary_fields(ownership, ["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"]) == manifest.ownership
		and _ordinary_fields(_game.get("_network_client_boarding_claim") as Dictionary, ["ship_id", "seat_id", "role"])
			== _ordinary_fields(manifest.pilot_seat, ["ship_id", "seat_id", "role"])
		and session.get_moving_interior_latest_relationship(passenger_avatar).is_empty()
		and presenter != null and passenger_avatar not in presenter.get_drawn_entity_ids())


func _ordinary_passenger_loss_client() -> bool:
	var final_manifest := _read("host.moving_reseat_checked")
	var body_source := _game.get_network_remote_body_intent_source()
	var frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	var presenter := _game.get_network_moving_interior_presenter()
	var source := _craft.get_local_input_source()
	var saved_helm := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
	if not _ordinary_require(_ordinary_consumed_manifest_current(final_manifest) and body_source != null
		and frame != null and presenter != null and source != null,
		"original clients arm passenger departure only after consuming the complete BOARD and seven moving stages"):
		return false
	_ordinary_passenger_loss_retained = {"source": source, "helm_grant": saved_helm}
	var prediction := (frame.get("_occupants") as Dictionary).get(_player.get_instance_id(), {}) as Dictionary
	var old_prediction: Callable = prediction.get("prediction_admission", Callable())
	if _role == "client" and not _ordinary_require(saved_helm.get("source") == source
		and saved_helm.get("capture", Callable()).is_valid() and source.command_produced.is_connected(saved_helm.capture),
		"surviving pilot retains its exact original ordinary source and production network command callback"):
		return false
	if _role == "client_b" and not _ordinary_require(old_prediction.is_valid() and bool(old_prediction.call())
		and frame._local_prediction_is_current(_player), "departing passenger retains its actual live seated cabin prediction grant"):
		return false
	_ordinary_pilot_loss_arm(int(final_manifest.passenger_peer))
	_write(_role + ".passenger_loss_ready", {"peer_id": _ordinary_peer_id, "player_id": str(_ordinary_player_id)})
	if not await _wait_file("host.passenger_loss_ready", 8.0) or not await _wait_file("host.passenger_loss_go", 8.0):
		return false
	if _role == "client_b":
		var stopped := _game.shutdown_network_session(&"halyard_ordinary_passenger_loss")
		if not _ordinary_require(bool(stopped.get("accepted", false)) and int(_ordinary_pilot_loss_events.session_stopped) == 1
			and int(_ordinary_pilot_loss_events.server_disconnected) == 0
			and _ordinary_pilot_loss_events.reason == "halyard_ordinary_passenger_loss",
			"original passenger intentionally closes its public production session once without a server-loss event"):
			return false
		if not await _wait_file("host.passenger_loss_released", 8.0):
			return false
		if not await _ordinary_boundary(func(): return (_player.get_instance_id() == _ordinary_player_id
			and not _ordinary_authority_adapter.is_session_active() and _ordinary_authority_adapter.multiplayer.get_unique_id() == 1
			and _ordinary_authority_adapter.get_server_offer().is_empty() and str(_game.get("_network_session_mode")).is_empty()
			and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty()
			and (_game.get("_network_remote_helm") as Dictionary).is_empty()
			and (_game.get("_network_client_helm_input_sources") as Dictionary).is_empty()
			and _game.get("_network_engineer_client_seat") == null and _game.get("_network_engineer_source") == null
			and not body_source.is_bound() and (not old_prediction.is_valid() or not bool(old_prediction.call()))
			and not frame._local_prediction_is_current(_player)
			and not bool(presenter.get_presentation_audit().get("attached", true)) and presenter.get_drawn_entity_ids().is_empty()
			and _ordinary_authority_adapter.get_passenger_replica_snapshot().is_empty()
			and _ordinary_authority_adapter.get_moving_interior_latest_relationship(StringName(_ordinary_walking_identity.entity_id)).is_empty()),
			8.0, "departing passenger retires exact old boarding, body, frame prediction, presenter and network command grants"):
			return false
		if not await _ordinary_boundary(func(): return _ordinary_solo_passenger_supported(frame), 8.0,
			"same departing Player becomes a supported awake solo cabin walker through production cleanup"):
			return false
		if not await _ordinary_authority_solo_walk(frame) or not await _ordinary_authority_solo_ui("Session closed: halyard_ordinary_passenger_loss"):
			return false
		if not _ordinary_require(int(_ordinary_pilot_loss_events.session_stopped) == 1 and int(_ordinary_pilot_loss_events.server_disconnected) == 0
			and not body_source.is_bound() and not frame._local_prediction_is_current(_player),
			"departing passenger's ordinary solo walk and pause Resume cannot revive its retired network grants"):
			return false
		_write("client_b.passenger_loss_recovered", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	else:
		if not await _wait_file("host.passenger_loss_released", 8.0):
			return false
		if not await _ordinary_boundary(func(): return _ordinary_passenger_loss_pilot_current(final_manifest), 8.0,
			"connected original pilot consumes passenger retirement while retaining exact cockpit claim, ownership and command callback"):
			return false
		_write("client.passenger_loss_consumed", {})
		if not await _wait_file("host.passenger_loss_throttle_go", 8.0):
			return false
		_ordinary_action(&"move_forward", true, 0.25)
		var throttle_checked: bool = await _wait_file("host.passenger_loss_throttle_checked", 8.0)
		_ordinary_action(&"move_forward", false)
		if not throttle_checked or not _ordinary_require(_ordinary_passenger_loss_pilot_current(final_manifest),
			"ordinary throttle leaves surviving pilot's original connected controls and command grant current"):
			return false
		_write("client.passenger_loss_controls", {})
	if not await _wait_file("host.passenger_loss_complete", 30.0):
		return false
	if _role == "client" and not _ordinary_require(_ordinary_passenger_loss_pilot_current(final_manifest),
		"surviving original pilot remains connected with its controls after the former passenger's solo input and UI"):
		return false
	_write(_role + ".passenger_loss_complete", {"events": _ordinary_pilot_loss_events.duplicate(true)})
	return true


# HALYARD-AUTHORITY-STOP starts after the entire accepted moving sequence.
# These are observations of the existing transport/cleanup owners: no client
# disconnect, handler call, migration, authority change or recovery pose is sent.
func _ordinary_authority_stop_host(baseline: Dictionary) -> bool:
	var pilot := int(baseline.pilot_peer)
	var passenger := int(baseline.passenger_peer)
	_ordinary_authority_adapter = _game.network_session
	var simulation := _game.get_network_remote_body_simulation()
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	var body := simulation.get_body(GameFlow.network_client_boarding_avatar_id(passenger))
	var helm := _craft.get_command_source() as NetworkRemotePilotCommandSource
	if not _ordinary_require(body != null and owner != null and helm != null,
		"server-stop retains the actual original passenger body, crew authority and remote helm"):
		return false
	var old_body: WeakRef = weakref(body)
	var old_helm: WeakRef = weakref(helm)
	_ordinary_authority_events = {"session_stopped": 0, "reason": ""}
	_ordinary_authority_adapter.session_stopped.connect(func(reason: StringName):
		_ordinary_authority_events.session_stopped += 1
		_ordinary_authority_events.reason = str(reason))
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".authority_stop_ready", 8.0):
			return false
	# Both ready receipts follow their original moving_complete and signal
	# registration. Stop only while the original bodies still hold both seats.
	if not _ordinary_require(_ordinary_pilot_is_current(pilot) and _ordinary_passenger_is_current(passenger)
		and simulation.get_body(GameFlow.network_client_boarding_avatar_id(passenger)) == body
		and _craft.get_command_source() == helm and _craft.get_crew_role_authority() == owner
		and _ordinary_peer_generation(pilot) == int(baseline.pilot_peer_generation)
		and _ordinary_peer_generation(passenger) == int(baseline.passenger_peer_generation)
		and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled(),
		"non-playing authority stops only after full moving completion with both original occupants aboard"):
		return false
	var stopped := _game.shutdown_network_session(&"halyard_ordinary_authority_stop")
	if not _ordinary_require(bool(stopped.get("accepted", false))
		and int(_ordinary_authority_events.session_stopped) == 1
		and _ordinary_authority_events.reason == "halyard_ordinary_authority_stop",
		"authority calls existing production shutdown once and receives its one stopped event"):
		return false
	_write("host.authority_stopped", {"events": _ordinary_authority_events})
	if not await _ordinary_boundary(func():
		return (not _ordinary_authority_adapter.is_session_active()
			and (_ordinary_authority_adapter.get_boarding_snapshot().get("occupancies", []) as Array).is_empty()
			and int(_ordinary_authority_adapter.get_owned_ship(_craft.get_ship_id()).get("owner_peer_id", 0)) == 0
			and int(_ordinary_authority_adapter.get_remote_ship_command_snapshot().get("pilot_count", -1)) == 0
			and (owner.get_snapshot().get("assignments", []) as Array).is_empty()
			and simulation.get_body_count() == 0 and old_body.get_ref() == null and old_helm.get_ref() == null
			and (_game.get("_network_remote_pilots") as Dictionary).is_empty()
			and (_game.get("_network_moving_interior_records") as Dictionary).is_empty()
			and not _craft.is_remote_piloted() and _craft.get_command_source() == _craft.get_local_input_source()
			and _craft.get_crew_role_authority() == null),
		8.0, "server-stop retires exact retained body, role owner, helm, boarding and ship ownership grants"):
		return false
	for role in ["client", "client_b"]:
		if not await _wait_file(role + ".authority_recovered", 30.0):
			return false
	return _ordinary_require(int(_ordinary_authority_events.session_stopped) == 1,
		"authority remains stopped once while both original clients prove usable solo controls")


func _ordinary_authority_stop_client() -> bool:
	_ordinary_authority_adapter = _game.network_session
	# Retain the actual API and sources before the host closes its transport;
	# a replacement adapter cannot make checks of the old grants pass by absence.
	var transport := _ordinary_authority_adapter.multiplayer
	var body_source := _game.get_network_remote_body_intent_source()
	var frame := _craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	var presenter := _game.get_network_moving_interior_presenter()
	var source := _craft.get_local_input_source()
	var saved_helm := (_game.get("_network_client_helm_input_sources") as Dictionary).get(_craft.get_instance_id(), {}) as Dictionary
	var old_claim := (_game.get("_network_client_boarding_claim") as Dictionary).duplicate(true)
	var final_manifest := _read("host.moving_reseat_checked")
	if not _ordinary_require(_ordinary_consumed_manifest_current(final_manifest)
		and body_source != null and frame != null and presenter != null and source != null
		and not old_claim.is_empty()
		and transport.server_disconnected.is_connected(Callable(_ordinary_authority_adapter, "_on_server_disconnected")),
		"original seated client retains real transport handler and exact old body, prediction and boarding sources before stop"):
		return false
	if _role == "client" and not _ordinary_require(saved_helm.get("source") == source
		and saved_helm.get("capture", Callable()).is_valid()
		and source.command_produced.is_connected(saved_helm.capture)
		and source.get_authority_peer_id() == _ordinary_peer_id,
		"former pilot retains actual borrowed helm grant and network command capture before authority stop"):
		return false
	var prediction_grant := ((frame.get("_occupants") as Dictionary).get(_player.get_instance_id(), {}) as Dictionary).duplicate()
	var old_prediction: Callable = prediction_grant.get("prediction_admission", Callable())
	if _role == "client_b" and not _ordinary_require(old_prediction.is_valid() and bool(old_prediction.call())
		and frame._local_prediction_is_current(_player),
		"former passenger retains the exact live production cabin prediction admission before authority stop"):
		return false
	_ordinary_authority_events = {"server_disconnected": 0, "session_stopped": 0, "reason": ""}
	transport.server_disconnected.connect(func(): _ordinary_authority_events.server_disconnected += 1)
	_ordinary_authority_adapter.session_stopped.connect(func(reason: StringName):
		_ordinary_authority_events.session_stopped += 1
		_ordinary_authority_events.reason = str(reason))
	_write(_role + ".authority_stop_ready", {"pid": OS.get_process_id(), "peer_id": _ordinary_peer_id,
		"peer_generation": _ordinary_initial_peer_generation, "player_id": str(_ordinary_player_id),
		"boarding": _ordinary_fields(old_claim, ["ship_id", "seat_id", "role"])})
	if not await _ordinary_boundary(func(): return (int(_ordinary_authority_events.server_disconnected) == 1
		and int(_ordinary_authority_events.session_stopped) == 1
		and _ordinary_authority_events.reason == "server_disconnected"), 8.0,
		"actual original client transport emits server_disconnected and production adapter stops for that reason"):
		return false
	if not await _wait_file("host.authority_stopped", 8.0):
		return false
	if not await _ordinary_boundary(func():
		return (_player.get_instance_id() == _ordinary_player_id and not _game.get("_transition_busy")
			and not _ordinary_authority_adapter.is_session_active() and _ordinary_authority_adapter.get_server_offer().is_empty()
			and _ordinary_authority_adapter.multiplayer.get_unique_id() == 1
			and str(_game.get("_network_session_mode")).is_empty()
			and (_game.get("_network_client_boarding_claim") as Dictionary).is_empty()
			and (_game.get("_network_remote_helm") as Dictionary).is_empty()
			and (_game.get("_network_client_helm_input_sources") as Dictionary).is_empty()
			and _game.get("_network_engineer_client_seat") == null
			and _game.get("_network_engineer_source") == null
			and not body_source.is_bound() and (not old_prediction.is_valid() or not bool(old_prediction.call()))
			and not frame._local_prediction_is_current(_player)
			and not bool(presenter.get_presentation_audit().get("attached", true))
			and presenter.get_drawn_entity_ids().is_empty()
			and _ordinary_authority_adapter.get_passenger_replica_snapshot().is_empty()
			and _ordinary_authority_adapter.get_moving_interior_latest_relationship(
				StringName(_ordinary_walking_identity.entity_id)).is_empty()),
		8.0, "production stopped owner retires old admission, boarding, body stream, cabin prediction, crew seat and remote helm identities"):
		return false
	if _role == "client":
		# Production restores the borrowed input owner and keeps the real local
		# cockpit. Do not invent a forced stand or a recovery world position.
		if not _ordinary_require(source == _craft.get_command_source() and source.is_enabled_owner()
			and source.get_authority_peer_id() == int(saved_helm.authority)
			and source.get_local_peer_id() == 1 and not source.command_produced.is_connected(saved_helm.capture)
			and _game.get("_piloting") and _player.is_seated_at(_craft.get_pilot_seat_anchor()),
			"former pilot keeps ordinary local cockpit with restored original input authority and retired network capture"):
			return false
		var sampled := {"local_throttle": false}
		var observe := func(command: ShipCommand, peer: int):
			if peer == 1 and command.throttle > 0.15:
				sampled.local_throttle = true
		source.command_produced.connect(observe)
		_ordinary_action(&"move_forward", true, 0.25)
		var usable := await _ordinary_boundary(func(): return (bool(sampled.local_throttle)
			and _craft.get_last_ship_command().throttle > 0.15 and source.is_enabled_owner()),
			8.0, "former pilot ordinary throttle samples and reaches actual solo ship consumer after host loss")
		_ordinary_action(&"move_forward", false)
		source.command_produced.disconnect(observe)
		if not usable:
			return false
	else:
		if not await _ordinary_boundary(func(): return _ordinary_solo_passenger_supported(frame), 8.0,
			"former passenger is restored to same supported usable solo cabin body by production seat cleanup"):
			return false
		if not await _ordinary_authority_solo_walk(frame):
			return false
	if not await _ordinary_authority_solo_ui():
		return false
	if not _ordinary_require(int(_ordinary_authority_events.server_disconnected) == 1
		and int(_ordinary_authority_events.session_stopped) == 1
		and not body_source.is_bound() and (not old_prediction.is_valid() or not bool(old_prediction.call()))
		and not frame._local_prediction_is_current(_player),
		"usable solo input and UI cannot revive old transport, body stream or cabin prediction grants"):
		return false
	_write(_role + ".authority_recovered", {"events": _ordinary_authority_events,
		"player_id": str(_player.get_instance_id()), "phase": _game.phase, "piloting": _game.get("_piloting")})
	return true


func _ordinary_solo_passenger_supported(frame: MovingInteriorFrame) -> bool:
	return _player.get_instance_id() == _ordinary_player_id and not _player.is_seated() \
		and not _player.is_station_seated() and _player.is_control_enabled() and _player.is_on_floor() \
		and not _game.get("_piloting") and not _craft.is_piloted() and not _game.get("_transition_busy") \
		and _game.phase == GameFlow.Phase.IN_FLIGHT_CABIN \
		and _player.get_cabin_containment_report().get("frame") == _craft \
		and frame.is_occupant_registered(_player) and frame.is_simulation_authority_for(_player) \
		and not frame._local_prediction_is_current(_player)


func _ordinary_authority_solo_walk(frame: MovingInteriorFrame) -> bool:
	var start := _craft.to_local(_player.global_position)
	var goal := Vector3(0.0, start.y, -6.80)
	await _ordinary_look(_craft.to_global(goal) + Vector3.UP * 1.4)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and not _ordinary_aborted():
		# Cabin-local displacement excludes hull carry. Use the same ordinary
		# camera-relative action inputs as the accepted boarding/moving walk.
		var delta := (_craft.to_global(goal) - _player.global_position).slide(Vector3.UP)
		var forward := (-_player.get_camera().global_basis.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var axis := Vector2(delta.normalized().dot(right), -delta.normalized().dot(forward))
		_ordinary_release_walk()
		_ordinary_action(&"move_left" if axis.x < 0.0 else &"move_right", true, absf(axis.x))
		_ordinary_action(&"move_forward" if axis.y < 0.0 else &"move_back", true, absf(axis.y))
		await _ticks(1)
		if _craft.to_local(_player.global_position).distance_to(start) > 0.6 and _ordinary_solo_passenger_supported(frame):
			_ordinary_release_walk()
			print("HALYARD_AUTHORITY_STOP_SOLO_WALK: role=", _role,
				" distance=", _craft.to_local(_player.global_position).distance_to(start))
			return _ordinary_require(true, "same supported former passenger walks over point six metres through ordinary solo inputs within fifteen seconds")
	_ordinary_release_walk()
	return _ordinary_require(false, "same supported former passenger walks over point six metres through ordinary solo inputs within fifteen seconds")


func _ordinary_authority_solo_ui(expected_message: String = "Connection to the session host was lost.") -> bool:
	var presenter := _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	var view := presenter.get_snapshot()
	var expected_role := &"pilot" if _role == "client" else &"observer"
	if not _ordinary_require(view.get("state") == &"disconnected" and view.get("local_role") == expected_role
		and view.get("ownership_text") == str(expected_role).to_upper()
		and str(view.get("message", "")).contains(expected_message)
		and bool(view.get("craft_control_available", false)),
		"actual consumed HUD honestly reports host loss and current solo control role"):
		return false
	await _ordinary_press(&"pause")
	if not await _ordinary_boundary(func(): return paused, 8.0,
		"ordinary pause input opens real solo pause UI after server stop"):
		return false
	if not await _ordinary_button("ResumeButton"):
		return false
	return await _ordinary_boundary(func(): return not paused, 8.0,
		"real focused ResumeButton responds to ordinary ui_accept and resumes solo play")


func _ordinary_manifest(pilot_peer: int, passenger_peer: int) -> Dictionary:
	var pilot_avatar := GameFlow.network_client_boarding_avatar_id(pilot_peer)
	var passenger_avatar := GameFlow.network_client_boarding_avatar_id(passenger_peer)
	var pilot_seat: Dictionary = {}
	var passenger_boarding: Dictionary = {}
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if int(held.get("peer_id", 0)) == pilot_peer and held.get("avatar_id") == pilot_avatar:
			pilot_seat = _ordinary_fields(held, ["peer_id", "avatar_id", "ship_id", "ship_generation", "role", "seat_id", "seat_generation", "claim_sequence"])
		elif int(held.get("peer_id", 0)) == passenger_peer and held.get("avatar_id") == passenger_avatar:
			passenger_boarding = _ordinary_fields(held, ["peer_id", "avatar_id", "ship_id", "ship_generation", "role", "seat_id", "seat_generation", "claim_sequence"])
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	return {"pilot_peer": pilot_peer, "passenger_peer": passenger_peer,
		"pilot_peer_generation": _ordinary_peer_generation(pilot_peer),
		"passenger_peer_generation": _ordinary_peer_generation(passenger_peer),
		"ship_id": str(_craft.get_ship_id()),
		"ownership": _ordinary_fields(_game.network_session.get_owned_ship(_craft.get_ship_id()),
			["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"]),
		"pilot_seat": pilot_seat, "passenger_boarding": passenger_boarding,
		"passenger_seat": _ordinary_fields(owner.get_assignment(passenger_peer, passenger_avatar) if owner != null else {},
			["occupant_peer_id", "avatar_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence"]),
		"pilot_body": _ordinary_fields(_ordinary_publication(pilot_avatar).get("wire", {}) as Dictionary,
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state"]),
		"passenger_body": _ordinary_fields(_ordinary_publication(passenger_avatar).get("wire", {}) as Dictionary,
			["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation", "occupancy_state"])}


func _ordinary_manifest_current(manifest: Dictionary) -> bool:
	var pilot := int(manifest.get("pilot_peer", 0))
	var passenger := int(manifest.get("passenger_peer", 0))
	var ownership := manifest.get("ownership", {}) as Dictionary
	var pilot_seat := manifest.get("pilot_seat", {}) as Dictionary
	var passenger_seat := manifest.get("passenger_seat", {}) as Dictionary
	var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
	if owner == null or pilot <= 1 or passenger <= 1 or pilot == passenger:
		return false
	var exclusive := owner.get_assignment(pilot, GameFlow.network_client_boarding_avatar_id(pilot)).is_empty() \
		and owner.get_assignment(1, GameFlow.SOLO_CREW_AVATAR_ID).is_empty() \
		and (owner.get_snapshot().get("assignments", []) as Array).size() == 1
	var count := 0
	for held: Dictionary in _game.network_session.get_boarding_snapshot().get("occupancies", []):
		if held.get("ship_id") == _craft.get_ship_id():
			count += 1
	for kind in ["pilot_seat", "passenger_boarding"]:
		var expected_peer := pilot if kind == "pilot_seat" else passenger
		var boarding := manifest.get(kind, {}) as Dictionary
		if int(boarding.get("peer_id", 0)) != expected_peer \
			or str(boarding.get("avatar_id", "")) != str(GameFlow.network_client_boarding_avatar_id(expected_peer)) \
			or str(boarding.get("ship_id", "")) != str(_craft.get_ship_id()) \
			or int(boarding.get("ship_generation", 0)) != int(ownership.get("ship_generation", -1)) \
			or int(boarding.get("seat_generation", 0)) <= 0 or int(boarding.get("claim_sequence", 0)) <= 0:
			return false
	for kind in ["pilot_body", "passenger_body"]:
		var expected_peer := pilot if kind == "pilot_body" else passenger
		var wire := manifest.get(kind, {}) as Dictionary
		var initial := _read("client.cabin" if kind == "pilot_body" else "client_b.cabin")
		if str(wire.get("entity_id", "")) != str(GameFlow.network_client_boarding_avatar_id(expected_peer)) \
			or int(wire.get("entity_generation", 0)) != int(initial.get("entity_generation", -1)) \
			or int(wire.get("entity_generation", 0)) <= 0 \
			or str(wire.get("parent_frame_id", "")) != "frame_%s" % _craft.get_ship_id() \
			or int(wire.get("parent_frame_generation", 0)) != 1 \
			or int(wire.get("occupancy_state", -1)) != NetworkMovingInteriorRelationship.STATE_SEATED:
			return false
	return _ordinary_pilot_is_current(pilot) and _ordinary_passenger_is_current(passenger) \
		and exclusive and count == 2 and _ordinary_manifest(pilot, passenger) == manifest \
		and int(ownership.get("owner_peer_id", 0)) == pilot and int(ownership.get("ownership_generation", 0)) > 0 \
		and int(pilot_seat.get("seat_generation", 0)) > 0 and int(pilot_seat.get("claim_sequence", 0)) > 0 \
		and pilot_seat.get("seat_id") != passenger_seat.get("seat_id") \
		and _ordinary_publication(GameFlow.network_client_boarding_avatar_id(pilot)).get("occupant") \
			!= _ordinary_publication(GameFlow.network_client_boarding_avatar_id(passenger)).get("occupant") \
		and _game.phase == GameFlow.Phase.INTRO and not _player.is_seated() and not _player.is_control_enabled() \
		and _craft.velocity.length() <= 0.1


func _ordinary_consumed_manifest_current(manifest: Dictionary) -> bool:
	var local_current := _ordinary_local_pilot_is_current() if _role == "client" else _ordinary_local_passenger_is_current()
	if not local_current or not _ordinary_walking_identity_is_preserved():
		return false
	var sections := _game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary
	var ownership: Dictionary = {}
	for record: Dictionary in sections.get("ownership", []):
		if record.get("ship_id") == _craft.get_ship_id():
			ownership = record
	if _ordinary_fields(ownership, ["ship_id", "ship_generation", "owner_peer_id", "ownership_generation"]) != manifest.get("ownership", {}):
		return false
	var pilot_seat := manifest.get("pilot_seat", {}) as Dictionary
	var own_boarding := manifest.get("pilot_seat" if _role == "client" else "passenger_boarding", {}) as Dictionary
	var boarding_claim := _game.get("_network_client_boarding_claim") as Dictionary
	# The received boarding grant stores only these three fields. Passenger
	# admission retains its cabin berth; the separate consumed chair replica
	# below proves crew_port_00 and its real seat/claim generations.
	if _ordinary_fields(boarding_claim, ["ship_id", "seat_id", "role"]) \
		!= _ordinary_fields(own_boarding, ["ship_id", "seat_id", "role"]) \
		or int(own_boarding.get("peer_id", 0)) != _ordinary_peer_id \
		or str(own_boarding.get("avatar_id", "")) != str(_ordinary_walking_identity.get("entity_id", "")) \
		or int(manifest.get("pilot_peer" if _role == "client" else "passenger_peer", 0)) != _ordinary_peer_id \
		or int(manifest.get("pilot_peer_generation" if _role == "client" else "passenger_peer_generation", 0)) != _ordinary_initial_peer_generation \
		or int(own_boarding.get("seat_generation", 0)) <= 0 or int(own_boarding.get("claim_sequence", 0)) <= 0:
		return false
	for kind in ["pilot_body", "passenger_body"]:
		var expected := manifest.get(kind, {}) as Dictionary
		var avatar := StringName(expected.get("entity_id", ""))
		var latest := _game.network_session.get_moving_interior_latest_relationship(avatar)
		var identity_fields := ["entity_id", "entity_generation", "parent_frame_id", "parent_frame_generation"]
		if _role == "client" and kind == "pilot_body":
			# The host excludes the pilot owner from its remote seated-anchor
			# publication. This peer retains the original walking relationship;
			# its authenticated body/frame identity must still match. Its actual
			# local seat and received authoritative boarding/ownership above own
			# the pilot-seat proof, without changing production echo policy.
			var claim := _game.get("_network_client_boarding_claim") as Dictionary
			if str(claim.get("seat_id", "")) != str(pilot_seat.get("seat_id", "")):
				return false
		else:
			identity_fields.append("occupancy_state")
		if _ordinary_fields(latest, identity_fields) != _ordinary_fields(expected, identity_fields):
			return false
	if _role == "client_b":
		var view := _game.network_session.get_passenger_replica_snapshot()
		if _ordinary_fields(view.get("assignment", {}) as Dictionary,
			["occupant_peer_id", "avatar_id", "vessel_id", "role", "seat_id", "seat_generation", "claim_sequence"]) != manifest.get("passenger_seat", {}):
			return false
		if int(view.get("entity_generation", 0)) != int(_ordinary_walking_identity.get("entity_generation", -1)):
			return false
		var default_source := _craft.get("_default_local_command_source") as ShipCommandSource
		var active_source := _craft.get("_command_source") as ShipCommandSource
		if (default_source != null and default_source.is_enabled_owner()) or (active_source != null and active_source.is_enabled_owner()):
			return false
	return int(ownership.get("owner_peer_generation", 0)) == int(manifest.get("pilot_peer_generation", -1)) \
		and _player.get_instance_id() == _ordinary_player_id


func _ordinary_fields(record: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for key: String in keys:
		if record.has(key):
			var value: Variant = record[key]
			if value is StringName:
				result[key] = str(value)
			elif typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
				result[key] = value
	# Receipt JSON decodes numbers as floats, while network variants retain ints.
	# Compare projected primitives in the same JSON representation, preserving
	# fractional values and leaving the source records untouched.
	return JSON.parse_string(JSON.stringify(result, "", true, true)) as Dictionary


func _ordinary_boundary(predicate: Callable, seconds: float, description: String) -> bool:
	return _ordinary_require(await _until(predicate, seconds), description)


func _ordinary_require(condition: bool, description: String) -> bool:
	_check(condition, description)
	return condition


func _ordinary_aborted() -> bool:
	return FileAccess.file_exists(_directory.path_join("abort")) \
		or (_profile_deadline > 0 and Time.get_ticks_msec() >= _profile_deadline)


func _ordinary_node_identity(node: Node) -> Dictionary:
	if not is_instance_valid(node):
		return {"valid": false}
	return {"valid": true, "id": str(node.get_instance_id()), "path": str(node.get_path()) if node.is_inside_tree() else ""}


func _ordinary_failure_snapshot(description: String) -> Dictionary:
	var snapshot: Dictionary = {"role": _role, "description": description, "pid": OS.get_process_id(),
		"wall": Time.get_unix_time_from_system(), "ticks": Engine.get_physics_frames(),
		"peer_id": _ordinary_peer_id, "peer_generation": _ordinary_initial_peer_generation,
		"original_player_id": str(_ordinary_player_id), "walking_identity": _ordinary_walking_identity,
		"moving_selected": _ordinary_two_client_moving,
		"shared_abort": _ordinary_fields(_read("abort"), ["role", "description", "snapshot"])}
	if _ordinary_two_client_authority_stop:
		snapshot["authority_stop"] = {"events": _ordinary_authority_events.duplicate(true),
			"original_adapter_valid": is_instance_valid(_ordinary_authority_adapter)}
		if is_instance_valid(_ordinary_authority_adapter):
			(snapshot.authority_stop as Dictionary)["original_adapter_active"] = _ordinary_authority_adapter.is_session_active()
			(snapshot.authority_stop as Dictionary)["original_end_reason"] = _ordinary_authority_adapter.get_session_end_reason_snapshot()
	if not is_instance_valid(_game) or not is_instance_valid(_craft) or not is_instance_valid(_player):
		snapshot["missing"] = "Main, craft or Player unavailable"
		return snapshot
	if _ordinary_two_client_passenger_loss:
		var retired_body := _ordinary_passenger_loss_retained.get("body") as WeakRef
		snapshot["passenger_loss"] = {"events": _ordinary_pilot_loss_events.duplicate(true),
			"session_active": _game.network_session.is_session_active(),
			"admitted_peers": _game.network_session.get_admitted_peer_ids(),
			"original_body_alive": retired_body != null and retired_body.get_ref() != null,
			"body_audit": _game.get_network_remote_body_simulation().get_audit(),
			"ownership": _game.network_session.get_owned_ship(_craft.get_ship_id()),
			"remote_commands": _game.network_session.get_remote_ship_command_snapshot(),
			"crew_commands": _game.network_session.get_crew_command_snapshot(),
			"boarding": _game.network_session.get_boarding_snapshot(),
			"released": _read("host.passenger_loss_released"),
			"complete": _read("host.passenger_loss_complete")}
	if _ordinary_two_client_pilot_loss:
		var old_helm: WeakRef = _ordinary_pilot_loss_retained.get("helm") as WeakRef
		var pilot_manifest := _read("host.moving_reseat_checked")
		var pilot_peer := int(pilot_manifest.get("pilot_peer", 0))
		var passenger_peer := int(pilot_manifest.get("passenger_peer", 0))
		snapshot["pilot_loss"] = {"events": _ordinary_pilot_loss_events.duplicate(true),
			"session_active": _game.network_session.is_session_active(),
			"admitted_peers": _game.network_session.get_admitted_peer_ids(),
			"original_adapter_current": _game.network_session == _ordinary_authority_adapter,
			"ownership": _game.network_session.get_owned_ship(_craft.get_ship_id()),
			"remote_commands": _game.network_session.get_remote_ship_command_snapshot(),
			"remote_piloted": _craft.is_remote_piloted(), "piloted": _craft.is_piloted(),
			"old_helm_alive": old_helm != null and old_helm.get_ref() != null,
			"retained_local_source_current": _craft.get_command_source() == _ordinary_pilot_loss_retained.get("source"),
			"pilot_publication": str(_ordinary_publication(GameFlow.network_client_boarding_avatar_id(pilot_peer))),
			"passenger_publication": str(_ordinary_publication(GameFlow.network_client_boarding_avatar_id(passenger_peer))),
			"boarding": _game.network_session.get_boarding_snapshot(),
			"passenger_replica": _game.network_session.get_passenger_replica_snapshot(),
			"consumed_pose": _game._network_craft_pose_stream.latest_sample(_craft.get_ship_id()),
			"released": _read("host.pilot_loss_released"),
			"stand": _read("host.pilot_loss_stand_checked"), "reseat": _read("host.pilot_loss_reseat_checked")}
	var source := _game.get_network_remote_body_intent_source()
	snapshot["player"] = {"identity": _ordinary_node_identity(_player), "position": str(_player.global_position),
		"craft_local": str(_craft.to_local(_player.global_position)), "floor": _player.is_on_floor(),
		"velocity": str(_player.velocity), "controls": _player.is_control_enabled(), "seated": _player.is_seated(),
		"seat": _ordinary_node_identity(_player.get("_seat_anchor") as Node),
		"containment": str(_player.get_cabin_containment_report())}
	snapshot["phase"] = _game.phase
	snapshot["transition_busy"] = bool(_game.get("_transition_busy"))
	snapshot["piloting"] = bool(_game.get("_piloting"))
	snapshot["candidate"] = _ordinary_node_identity(_game.boarding_candidate)
	snapshot["near_ship"] = bool(_game.get("_near_ship"))
	snapshot["station_candidate"] = _ordinary_node_identity(_game.station_interaction_candidate)
	snapshot["nearby"] = str(_player.get_nearby_interactables())
	snapshot["craft_pose"] = str(_craft.global_transform)
	snapshot["craft_velocity"] = str(_craft.velocity)
	if _ordinary_two_client_moving:
		var telemetry := _craft.get_telemetry()
		var operation := _craft.get_network_operation_telemetry_presentation()
		var operation_audit := _craft.get_network_operation_presentation_audit()
		snapshot["moving_engine"] = {
			"source": "accepted_host_operation_presentation" if _role == "client_b" else "local_simulation",
			"raw_telemetry": telemetry, "operation_presentation": operation,
			"operation_audit": {"state": operation_audit.get("state", {}),
				"source_policy": (operation_audit.get("source", {}) as Dictionary).get("policy", []),
				"owns_operation_authority": operation_audit.get("owns_operation_authority", false)}}
		var baseline := _read("host.seats_confirmed")
		if _role in ["client", "client_b"] and not baseline.is_empty():
			snapshot["moving_departure_gates"] = {
				"speed_above_point_one": _craft.velocity.length() > 0.1,
				"raw_engine_online": telemetry.get("engine_state") == HeroShip.ENGINE_ONLINE,
				"accepted_operation_engine_online": operation.get("engine_state") == HeroShip.ENGINE_ONLINE,
				"selected_engine_online": _ordinary_moving_engine_online(),
				"baseline_consumed_current": _ordinary_consumed_manifest_current(baseline)}
	snapshot["claim"] = _ordinary_fields(_game.get("_network_client_boarding_claim") as Dictionary,
		["ship_id", "seat_id", "role"])
	snapshot["body_source"] = source.get_audit() if source != null else {}
	snapshot["body_relationship"] = str(_game.network_session.get_moving_interior_latest_relationship(
		source.get_entity_id())) if source != null else ""
	snapshot["boarding_audit"] = _game.get_network_client_boarding_audit()
	snapshot["passenger_replica"] = _game.network_session.get_passenger_replica_snapshot()
	var presenter := _game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	snapshot["consumed_hud"] = presenter.get_snapshot() if presenter != null else {}
	snapshot["local_producer"] = _ordinary_producer_state(_craft.get("_default_local_command_source") as ShipCommandSource)
	snapshot["active_producer"] = _ordinary_producer_state(_craft.get("_command_source") as ShipCommandSource)
	snapshot["ownership"] = _game.network_session.get_owned_ship(_craft.get_ship_id())
	var sections := _game.network_session.get_authoritative_snapshot().get("sections", {}) as Dictionary
	snapshot["consumed_ownership"] = sections.get("ownership", [])
	snapshot["consumed_boarding"] = sections.get("boarding", [])
	snapshot["consumed_relationships"] = {}
	for role in ["client", "client_b"]:
		var peer := int(_read(role + ".admitted").get("peer_id", 0))
		(snapshot.consumed_relationships as Dictionary)[role] = str(_game.network_session.get_moving_interior_latest_relationship(
			GameFlow.network_client_boarding_avatar_id(peer)))
	if _role == "host":
		snapshot["occupancies"] = _game.network_session.get_boarding_snapshot().get("occupancies", [])
		snapshot["remote_bodies"] = []
		var simulation := _game.get_network_remote_body_simulation()
		if simulation == null:
			snapshot["missing_remote_simulation"] = true
			return snapshot
		for role in ["client", "client_b"]:
			var peer := int(_read(role + ".admitted").get("peer_id", 0))
			var avatar := GameFlow.network_client_boarding_avatar_id(peer)
			var body := simulation.get_body(avatar) as PlayerController
			var publication := _ordinary_publication(avatar)
			(snapshot.remote_bodies as Array).append({"role": role, "peer": peer,
				"generation": _ordinary_peer_generation(peer), "body": _ordinary_node_identity(body),
				"record": str(simulation.get_body_record(avatar)), "position": str(body.global_position) if body != null else "",
				"seat": _ordinary_node_identity(body.get("_seat_anchor") as Node) if body != null else {},
				"occupant": _ordinary_node_identity(publication.get("occupant") as Node),
				"wire": str(publication.get("wire", {}))})
		var owner: CrewSeatRoleAuthority = _craft.get_crew_role_authority()
		snapshot["crew_assignments"] = owner.get_snapshot().get("assignments", []) if owner != null else []
	return snapshot


func _ordinary_producer_state(source: ShipCommandSource) -> Dictionary:
	if not is_instance_valid(source):
		return {"present": false}
	return {"present": true, "identity": _ordinary_node_identity(source), "enabled": source.enabled,
		"enabled_owner": source.is_enabled_owner(), "authority_peer_id": source.get_authority_peer_id(),
		"local_peer_id": source.get_local_peer_id()}
