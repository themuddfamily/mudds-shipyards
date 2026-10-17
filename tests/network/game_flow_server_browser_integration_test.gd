extends SceneTree

## D3 independent Main/menu admission release check (default fixture unchanged).
## Exact invocation, after committing this mode and copying the prepared private donor cache:
## install -d -m 700 /srv/mudds-work/live-menu-coordinator-profile-20261017/{data,config,cache,state,runtime,tmp,data-dirs,config-dirs}
## live_menu_context=(); for live_menu_key in HOME CODEX_HOME GODOT_SILENCE_ROOT_WARNING; do if [[ -v "$live_menu_key" ]]; then live_menu_context+=("$live_menu_key=${!live_menu_key}"); fi; done
## env -i "${live_menu_context[@]}" PATH=/usr/local/bin:/usr/bin:/bin XDG_DATA_HOME=/srv/mudds-work/live-menu-coordinator-profile-20261017/data XDG_CONFIG_HOME=/srv/mudds-work/live-menu-coordinator-profile-20261017/config XDG_CACHE_HOME=/srv/mudds-work/live-menu-coordinator-profile-20261017/cache XDG_STATE_HOME=/srv/mudds-work/live-menu-coordinator-profile-20261017/state XDG_RUNTIME_DIR=/srv/mudds-work/live-menu-coordinator-profile-20261017/runtime XDG_DATA_DIRS=/srv/mudds-work/live-menu-coordinator-profile-20261017/data-dirs XDG_CONFIG_DIRS=/srv/mudds-work/live-menu-coordinator-profile-20261017/config-dirs TMPDIR=/srv/mudds-work/live-menu-coordinator-profile-20261017/tmp timeout --signal=TERM --kill-after=10s 300s /tmp/mudds-tools/godot-4.7.1/godot --headless --audio-driver Dummy --path /srv/mudds-work/live-menu-admission-20261017 --script res://tests/network/game_flow_server_browser_integration_test.gd -- --live-menu-one-guest --live-results /srv/mudds-work/live-menu-admission-results-20261017/peers
## The headless coordinator owns two xvfb-run x11/dummy-renderer Main peers.
## Each peer has private 0700 XDG homes, search directories and TMPDIR. No rendered pixels
## are read. Staging sets actual LineEdit text and focuses actual visible Buttons;
## ui_accept input activates their production handlers, including the LAN row.
## After admission each player uses Back → Begin Shift, dismisses any visible
## tutorial card, then uses the visible runtime Disconnect action. Menu usability
## after shift uses pause input → Server Browser → Back → Resume.
## Limits: outer 300s; each cold Main 60s; UI availability 5s and activation 5s; host UI/responder
## 10s; discovery 10s; authenticated admission 20s; after guest cold startup host
## observes join within 50s, leave within 20s; each receipt handoff 20s; guest
## completion 100s, host completion 30s; normal exit 10s, forced reap 10s and
## wrapper/display exit 10s per peer. Coordinator stages share a 230s deadline
## reserving 60s for two-peer cleanup within the unchanged outer 300s cap.
## First failed boundary ends the route; no automatic retry or D4 second guest.


const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SessionType := preload("res://scripts/network/network_enet_session_adapter.gd")

class HudProbe extends CanvasLayer:
	var browser_results: Array[Dictionary] = []
	var network_results: Array[Dictionary] = []

	func apply_server_browser_result(result: Dictionary) -> void:
		browser_results.append(result.duplicate(true))

	func update_network_session_status(snapshot: Dictionary) -> void:
		network_results.append(snapshot.duplicate(true))


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--live-menu-one-guest" in OS.get_cmdline_user_args():
		await _live_run()
		return
	var flow := GameFlowType.new()
	var hud := HudProbe.new()
	flow.hud = hud
	var session := SessionType.new()
	root.add_child(session)
	flow.network_session = session
	flow._connect_signal_once(session, &"server_browser_result", flow._on_server_browser_result)
	var applied: Dictionary = session.apply_server_directory_snapshot(4, 12, [{
		"session_id": &"open_run",
		"host_peer_id": 7,
		"title": "Open Run",
		"region_id": &"eu-west",
		"ping_ms": 42,
		"player_count": 1,
		"max_players": 4,
	}])
	_check(bool(applied.get("accepted", false)), "adapter accepts detached discovery snapshot")
	_check(hud.browser_results.size() == 1 and hud.browser_results[0].rows.size() == 1
		and hud.browser_results[0].directory_generation == 4
		and hud.browser_results[0].server_tick == 12
		and hud.browser_results[0].snapshot_sequence > 0,
		"GameFlow forwards adapter listings with the complete production directory cursor")
	flow._on_hud_presentation_intent_requested(&"server_browser", {
		"action": &"refresh",
		"request": {"request_generation": 9},
	})
	_check(hud.browser_results.size() == 2 and hud.browser_results.back().rows.size() == 1
		and hud.browser_results.back().request_generation == 9,
		"refresh reads the current detached listings and echoes the HUD request fence")
	var expired := session.expire_server_directory(43)
	_check(expired.accepted and hud.browser_results.size() == 3
		and hud.browser_results.back().rows.is_empty()
		and hud.browser_results.back().directory_generation == 4
		and hud.browser_results.back().snapshot_sequence > hud.browser_results[0].snapshot_sequence,
		"clock expiry reaches the HUD with empty rows and a complete advanced cursor")
	_check(session.apply_server_directory_snapshot(5, 43, [{
		"session_id": &"open_run",
		"host_peer_id": 7,
		"title": "Open Run",
		"region_id": &"eu-west",
		"ping_ms": 42,
		"player_count": 1,
		"max_players": 4,
	}]).accepted, "a fresh directory publication restores the join fixture after expiry")
	flow._on_hud_presentation_intent_requested(&"server_browser", {"action": &"join", "session_id": &"open_run"})
	_check(hud.network_results.size() == 1 and hud.network_results.back().state == &"connecting", "join intent uses the adapter's validated join path")
	_check(bool(session.get("_configured")), "validated join starts through ENet adapter")
	session.shutdown(&"test_cleanup")
	session.queue_free()
	flow.free()
	hud.free()
	if _failures.is_empty():
		print("GAME_FLOW_SERVER_BROWSER_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


# Owned-process mechanics follow halyard_network_passenger_route_test.gd.
var _live_directory := ""
var _live_role := "coordinator"
var _live_port := 0
var _live_game: GameFlow
var _live_peers: Dictionary = {}
var _live_deadline := 0


func _live_run() -> void:
	var args := OS.get_cmdline_user_args()
	var peer_index := args.find("--live-peer")
	if peer_index >= 0 and peer_index + 3 < args.size():
		_live_role = args[peer_index + 1]
		_live_directory = args[peer_index + 2]
		_live_port = int(args[peer_index + 3])
		await _live_actor()
		return
	_live_deadline = Time.get_ticks_msec() + 230_000 # Reserve two-peer exit/reap/display cleanup margin.
	var result_index := args.find("--live-results")
	_live_directory = args[result_index + 1] if result_index >= 0 and result_index + 1 < args.size() else "/tmp/mudds-live-menu-%d" % OS.get_process_id()
	# Refuse stale receipts rather than accepting another run's host identity.
	if DirAccess.dir_exists_absolute(_live_directory):
		_check(false, "live result directory must be fresh: " + _live_directory)
		_live_finish()
		return
	DirAccess.make_dir_recursive_absolute(_live_directory)
	_live_port = 26000 + OS.get_process_id() % 15000
	_live_peers.host = _live_spawn("host")
	_check(int(_live_peers.host) > 0, "independent Main host wrapper starts")
	var reached := int(_live_peers.host) > 0 and await _live_wait_file("host.main_ready", 60.0)
	if reached:
		reached = await _live_wait_file("host.ready", 15.0)
	if reached:
		_live_peers.guest = _live_spawn("guest")
		_check(int(_live_peers.guest) > 0, "independent Main guest wrapper starts")
		reached = int(_live_peers.guest) > 0 and await _live_wait_file("guest.main_ready", 60.0)
	if reached:
		reached = await _live_wait_file("guest.done", 100.0)
	if reached:
		reached = await _live_wait_file("host.done", 30.0)
	if not reached:
		_live_write("abort", {"reason": "first_failed_boundary"})
	for role: String in _live_peers:
		var done := _live_read(role + ".done")
		_check(not done.is_empty() and (done.get("failures", []) as Array).is_empty(), role + " ordinary live menu route passes")
		_assertions += int(done.get("assertions", 0))
		if not await _live_until(func(): return FileAccess.file_exists(_live_directory.path_join(role + ".exit")), 10.0, false):
			_live_kill_actor(role)
			await _live_until(func(): return FileAccess.file_exists(_live_directory.path_join(role + ".exit")), 10.0, false)
		_check(FileAccess.get_file_as_string(_live_directory.path_join(role + ".exit")).strip_edges() == "0", role + " actual Godot OS exit is zero")
		var child := _live_actor_pid(role)
		_check(child > 0 and not DirAccess.dir_exists_absolute("/proc/%d" % child), role + " actor has been reaped")
		# xvfb-run owns its server until the waiting shell exits.
		var wrapper := int(_live_peers[role])
		var wrapper_gone := await _live_until(func(): return wrapper <= 0 or not OS.is_process_running(wrapper), 10.0, false)
		_check(wrapper_gone, role + " xvfb-run wrapper and owned display close")
		if not wrapper_gone and wrapper > 0:
			OS.kill(wrapper)
	if _failures.is_empty():
		var host := _live_read("host.admitted")
		var guest := _live_read("guest.admitted")
		_check(int(host.get("pid", 0)) != int(guest.get("pid", 0)), "host and guest are distinct actual Main processes")
		_check(int(host.get("guest_peer_id", 0)) == int(guest.get("peer_id", -1)) and int(host.get("guest_generation", 0)) == int(guest.get("peer_generation", -1)), "host and guest agree on authenticated peer identity and generation")
		_check(host.get("player", {}) != guest.get("player", {}) and int(host.get("host_peer_id", 0)) == 1 and int(guest.get("peer_id", 0)) > 1, "independent actual Main players accompany distinct authenticated network peer identities")
		_check((_live_read("host.done").get("guest_counts", []) as Array) == [0, 1, 0], "real host guest counts reconcile 0 → 1 → 0")
	_live_finish()


func _live_spawn(role: String) -> int:
	var profile := _live_directory.path_join(role + "-profile")
	for folder in ["data", "config", "cache", "state", "runtime", "tmp", "data-dirs", "config-dirs"]:
		DirAccess.make_dir_recursive_absolute(profile.path_join(folder))
		_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile.path_join(folder)])) == 0, "private profile directory permissions: " + folder)
	_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile])) == 0, "private peer profile root permissions")
	var args := PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/network/game_flow_server_browser_integration_test.gd", "--", "--live-menu-one-guest", "--live-peer", role, _live_directory, str(_live_port)])
	# Positional argv protects path text from shell evaluation. The shell waits
	# for the actual Godot child; a .done receipt is never treated as OS exit.
	var command := 'trap \'kill "$child" 2>/dev/null; wait "$child"; exit 143\' TERM INT HUP; /usr/bin/env -i DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" "$@" > "$0.log" 2>&1 & child=$!; printf "%s" "$child" > "$0.pid"; wait "$child"; status=$?; printf "%s" "$status" > "$0.exit"; exit "$status"'
	var wrapper := PackedStringArray(["-a", "--server-args=-screen 0 1280x720x24 -nolisten unix -nolisten tcp", "/bin/sh", "-c", command, _live_directory.path_join(role), "/usr/bin/env", "PATH=/usr/local/bin:/usr/bin:/bin", "XDG_DATA_HOME=" + profile.path_join("data"), "XDG_CONFIG_HOME=" + profile.path_join("config"), "XDG_CACHE_HOME=" + profile.path_join("cache"), "XDG_RUNTIME_DIR=" + profile.path_join("runtime"), "XDG_STATE_HOME=" + profile.path_join("state"), "XDG_DATA_DIRS=" + profile.path_join("data-dirs"), "XDG_CONFIG_DIRS=" + profile.path_join("config-dirs"), "TMPDIR=" + profile.path_join("tmp")])
	# Preserve the invoking root context exactly, including an absent variable.
	for key in ["HOME", "CODEX_HOME", "GODOT_SILENCE_ROOT_WARNING"]:
		if OS.has_environment(key):
			wrapper.append(key + "=" + OS.get_environment(key))
	wrapper.append(OS.get_executable_path())
	wrapper.append_array(args)
	print("LIVE_MENU_PEER_LAUNCH: ", role, " ", args)
	return OS.create_process("xvfb-run", wrapper)


func _live_actor() -> void:
	_live_write(_live_role + ".script_ready", {"pid": OS.get_process_id(), "display": OS.get_environment("DISPLAY"), "xdg_data": OS.get_environment("XDG_DATA_HOME"), "xdg_config": OS.get_environment("XDG_CONFIG_HOME"), "xdg_cache": OS.get_environment("XDG_CACHE_HOME"), "xdg_runtime": OS.get_environment("XDG_RUNTIME_DIR"), "xdg_state": OS.get_environment("XDG_STATE_HOME"), "xdg_data_dirs": OS.get_environment("XDG_DATA_DIRS"), "xdg_config_dirs": OS.get_environment("XDG_CONFIG_DIRS"), "tmpdir": OS.get_environment("TMPDIR"), "wayland_display": OS.get_environment("WAYLAND_DISPLAY"), "wayland_socket": OS.get_environment("WAYLAND_SOCKET")})
	var main: PackedScene = load("res://scenes/main.tscn")
	_live_game = main.instantiate() as GameFlow
	root.add_child(_live_game)
	await process_frame
	await process_frame
	_live_write(_live_role + ".main_ready", {"pid": OS.get_process_id()})
	_check(_live_game.hud is GameHUD and _live_game.get_node_or_null("Player") is PlayerController, "actual Main owns real HUD and player")
	if _failures.is_empty():
		if _live_role == "host":
			await _live_host()
		else:
			await _live_guest()
	# Cleanup is independent of menu success, focus, pause state or input capture.
	var release := InputEventAction.new()
	release.action = &"ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	Input.action_release(&"ui_accept")
	_live_game.shutdown_network_session(&"live_menu_cleanup")
	_live_game.release_mouse_capture()
	_live_game.queue_free()
	await process_frame
	await process_frame
	var done := {"assertions": _assertions, "failures": Array(_failures), "pid": OS.get_process_id()}
	if _live_role == "host":
		done["guest_counts"] = _live_counts
	_live_write(_live_role + ".done", done)
	_live_finish()


var _live_counts: Array[int] = []


func _live_host() -> void:
	if not await _live_button("IntroServerBrowserButton"):
		return
	var port := _live_game.hud.get("_server_browser_port") as LineEdit
	port.text = str(_live_port)
	if not await _live_button("ServerBrowserHostButton"):
		return
	if not await _live_boundary(func(): return is_instance_valid(_live_game.network_session) and _live_game.network_session.is_server() and is_instance_valid(_live_game.get_lan_discovery()) and _live_game.get_lan_discovery().is_responding(), 10.0, "host UI starts real ENet and LAN responder"):
		return
	var session := _live_game.network_session
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_check(_live_counts == [0] and session.get_admitted_peer_ids().is_empty(), "hosting excludes own player from guest capacity")
	var discovery := _live_game.get_lan_discovery()
	_live_write("host.ready", {"pid": OS.get_process_id(), "session_id": str(discovery.get("_responder_session_id")), "port": session.get_local_port()})
	if not await _live_wait_file("guest.main_ready", 60.0):
		return
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().size() == 1, 50.0, "host observes one authenticated menu guest"):
		return
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	var guest_id := int(session.get_admitted_peer_ids()[0])
	var lifecycle := session.get_snapshot().get("lifecycle", {}) as Dictionary
	var peers := lifecycle.get("peers", []) as Array
	_check(peers.size() == 1 and int(peers[0].peer_id) == guest_id and int(peers[0].peer_generation) > 0, "host lifecycle contains authenticated guest only")
	_live_write("host.admitted", {"pid": OS.get_process_id(), "host_peer_id": session.multiplayer.get_unique_id(), "player": _live_player_identity(), "guest_peer_id": guest_id, "guest_generation": int(peers[0].peer_generation) if peers.size() == 1 else 0})
	if not await _live_wait_file("guest.admitted", 20.0):
		return
	if not await _live_begin_shift():
		return
	_live_write("host.allow_leave", {})
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().is_empty() and int(session.get_session_capacity_snapshot().occupancy) == 0, 20.0, "guest UI disconnect returns real host guest count to zero"):
		return
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_check(_live_guest_ownership_clear(session, guest_id), "host releases guest admissions, seat/ship/crew ownership and remote body")
	if not await _live_pause_browser():
		return
	_live_write("host.cleared", {})
	if not await _live_button("RuntimeStatusDisconnectButton"):
		return
	_check(not session.is_session_active() and not discovery.is_responding(), "host UI disconnect closes session and LAN responder")


func _live_guest() -> void:
	if not await _live_button("IntroServerBrowserButton") or not await _live_button("ServerBrowserRefreshButton"):
		return
	var hosted := _live_read("host.ready")
	var session_id := StringName(str(hosted.get("session_id", "")))
	if not await _live_boundary(func(): return _live_row(session_id) != null, 10.0, "refresh receives the actual host's LAN-advertised session row"):
		return
	var discovery := _live_game.get_lan_discovery()
	var endpoint := discovery.get_endpoint(session_id)
	_check(not session_id.is_empty() and int(endpoint.get("port", 0)) == int(hosted.get("port", -1)) and not str(endpoint.get("address", "")).is_empty(), "selected LAN row resolves the owned live host endpoint")
	_live_write("guest.discovered", {"session_id": str(session_id), "endpoint": endpoint})
	if not _failures.is_empty() or not await _live_activate(_live_row(session_id)):
		return
	if not await _live_boundary(_live_authenticated, 20.0, "selected real HUD row joins and authenticates guest"):
		return
	var session := _live_game.network_session
	var peer := (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	var guest_id := session.multiplayer.get_unique_id()
	_live_write("guest.admitted", {"pid": OS.get_process_id(), "peer_id": guest_id, "peer_generation": int(peer.get("peer_generation", 0)), "player": _live_player_identity()})
	if not await _live_wait_file("host.allow_leave", 20.0):
		return
	if not await _live_begin_shift() or not await _live_button("RuntimeStatusDisconnectButton"):
		return
	_check(not session.is_session_active() and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty(), "guest UI disconnect clears transport and admission")
	_check(_live_game.get_network_remote_body_intent_source() == null and not (_live_game.get_node("Player") as PlayerController).is_seated(), "menu guest has no retained body or chair ownership")
	if not await _live_pause_browser():
		return
	await _live_wait_file("host.cleared", 20.0)


func _live_begin_shift() -> bool:
	if not await _live_button("ServerBrowserBackButton") or not await _live_button("IntroBeginShiftButton"):
		return false
	if not await _live_boundary(func(): return _live_game.phase != GameFlow.Phase.INTRO, 5.0, "ordinary Begin Shift exposes playable Main and runtime controls"):
		return false
	var dismiss := _live_game.hud.find_child("RuntimeStatusDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree() and not dismiss.disabled:
		if not await _live_activate(dismiss):
			return false
	return true


func _live_pause_browser() -> bool:
	var pressed := InputEventAction.new()
	pressed.action = &"pause"
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventAction.new()
	released.action = &"pause"
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame
	return await _live_button("ServerBrowserButton") and await _live_button("ServerBrowserBackButton") and await _live_button("ResumeButton")


func _live_player_identity() -> Dictionary:
	var player := _live_game.get_node("Player") as PlayerController
	return {"pid": OS.get_process_id(), "object_id": str(player.get_instance_id()), "path": str(player.get_path())}


func _live_authenticated() -> bool:
	var session := _live_game.network_session
	if not is_instance_valid(session) or not session.is_session_active():
		return false
	var offer := session.get_server_offer()
	var admission := offer.get("admission", {}) as Dictionary
	var peer := admission.get("peer", {}) as Dictionary
	var transport := offer.get("transport", {}) as Dictionary
	var epoch := (offer.get("migration", {}) as Dictionary).get("epoch", {}) as Dictionary
	var current := session.get_migration_snapshot()
	var identity := session.multiplayer.get_unique_id()
	if not bool(admission.get("accepted", false)) or identity <= 1 or int(peer.get("peer_id", 0)) != identity or int(peer.get("peer_generation", 0)) <= 0 or int(transport.get("peer_id", 0)) != identity or int(transport.get("peer_generation", 0)) != int(peer.get("peer_generation", 0)) or str(transport.get("auth_token", "")).is_empty():
		return false
	for key in ["package_generation", "session_generation", "migration_generation"]:
		if int(epoch.get(key, 0)) <= 0 or epoch.get(key) != current.get(key):
			return false
	return true


func _live_guest_ownership_clear(session: NetworkEnetSessionAdapter, guest_id: int) -> bool:
	var lifecycle := session.get_snapshot().get("lifecycle", {}) as Dictionary
	for peer: Dictionary in lifecycle.get("peers", []):
		if int(peer.get("peer_id", 0)) == guest_id:
			return false
	for ship: Dictionary in (session.get("_ship_ownership").get_snapshot() as Dictionary).get("ships", []):
		if int(ship.get("owner_peer_id", 0)) == guest_id:
			return false
	for assignment: Dictionary in (session.get("_seat_authority").get_snapshot() as Dictionary).get("assignments", []):
		if int(assignment.get("occupant_peer_id", 0)) == guest_id:
			return false
	for assignment: Dictionary in (session.get_crew_role_snapshot().get("roles", {}) as Dictionary).values():
		if int(assignment.get("peer_id", 0)) == guest_id:
			return false
	for occupancy: Dictionary in session.get_boarding_snapshot().get("occupancies", []):
		if int(occupancy.get("peer_id", 0)) == guest_id:
			return false
	return int(session.get_crew_role_snapshot().get("admitted_peer_count", -1)) == 0 and _live_game._network_remote_body_simulation.get_body_count() == 0


func _live_row(session_id: StringName) -> Button:
	var rows := _live_game.hud.get("_server_browser_rows") as VBoxContainer
	for child in rows.get_children():
		if child is Button and StringName(child.get_meta(&"session_id", &"")) == session_id:
			return child as Button
	return null


func _live_button(node_name: String) -> bool:
	if not await _live_boundary(func():
		var candidate := _live_game.hud.find_child(node_name, true, false) as Button
		return candidate != null and candidate.is_visible_in_tree() and not candidate.disabled,
		5.0, "visible enabled HUD action: " + node_name):
		return false
	return await _live_activate(_live_game.hud.find_child(node_name, true, false) as Button)


func _live_activate(button: Button) -> bool:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		_check(false, "actual visible enabled HUD button is available")
		return false
	root.grab_focus()
	button.grab_focus()
	await process_frame
	if root.gui_get_focus_owner() != button:
		_check(false, "actual HUD button receives keyboard/controller focus")
		return false
	var activated := [false]
	button.pressed.connect(func(): activated[0] = true, CONNECT_ONE_SHOT)
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var released := InputEventAction.new()
	released.action = &"ui_accept"
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame
	return await _live_boundary(func(): return activated[0], 5.0, "focused ui_accept activates actual HUD Button")


func _live_boundary(predicate: Callable, seconds: float, description: String) -> bool:
	var reached := await _live_until(predicate, seconds)
	_check(reached, description)
	if not reached:
		_live_write(_live_role + ".failed_boundary", {"description": description})
	return reached


func _live_until(predicate: Callable, seconds: float, abortable: bool = true) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		if abortable and FileAccess.file_exists(_live_directory.path_join("abort")):
			return false
		if abortable and _live_role == "coordinator" and _live_deadline > 0 and Time.get_ticks_msec() >= _live_deadline:
			return false
		await process_frame
	return false


func _live_wait_file(name: String, seconds: float) -> bool:
	var reached := await _live_until(func():
		if FileAccess.file_exists(_live_directory.path_join(name)):
			return true
		# A finished peer cannot reach a later gameplay boundary.
		for role in ["host", "guest"]:
			if name.begins_with(role + ".") and name != role + ".done" and FileAccess.file_exists(_live_directory.path_join(role + ".done")):
				return true
		return false, seconds)
	reached = reached and FileAccess.file_exists(_live_directory.path_join(name))
	_check(reached, "live peer boundary: " + name)
	return reached


func _live_write(name: String, data: Dictionary) -> void:
	var target := _live_directory.path_join(name)
	var temporary := target + ".tmp-%d" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_check(false, "peer receipt opens: " + name)
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	_check(error == OK and DirAccess.rename_absolute(temporary, target) == OK, "atomic peer receipt publishes: " + name)
	print("LIVE_MENU_BOUNDARY: ", _live_role, " ", name, " wall=", Time.get_unix_time_from_system())


func _live_read(name: String) -> Dictionary:
	if not FileAccess.file_exists(_live_directory.path_join(name)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_live_directory.path_join(name)))
	return parsed if parsed is Dictionary else {}


func _live_actor_pid(role: String) -> int:
	var path := _live_directory.path_join(role + ".pid")
	return int(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else 0


func _live_kill_actor(role: String) -> void:
	var pid := _live_actor_pid(role)
	if pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid):
		OS.kill(pid) # The owning shell remains alive to wait/reap and receipt.


func _live_finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("LIVE_MENU_ARTIFACTS: ", _live_directory)
	print("GAME_FLOW_LIVE_MENU_ONE_GUEST: %d assertions, %d failures" % [_assertions, _failures.size()])
	if _failures.is_empty() and _live_role == "coordinator":
		print("GAME_FLOW_LIVE_MENU_ONE_GUEST_TEST_OK")
	quit(0 if _failures.is_empty() else 1)
