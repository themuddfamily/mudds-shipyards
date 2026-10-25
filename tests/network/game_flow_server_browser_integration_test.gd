extends SceneTree

## D3 independent Main/menu admission release check (default fixture unchanged).
## Exact invocation, after committing this mode and copying the prepared private donor cache:
## install -d -m 700 /srv/mudds-work/browser-disconnect-coordinator-profile-20261017/{data,config,cache,state,runtime,tmp,data-dirs,config-dirs}
## live_menu_context=(); for live_menu_key in HOME CODEX_HOME GODOT_SILENCE_ROOT_WARNING; do if [[ -v "$live_menu_key" ]]; then live_menu_context+=("$live_menu_key=${!live_menu_key}"); fi; done
## env -i "${live_menu_context[@]}" PATH=/usr/local/bin:/usr/bin:/bin XDG_DATA_HOME=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/data XDG_CONFIG_HOME=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/config XDG_CACHE_HOME=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/cache XDG_STATE_HOME=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/state XDG_RUNTIME_DIR=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/runtime XDG_DATA_DIRS=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/data-dirs XDG_CONFIG_DIRS=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/config-dirs TMPDIR=/srv/mudds-work/browser-disconnect-coordinator-profile-20261017/tmp timeout --signal=TERM --kill-after=10s 300s /tmp/mudds-tools/godot-4.7.1/godot --headless --audio-driver Dummy --path /srv/mudds-work/browser-disconnect-fix-20261017 --script res://tests/network/game_flow_server_browser_integration_test.gd -- --live-menu-one-guest --live-results /srv/mudds-work/browser-disconnect-fix-results-20261017/peers
## The headless coordinator owns two xvfb-run x11/dummy-renderer Main peers.
## Each peer has private 0700 XDG homes, search directories and TMPDIR. No rendered pixels
## are read. Staging sets actual LineEdit text and focuses actual visible Buttons;
## ui_accept input activates their production handlers, including the LAN row.
## After admission each player uses Back → Begin Shift, dismisses any visible
## tutorial card, then uses pause → Server Browser → Disconnect. After leaving,
## the still-open browser supports Refresh → Back → Resume.
## Limits: outer 300s; each cold Main 60s; UI availability 5s and activation 5s; host UI/responder
## 10s; discovery 10s; authenticated admission 20s; after guest cold startup host
## observes join within 50s, leave within 20s; each receipt handoff 20s; guest
## completion 100s, host completion 30s; normal exit 10s, forced reap 10s and
## wrapper/display exit 10s per peer. Coordinator stages share a 230s deadline
## reserving 60s for two-peer cleanup within the unchanged outer 300s cap.
## First failed boundary ends the route; no automatic retry.
## D4 exact invocation (same environment isolation and external ordered network/display locks):
## install -d -m 700 /srv/mudds-work/two-guest-menu-coordinator-profile-20261017/{data,config,cache,state,runtime,tmp,data-dirs,config-dirs}
## live_menu_context=(); for live_menu_key in HOME CODEX_HOME GODOT_SILENCE_ROOT_WARNING; do if [[ -v "$live_menu_key" ]]; then live_menu_context+=("$live_menu_key=${!live_menu_key}"); fi; done
## env -i "${live_menu_context[@]}" PATH=/usr/local/bin:/usr/bin:/bin XDG_DATA_HOME=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/data XDG_CONFIG_HOME=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/config XDG_CACHE_HOME=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/cache XDG_STATE_HOME=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/state XDG_RUNTIME_DIR=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/runtime XDG_DATA_DIRS=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/data-dirs XDG_CONFIG_DIRS=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/config-dirs TMPDIR=/srv/mudds-work/two-guest-menu-coordinator-profile-20261017/tmp timeout --signal=TERM --kill-after=10s 300s /tmp/mudds-tools/godot-4.7.1/godot --headless --audio-driver Dummy --path /srv/mudds-work/two-guest-menu-20261017 --script res://tests/network/game_flow_server_browser_integration_test.gd -- --live-menu-two-guests --live-results /srv/mudds-work/two-guest-menu-results-20261017/two-guest-peers
## D4 preserves the outer300s and all D3 boundaries above. Its coordinator uses
## a 200s shared work deadline, reserving90s for three peers' exit/reap/display closure.
## Stage: host.ready → guest.main_ready → host.admitted + guest.admitted →
## guest2.main_ready (separate60s cold-Main boundary for host and waiting guest) →
## host.guest2_admitted + guest2.admitted → host.allow_leave → host.first_cleared →
## guest2.remaining → host.allow_second_leave → host.cleared. Each receipt20s;
## host admission50s (also coordinator first-admission observation) and departure20s,
## unchanged. Guest2 completion100s;
## after it finishes, guest completion20s then host completion30s. No wider D3 timeout.


## BROWSER-CANCEL mode uses the same isolated invocation and suite_process.py
## --timeout 300 ownership as D3, replacing its mode with --live-menu-cancel.
## One private Xvfb/x11/Dummy Main actor uses ordinary ui_accept for Manual Join
## and Cancel Connection twice. The coordinator holds a loopback UDP socket open
## without replying to ENet handshakes. Original Main60s/UI5s/actor100s/cleanup10s
## limits and coordinator230s work deadline remain; no external host is needed.
## Success: GAME_FLOW_LIVE_MENU_CANCEL_TEST_OK, cancel.reusable attempts=2 and
## cancelled=2, plus zero actual actor exit and reaped actor/wrapper/display.
## BROWSER-JOIN gameplay: use the D3 invocation/environment/locks above with
## --live-menu-one-guest-gameplay. Both real Main players walk >=1m forward
## while admitted, then >=1m back after normal Disconnect/Refresh/Back/Resume.
## Each walk uses production movement actions, <=5s walking/settling boundaries,
## and 12 neutral physics ticks with <=.02m drift. All original D3 caps remain.
## BROWSER-FULL: same isolated invocation/locks with --live-menu-full. Three
## actual Main peers use a deliberately configured one-guest host (not a release
## capacity claim). Only after matching host/occupant admissions does candidate
## cold-start, discover the actual full LAN row, attempt an ordinary pointer
## selection, Refresh, Back, Begin Shift and walk the same supported Player.
## Full rows are disabled by production UI; refusal must produce no join intent
## or transport, while full feedback and Refresh remain usable. Host/occupant
## identities are sampled continuously until candidate completes continuation.
## Original outer300s and D4 work200s/cleanup90s apply, as do Main60s, UI5s,
## discovery10s, admission20s, handoff20s, candidate100s, guest20s/host30s and
## per-peer exit/reap/display10s. First failed boundary aborts, without retry.
## Success: GAME_FLOW_LIVE_MENU_FULL_TEST_OK and all three actual OS exits0.
## Success: GAME_FLOW_LIVE_MENU_ONE_GUEST_GAMEPLAY_TEST_OK; existing .done
## receipts contain both actual walks, and actual actor OS exits must be zero.
## BROWSER-DISCONNECT: --live-menu-disconnect-rejoin keeps the original two-Main
## host available through guest ordinary Disconnect, retired transport/authority,
## same-Player solo walking, actual LAN Refresh/row selection and fresh admission.
## Immutable .admitted/.rejoined receipts match each host/guest identity tuple;
## both new connected walks use the second admission. Guest disconnects again,
## then host normally stops; both retain usable browser/solo return and OS exits0.
## Original D3 outer300s/work230s/Main60s/UI5s/discovery10s/admission20s/
## handoff20s/guest100s/host30s/cleanup10s and walk/settle5s/12neutral remain.


## BROWSER-CANCEL complete reuse: --live-menu-cancel-rejoin retains the two
## ordinary pending attempts against a separate coordinator-owned nonanswer UDP
## endpoint. The same guest Main/Player then discovers and joins the independent
## live Main host, followed by both connected/solo walks and normal leave/stop.
## Native CONNECTING/pending identity and complete Cancel retirement are observed;
## an always-physics guard retains closed old native peers and the original Player.
## Original D3 caps remain; success: GAME_FLOW_LIVE_MENU_CANCEL_REJOIN_TEST_OK.
##
## BROWSER-STALE: --live-menu-stale uses actual Begin Shift/Pause/Browser and
## real last-reply time (30 seconds) with the original D3 caps unchanged. The
## focused LAN row retires naturally while paused, leaving expired feedback and
## Retry focus, no join intent/native peer/admission. Ordinary Accept retries
## discovery; the fresh host row then admits both original Players to connected
## walking, normal Disconnect, supported solo return and both actual OS exits0.
## The observer never calls expire_stale/get_endpoint to drive the expiry.
##
## BROWSER-UNREACHABLE separate no-answer case: --live-menu-no-answer binds an
## owned silent loopback UDP endpoint before the guest starts. Same Main/Player
## joins it from Begin Shift/Pause/browser, naturally reaches the production
## five-second deadline while paused, then ordinary Retry starts a fresh native
## attempt and ordinary Cancel retires it before expiry. Refresh/LAN-row join
## reuses the actual independent Main host for connected/solo walks and OS exit0.
## Existing D3 deadlines remain unchanged; this does not replay or accept the
## parked e944f52 connected-but-nonadmitting packaged route.
## Success: GAME_FLOW_LIVE_MENU_NO_ANSWER_TEST_OK.


const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SessionType := preload("res://scripts/network/network_enet_session_adapter.gd")

class HudProbe extends CanvasLayer:
	var browser_results: Array[Dictionary] = []
	var network_results: Array[Dictionary] = []

	func apply_server_browser_result(result: Dictionary) -> void:
		browser_results.append(result.duplicate(true))

	func update_network_session_status(snapshot: Dictionary) -> void:
		network_results.append(snapshot.duplicate(true))


# A test-local consumer runs after Main (-100), Player (0) and ship camera (100).
# Production producers keep their authored order. Rendering may skip frames;
# this node still observes every completed physics step, including paused faults.
class LiveWalkSampler extends Node:
	var observe: Callable

	func _physics_process(_delta: float) -> void:
		observe.call()


var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if "--live-menu-one-guest" in OS.get_cmdline_user_args() or "--live-menu-one-guest-gameplay" in OS.get_cmdline_user_args() or "--live-menu-two-guests" in OS.get_cmdline_user_args() or "--live-menu-cancel" in OS.get_cmdline_user_args() or "--live-menu-full" in OS.get_cmdline_user_args() or "--live-menu-disconnect-rejoin" in OS.get_cmdline_user_args() or "--live-menu-stale" in OS.get_cmdline_user_args() or "--live-menu-cancel-rejoin" in OS.get_cmdline_user_args() or "--live-menu-no-answer" in OS.get_cmdline_user_args():
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
var _live_two_guests := false
var _live_cancel := false
var _live_cancel_rejoin := false
var _live_no_answer := false
var _live_cancelled_native_peers: Array[ENetMultiplayerPeer] = []
var _live_cancel_observation: Dictionary = {}
var _live_cancel_fresh_requested := false
var _live_full := false
var _live_full_guard: Dictionary = {}
var _live_full_sampler: LiveWalkSampler
var _live_full_observation: Dictionary = {}
var _live_gameplay := false
var _live_stale := false
var _live_stale_observation: Dictionary = {}
var _live_rejoin := false
var _live_rejoined := false
var _live_original_native_peer: ENetMultiplayerPeer
var _live_walks: Dictionary = {}
var _live_pending_endpoint: PacketPeerUDP


func _live_run() -> void:
	var args := OS.get_cmdline_user_args()
	_live_two_guests = "--live-menu-two-guests" in args
	_live_cancel = "--live-menu-cancel" in args
	_live_no_answer = "--live-menu-no-answer" in args
	_live_cancel_rejoin = "--live-menu-cancel-rejoin" in args or _live_no_answer
	_live_full = "--live-menu-full" in args
	_live_stale = "--live-menu-stale" in args
	_live_rejoin = "--live-menu-disconnect-rejoin" in args
	_live_gameplay = "--live-menu-one-guest-gameplay" in args or _live_rejoin or _live_stale or _live_cancel_rejoin
	var peer_index := args.find("--live-peer")
	if peer_index >= 0 and peer_index + 3 < args.size():
		_live_role = args[peer_index + 1]
		_live_directory = args[peer_index + 2]
		_live_port = int(args[peer_index + 3])
		await _live_actor()
		return
	_live_deadline = Time.get_ticks_msec() + (200_000 if _live_two_guests or _live_full else 230_000) # Reserve per-peer cleanup margin.
	var result_index := args.find("--live-results")
	_live_directory = args[result_index + 1] if result_index >= 0 and result_index + 1 < args.size() else "/tmp/mudds-live-menu-%d" % OS.get_process_id()
	# Refuse stale receipts rather than accepting another run's host identity.
	if DirAccess.dir_exists_absolute(_live_directory):
		_check(false, "live result directory must be fresh: " + _live_directory)
		_live_finish()
		return
	DirAccess.make_dir_recursive_absolute(_live_directory)
	var reached := false
	if _live_cancel:
		reached = await _live_cancel_coordinator()
	else:
		if _live_cancel_rejoin:
			_live_pending_endpoint = PacketPeerUDP.new()
			var pending_error := _live_pending_endpoint.bind(0, "127.0.0.1")
			_check(pending_error == OK, "coordinator owns separate non-admitting cancellation endpoint")
			if pending_error != OK:
				_live_finish()
				return
			_live_write("cancel_endpoint.ready", {"pid": OS.get_process_id(), "port": _live_pending_endpoint.get_local_port()})
		_live_port = 26000 + OS.get_process_id() % 15000
		_live_peers.host = _live_spawn("host")
		_check(int(_live_peers.host) > 0, "independent Main host wrapper starts")
		reached = int(_live_peers.host) > 0 and await _live_wait_file("host.main_ready", 60.0)
		if reached:
			reached = await _live_wait_file("host.ready", 15.0)
		if reached:
			_live_peers.guest = _live_spawn("guest")
			_check(int(_live_peers.guest) > 0, "independent Main guest wrapper starts")
			reached = int(_live_peers.guest) > 0 and await _live_wait_file("guest.main_ready", 60.0)
		if reached and (_live_two_guests or _live_full):
			reached = await _live_boundary(func(): return FileAccess.file_exists(_live_directory.path_join("host.admitted")) and FileAccess.file_exists(_live_directory.path_join("guest.admitted")), 50.0, "first guest admission is acknowledged by both independent peers before guest2 starts")
			if reached and _live_full:
				var hosted := _live_read("host.admitted")
				var occupied := _live_read("guest.admitted")
				reached = int(hosted.get("guest_peer_id", 0)) > 1 and int(hosted.get("guest_peer_id", 0)) == int(occupied.get("peer_id", -1)) and int(hosted.get("guest_generation", 0)) > 0 and int(hosted.get("guest_generation", 0)) == int(occupied.get("peer_generation", -1))
				_check(reached, "matching actual host/occupant peer and generation precede candidate cold startup")
			if reached:
				var third := "candidate" if _live_full else "guest2"
				_live_peers[third] = _live_spawn(third)
				_check(int(_live_peers[third]) > 0, "third independent Main wrapper starts after first admission")
				reached = int(_live_peers[third]) > 0 and await _live_wait_file(third + ".main_ready", 60.0)
			if reached:
				reached = await _live_wait_file(("candidate" if _live_full else "guest2") + ".done", 100.0)
		if reached:
			reached = await _live_wait_file("guest.done", 20.0 if _live_two_guests or _live_full else 100.0)
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
	if _failures.is_empty() and not _live_cancel:
		var host := _live_read("host.admitted")
		var guest := _live_read("guest.admitted")
		_check(int(host.get("pid", 0)) != int(guest.get("pid", 0)), "host and guest are distinct actual Main processes")
		_check(int(host.get("guest_peer_id", 0)) == int(guest.get("peer_id", -1)) and int(host.get("guest_generation", 0)) == int(guest.get("peer_generation", -1)), "host and guest agree on authenticated peer identity and generation")
		_check(host.get("player", {}) != guest.get("player", {}) and int(host.get("host_peer_id", 0)) == 1 and int(guest.get("peer_id", 0)) > 1, "independent actual Main players accompany distinct authenticated network peer identities")
		var counts := _live_read("host.done").get("guest_counts", []) as Array
		if _live_two_guests:
			_live_check_two_guest_receipts(host, guest, counts)
		elif _live_rejoin:
			_check(counts.size() == 5 and counts[0] == 0 and counts[1] == 1 and counts[2] == 0 and counts[3] == 1 and counts[4] == 0, "real host guest counts reconcile both ordinary joins and disconnects 0 → 1 → 0 → 1 → 0")
			_live_check_gameplay_receipts()
			_live_check_rejoin_receipts(host, guest)
		else:
			_check(counts.size() == 3 and counts[0] == 0 and counts[1] == 1 and counts[2] == 0,
				"real host guest counts reconcile 0 → 1 → 0")
			if _live_gameplay:
				_live_check_gameplay_receipts()
			if _live_full:
				_live_check_full_receipts(host, guest)
			if _live_stale:
				_live_check_stale_receipts(host, guest)
	if _live_cancel_rejoin and _live_pending_endpoint != null:
		_check(_live_pending_endpoint.get_available_packet_count() > 0, "owned cancellation endpoint received actual ENet handshake datagrams")
		var cancelled := _live_read("guest.done").get("no_answer" if _live_no_answer else "cancel_rejoin", {}) as Dictionary
		_check(cancelled.get("player", {}) == _live_read("guest.admitted").get("player", {}), "successful join and walks retain the original cancellation Player")
		_check((cancelled.get("retired", []) as Array).size() == 2 and bool(cancelled.get("guard", {}).get("valid", false)) and int(cancelled.get("guard", {}).get("samples", 0)) > 0 and int(cancelled.get("fresh_admissions", 0)) == 1, "both retired pending peers stay closed through one fresh successful admission and ordinary leave")
		_check(not str(cancelled.get("fresh_native_id", "")).is_empty() and str(cancelled.get("fresh_native_id", "")) not in cancelled.get("old_native_ids", []), "fresh successful join uses a different native peer from both retired pending requests")
		if _live_no_answer:
			var first: Dictionary = cancelled.get("first_pending", {})
			var retry: Dictionary = cancelled.get("retry_pending", {})
			var terminal: Dictionary = cancelled.get("timeout", {})
			var stops: Array = cancelled.get("stops", [])
			_check(bool(first.get("valid", false)) and bool(retry.get("valid", false)) and first.get("native_id", "") != retry.get("native_id", "") and int(retry.get("deadline_milliseconds", 0)) > int(first.get("deadline_milliseconds", 0)), "no-answer receipts retain two distinct real pending attempts and increasing production deadlines")
			_check(stops.size() >= 2 and str(stops[0].get("reason", "")) == "connection_timeout" and int(stops[0].get("at_milliseconds", 0)) >= int(first.get("deadline_milliseconds", 1)) and str(stops[1].get("reason", "")) == "ui_cancel" and int(stops[1].get("at_milliseconds", 0)) < int(retry.get("deadline_milliseconds", 0)), "no-answer immutable result distinguishes actual natural timeout from prompt retry cancellation")
			_check(_live_browser_retry_ready(terminal, 0) and bool(terminal.get("copy_visible", false)) and str(terminal.get("copy", "")).begins_with("The session host did not admit the connection in time."), "no-answer result retains the actual timeout copy and natural-stop current Retry fence")
	if _live_pending_endpoint != null:
		_live_pending_endpoint.close()
	_live_finish()


# Passive checks never grant identity, change the advertised capacity or invoke
# a join handler. Their independent physics consumer survives paused menus.
func _live_start_full_guard(predicate: Callable, description: String) -> void:
	_live_full_guard = {"active": true, "valid": true, "samples": 0}
	_live_full_sampler = LiveWalkSampler.new()
	_live_full_sampler.process_mode = Node.PROCESS_MODE_ALWAYS
	_live_full_sampler.process_physics_priority = 1_000_000
	_live_full_sampler.observe = func() -> void:
		if not bool(_live_full_guard.active):
			return
		_live_full_guard.samples = int(_live_full_guard.samples) + 1
		if not predicate.call() and bool(_live_full_guard.valid):
			_live_full_guard.valid = false
			_check(false, description)
			_live_write("abort", {"reason": description, "role": _live_role})
	root.add_child(_live_full_sampler)


func _live_stop_full_guard() -> void:
	if _live_full_guard.is_empty():
		return
	_live_full_guard.active = false
	_live_full_observation["guard"] = _live_full_guard.duplicate(true)
	if is_instance_valid(_live_full_sampler):
		_live_full_sampler.queue_free()
		_live_full_sampler = null


func _live_full_identity_retained() -> bool:
	if not _live_walk_network_ready(true):
		return false
	if _live_role != "host":
		return true
	var capacity: Dictionary = _live_game.network_session.get_session_capacity_snapshot()
	return int(capacity.occupancy) == 1 and int(capacity.max_players) == 1 and int(capacity.available_slots) == 0


func _live_full_hold() -> bool:
	_check(_live_full_identity_retained(), "actual configured one-guest session retains original authenticated occupant")
	if not _failures.is_empty():
		return false
	_live_start_full_guard(_live_full_identity_retained, "original full-session occupant and identity remain unchanged")
	if not await _live_wait_file("candidate.main_ready", 60.0) or not await _live_wait_file("candidate.full_selected", 20.0) or not await _live_wait_file("candidate.continued", 20.0):
		return false
	_check(_live_full_identity_retained() and bool(_live_full_guard.valid) and int(_live_full_guard.samples) > 0,
		"same actual occupant remains authenticated throughout rejected selection and usable continuation")
	_live_stop_full_guard()
	_live_full_observation["retained"] = _live_read(_live_role + ".admitted")
	_live_write(_live_role + ".full_retained", _live_full_observation)
	if _live_role == "host":
		return _failures.is_empty() and await _live_wait_file("guest.full_retained", 20.0)
	return _failures.is_empty()


func _live_full_candidate_clear() -> bool:
	var session := _live_game.network_session
	return is_instance_valid(session) and not session.is_session_active() and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty() and _live_game.get_network_remote_body_intent_source() == null and int(_live_full_observation.get("join_intents", -1)) == 0 and int(_live_full_observation.get("admissions", -1)) == 0


func _live_full_row_state(session_id: StringName) -> Dictionary:
	var hud := _live_game.hud
	var row := _live_row(session_id)
	var refresh := hud.find_child("ServerBrowserRefreshButton", true, false) as Button
	var listing: Dictionary = {}
	for entry: Dictionary in _live_game.network_session.query_server_directory():
		if StringName(entry.get("session_id", &"")) == session_id:
			listing = entry
	var detail := (hud.get("_server_browser_detail") as Label).text
	var scroll := hud.get("_server_browser_results_scroll") as ScrollContainer
	var visible_rect := row.get_global_rect().intersection(scroll.get_global_rect()).intersection(root.get_visible_rect()) if row != null else Rect2()
	var endpoint: Dictionary = _live_game.get_lan_discovery().get_endpoint(session_id)
	var hosted := _live_read("host.ready")
	var logical_point := visible_rect.get_center()
	var viewport_to_window := root.get_final_transform()
	var window_point := viewport_to_window * logical_point
	var viewport_rect := root.get_visible_rect()
	var valid := row != null and row.is_visible_in_tree() and row.disabled and row.focus_mode == Control.FOCUS_NONE and row.text.contains("1/1 guests") and row.text.contains("FULL") and visible_rect.has_area() and int(listing.get("player_count", -1)) == 1 and int(listing.get("max_players", -1)) == 1 and int(listing.get("available_slots", -1)) == 0 and bool(listing.get("is_full", false)) and (hud.get("_server_browser_title") as Label).text == "ALL SESSIONS FULL" and detail.contains("The only session is full.") and detail.contains("NEXT ACTION // REFRESH SERVER LIST OR RETURN") and not detail.contains("SELECT A SESSION") and refresh != null and not refresh.disabled and refresh.focus_mode == Control.FOCUS_ALL and root.gui_get_focus_owner() == refresh and int(endpoint.get("port", 0)) == int(hosted.get("port", -1)) and not str(endpoint.get("address", "")).is_empty()
	return {"valid": valid, "session_id": str(session_id), "endpoint": endpoint, "listing": listing,
		"row_text": row.text if row != null else "", "disabled": row.disabled if row != null else false,
		"focus_mode": row.focus_mode if row != null else -1, "detail": detail,
		"directory_generation": int(_live_game.get("_lan_directory_generation")),
		"pointer_position": [logical_point.x, logical_point.y],
		"pointer_window_position": [window_point.x, window_point.y],
		"viewport_visible_rect": [viewport_rect.position.x, viewport_rect.position.y, viewport_rect.size.x, viewport_rect.size.y],
		"viewport_size": [root.size.x, root.size.y],
		"viewport_to_window": {"x": [viewport_to_window.x.x, viewport_to_window.x.y], "y": [viewport_to_window.y.x, viewport_to_window.y.y], "origin": [viewport_to_window.origin.x, viewport_to_window.origin.y]}}


func _live_full_candidate() -> void:
	var identity := _live_player_identity()
	_live_full_observation = {"player": identity, "join_intents": 0, "admissions": 0, "row_activations": 0, "pointer_events": []}
	_live_game.hud.presentation_intent_requested.connect(func(kind: StringName, payload: Dictionary) -> void:
		if kind == &"server_browser" and StringName(payload.get("action", &"")) in [&"join", &"manual_join"]:
			_live_full_observation.join_intents = int(_live_full_observation.join_intents) + 1
	)
	if not await _live_button("IntroServerBrowserButton") or not await _live_button("ServerBrowserRefreshButton"):
		return
	var session := _live_game.network_session
	session.peer_admitted.connect(func(_peer_id: int, _receipt: Dictionary) -> void:
		_live_full_observation.admissions = int(_live_full_observation.admissions) + 1
	)
	_live_start_full_guard(_live_full_candidate_clear, "full-row candidate never starts transport or gains admission")
	var session_id := StringName(str(_live_read("host.ready").get("session_id", "")))
	if not await _live_boundary(func(): return bool(_live_full_row_state(session_id).valid), 10.0, "actual LAN host advertises its real occupied one-guest full row with accurate recovery feedback"):
		return
	var first := _live_full_row_state(session_id)
	_live_full_observation["first"] = first
	_live_write("candidate.full_selected", {"pid": OS.get_process_id(), "player": identity, "row": first})
	var row := _live_row(session_id)
	row.pressed.connect(func() -> void:
		_live_full_observation.row_activations = int(_live_full_observation.row_activations) + 1
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			(_live_full_observation.pointer_events as Array).append(event.pressed)
	)
	# Input.parse_input_event receives window-local coordinates; Viewport input
	# applies the inverse final transform before hit testing logical GUI rects.
	var point_values: Array = first.pointer_window_position
	var point := Vector2(float(point_values[0]), float(point_values[1]))
	# Actual GUI delivery to the visible disabled row; no signal emission,
	# handler call, focus override or fabricated network attempt is permitted.
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await process_frame
	_check(_live_full_candidate_clear() and int(_live_full_observation.row_activations) == 0 and _live_full_observation.pointer_events == [true, false] and bool(_live_full_row_state(session_id).valid),
		"ordinary pointer selection is refused by the real disabled full row without join intent, admission or misleading feedback")
	if not _failures.is_empty() or not await _live_button("ServerBrowserRefreshButton"):
		return
	if not await _live_boundary(func():
		var state := _live_full_row_state(session_id)
		return bool(state.valid) and int(state.directory_generation) > int(first.directory_generation),
		10.0, "ordinary Refresh obtains a new live full advertisement and retains usable accurate full feedback"):
		return
	_live_full_observation["refreshed"] = _live_full_row_state(session_id)
	if not await _live_begin_shift() or not await _live_walk("full_refused_solo", &"move_forward", false, identity):
		return
	_check(_live_player_identity() == identity and _live_full_candidate_clear() and bool(_live_full_guard.valid),
		"Back and Begin Shift restore usable same-player solo gameplay without full-session admission")
	if not _failures.is_empty():
		return
	_live_stop_full_guard()
	_live_write("candidate.continued", {"pid": OS.get_process_id(), "player": identity, "guard": _live_full_observation.guard})


func _live_check_full_receipts(host: Dictionary, guest: Dictionary) -> void:
	var candidate := _live_read("candidate.done")
	var observation: Dictionary = candidate.get("full", {})
	var identity: Dictionary = observation.get("player", {})
	_check(int(identity.get("pid", 0)) == int(candidate.get("pid", -1)) and int(candidate.get("pid", 0)) != int(host.get("pid", 0)) and int(candidate.get("pid", 0)) != int(guest.get("pid", 0)), "full-row candidate is a third independent actual Main player")
	_check(int(observation.get("join_intents", -1)) == 0 and int(observation.get("admissions", -1)) == 0 and int(observation.get("row_activations", -1)) == 0 and observation.get("pointer_events", []) == [true, false],
		"actual full-row pointer press/release produced no join handler activation or admission")
	for role: String in ["host", "guest", "candidate"]:
		var full: Dictionary = _live_read(role + ".done").get("full", {})
		var guard: Dictionary = full.get("guard", {})
		_check(bool(guard.get("valid", false)) and int(guard.get("samples", 0)) > 0 and not bool(guard.get("active", true)), role + " continuous physics guard completed without identity/admission changes")
		if role != "candidate":
			_check(full.get("retained", {}) == _live_read(role + ".admitted") and not _live_read(role + ".full_retained").is_empty(), role + " retained the original admitted peer and generation until candidate continuation")
	for stage: String in ["first", "refreshed"]:
		var state: Dictionary = observation.get(stage, {})
		_check(bool(state.get("valid", false)) and str(state.get("session_id", "")) == str(_live_read("host.ready").get("session_id", "")), stage + " full row belongs to exact live configured host")
	var walk: Dictionary = (candidate.get("gameplay", {}) as Dictionary).get("full_refused_solo", {})
	var start: Dictionary = walk.get("start", {})
	var authority: Dictionary = start.get("authority", {})
	_check(not bool(walk.get("connected", true)) and not bool(authority.get("network_active", true)) and float(walk.get("distance_m", 0.0)) >= 1.0 and float(walk.get("walk_seconds", 6.0)) <= 5.0 and float(walk.get("settle_seconds", 6.0)) <= 5.0 and (walk.get("neutral", []) as Array).size() == 12,
		"refused candidate completed original bounded supported one-metre solo walk and twelve neutral ticks")
	var previous := int(start.get("frame", -1))
	for phase: String in ["samples", "settle", "neutral"]:
		for sample: Dictionary in walk.get(phase, []):
			_check(_live_walk_sample_valid(sample, identity, authority) and int(sample.get("frame", -1)) == previous + 1 and not bool((sample.get("authority", {}) as Dictionary).get("network_active", true)), "full-refused walk preserves every actual physics step's original supported local actor and cleared session")
			previous = int(sample.get("frame", -1))


func _live_cancel_coordinator() -> bool:
	# An owned loopback UDP endpoint accepts datagrams but never answers ENet's
	# handshake. No external address, admission race or transport override.
	_live_pending_endpoint = PacketPeerUDP.new()
	var error := _live_pending_endpoint.bind(0, "127.0.0.1")
	_check(error == OK, "coordinator owns non-admitting loopback endpoint")
	if error != OK:
		return false
	_live_port = _live_pending_endpoint.get_local_port()
	_live_write("endpoint.ready", {"pid": OS.get_process_id(), "port": _live_port})
	_live_peers.cancel = _live_spawn("cancel")
	_check(int(_live_peers.cancel) > 0, "independent cancellation Main wrapper starts")
	if int(_live_peers.cancel) <= 0 or not await _live_wait_file("cancel.main_ready", 60.0) or not await _live_wait_file("cancel.done", 100.0):
		return false
	var received := _live_pending_endpoint.get_available_packet_count() > 0
	_check(received, "owned non-admitting endpoint receives the real Manual Join handshake")
	return received


func _live_prepare_pending_browser(browser_open: bool = false) -> bool:
	if not browser_open and not await _live_button("IntroServerBrowserButton"):
		return false
	if _live_cancel_rejoin:
		# Opening the page only presents HUD controls. Ordinary Refresh creates
		# the adapter through GameFlow's server-browser intent boundary.
		if not await _live_button("ServerBrowserRefreshButton"):
			return false
		_check(is_instance_valid(_live_game.network_session), "ordinary browser Refresh creates the real session adapter before observation")
		if not _failures.is_empty():
			return false
		_live_game.network_session.peer_admitted.connect(func(_peer_id: int, _receipt: Dictionary):
			_live_cancel_observation.fresh_admissions = int(_live_cancel_observation.fresh_admissions) + 1
			_check(_live_cancel_fresh_requested, "no cancelled request admits before fresh live-row activation"))
		_live_start_full_guard(func():
			if _live_no_answer and not _live_cancel_fresh_requested and not paused:
				return false
			if _live_player_identity() != _live_cancel_observation.player:
				return false
			for old: ENetMultiplayerPeer in _live_cancelled_native_peers:
				if old.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED or _live_game.network_session.get("_peer") == old:
					return false
			var session := _live_game.network_session
			return _live_cancel_fresh_requested or (session.get_admitted_peer_ids().is_empty() and session.get_server_offer().is_empty()),
			"cancelled native peers stay closed and original Player survives fresh join and leave")
	return _failures.is_empty()


func _live_cancel_guest(endpoint_port: int = 0) -> void:
	if not await _live_prepare_pending_browser():
		return
	var hud := _live_game.hud as GameHUD
	var address := hud.get("_server_browser_address") as LineEdit
	var port := hud.get("_server_browser_port") as LineEdit
	var player_name := hud.get("_server_browser_player_name") as LineEdit
	address.text = "127.0.0.1"
	var pending_port := endpoint_port if endpoint_port > 0 else _live_port
	port.text = str(pending_port)
	player_name.text = "Cancel Probe"
	var offline := hud.find_child("ServerBrowserDisconnectButton", true, false) as Button
	_check(offline != null and offline.is_visible_in_tree() and offline.disabled,
		"visible offline browser action starts disabled")
	if not _failures.is_empty():
		return
	for attempt in [1, 2]:
		if not await _live_button("ServerBrowserManualJoinButton"):
			return
		if not await _live_boundary(_live_pending_join, 5.0, "visible Manual Join starts pending attempt %d" % attempt):
			return
		var native: ENetMultiplayerPeer
		if _live_cancel_rejoin:
			native = _live_game.network_session.get("_peer") as ENetMultiplayerPeer
			_check(native != null and native == _live_game.network_session.get("_pending_join_peer") and native.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and _live_game.network_session.get_admitted_peer_ids().is_empty() and int(_live_game.network_session.get("_pending_join_deadline_milliseconds")) > Time.get_ticks_msec() and _live_game.network_session.is_processing(), "pending Cancel attempt owns an actual unadmitted native CONNECTING peer with armed deadline/process")
			if not _failures.is_empty():
				return
		var pending := {"port": pending_port, "active": true, "state": "connecting"}
		if _live_cancel_rejoin:
			pending["native_peer_id"] = str(native.get_instance_id())
		_live_write("cancel.pending%d" % attempt, pending)
		var cancel := hud.find_child("ServerBrowserDisconnectButton", true, false) as Button
		var manual := hud.find_child("ServerBrowserManualJoinButton", true, false) as Button
		var back := hud.find_child("ServerBrowserBackButton", true, false) as Button
		var available := cancel != null and cancel.is_visible_in_tree() and not cancel.disabled and cancel.text == "CANCEL CONNECTION" and cancel.focus_mode == Control.FOCUS_ALL and manual.focus_neighbor_right == manual.get_path_to(cancel) and cancel.focus_neighbor_right == cancel.get_path_to(back)
		_check(available, "pending browser exposes focusable Cancel Connection in controller graph")
		if not available:
			return
		cancel.grab_focus()
		await process_frame
		if attempt == 1:
			var card := hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "generation": 500, "revision": 1})
			_check(card and cancel.is_visible_in_tree() and not cancel.disabled and root.gui_get_focus_owner() == cancel,
				"newer tutorial leaves browser Cancel Connection visible and focused")
			if not _failures.is_empty():
				return
		if not await _live_activate(cancel):
			return
		if not await _live_boundary(_live_cancelled_join, 5.0, "ui_accept Cancel closes transport and presents disconnected"):
			return
		if _live_cancel_rejoin:
			var feedback := _live_browser_retry_observation()
			feedback["action_focused"] = root.gui_get_focus_owner() == cancel
			feedback["manual_to_action"] = manual.focus_neighbor_right == manual.get_path_to(cancel)
			feedback["action_to_back"] = cancel.focus_neighbor_right == cancel.get_path_to(back)
			_live_write("cancel.feedback%d" % attempt, feedback)
			_check(_live_browser_retry_ready(feedback) and bool(feedback.action_focused) and bool(feedback.manual_to_action) and bool(feedback.action_to_back),
				"ordinary Cancel retains current fenced Retry Connection and usable action navigation")
		else:
			_check(cancel.disabled and cancel.focus_mode == Control.FOCUS_NONE and root.gui_get_focus_owner() == back,
				"cancel completion restores browser focus to Back")
		if not _failures.is_empty():
			return
		if _live_cancel_rejoin:
			_live_cancelled_native_peers.append(native)
			var retired := _live_cancel_retirement(native)
			_check(bool(retired.valid), "ordinary Cancel retires native peer, pending deadline and all unadmitted authority")
			(_live_cancel_observation.retired as Array).append(retired)
			(_live_cancel_observation.old_native_ids as Array).append(str(native.get_instance_id()))
			if not _failures.is_empty():
				return
		_live_write("cancel.cancelled%d" % attempt, {"active": false, "state": "disconnected"})
		if not await _live_button("ServerBrowserRefreshButton") or not await _live_button("ServerBrowserBackButton") or not await _live_button("IntroServerBrowserButton"):
			return
		_check(address.text == "127.0.0.1" and port.text == str(pending_port),
			"browser remains usable and retains Manual Join endpoint after cancellation")
		if not _failures.is_empty():
			return
	_live_write("cancel.reusable", {"attempts": 2, "cancelled": 2})


# This is the separately unrun no-answer case, not the parked connected/raw-host
# browser-unreachable packaged route. The coordinator only binds UDP; it never
# sends an ENet response. All expiry and recovery below belong to production.
func _live_no_answer_then_join() -> void:
	_live_cancel_observation = {"player": _live_player_identity(), "retired": [], "old_native_ids": [], "fresh_admissions": 0, "phase": "opening", "stops": []}
	var endpoint_port := int(_live_read("cancel_endpoint.ready").get("port", 0))
	_check(endpoint_port > 0 and endpoint_port != _live_port, "no-answer UDP endpoint is recorded before the guest and separate from the live Main host")
	if not _failures.is_empty() or not await _live_button("IntroServerBrowserButton") or not await _live_begin_shift() or not await _live_open_pause_browser():
		return
	if not await _live_prepare_pending_browser(true):
		return
	var hud := _live_game.hud as GameHUD
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	session.session_stopped.connect(func(reason: StringName):
		(_live_cancel_observation.stops as Array).append({"reason": str(reason), "at_milliseconds": Time.get_ticks_msec(), "phase": str(_live_cancel_observation.phase), "paused": paused}))
	(hud.get("_server_browser_address") as LineEdit).text = "127.0.0.1"
	(hud.get("_server_browser_port") as LineEdit).text = str(endpoint_port)
	(hud.get("_server_browser_player_name") as LineEdit).text = "No Answer Probe"
	_live_cancel_observation.phase = "first_pending"
	if not await _live_button("ServerBrowserManualJoinButton") or not await _live_boundary(_live_pending_join, 5.0, "ordinary Manual Join creates no-answer pending transport"):
		return
	var first_native := session.get("_peer") as ENetMultiplayerPeer
	var first := _live_no_answer_pending_observation(first_native, endpoint_port)
	_live_cancel_observation["first_pending"] = first
	_check(bool(first.valid), "first no-answer attempt has actual paused native CONNECTING peer and armed production deadline")
	if not _failures.is_empty():
		return
	_live_write("guest.no_answer_pending", first)
	# Start the existing UI boundary only after observing the pending native
	# attempt. Do not poll native ENet, expire the adapter or change its timer.
	if not await _live_boundary(_live_cancelled_join, 5.0, "production five-second deadline naturally retires the paused unanswered join"):
		return
	var feedback := _live_browser_retry_observation()
	var copy := hud.get("_server_browser_feedback") as Label
	var stops: Array = _live_cancel_observation.stops
	var stopped: Dictionary = stops[0] if stops.size() == 1 else {}
	feedback["copy"] = copy.text
	feedback["copy_visible"] = copy.is_visible_in_tree()
	feedback["terminal_updates_after_retirement"] = 0
	feedback["observed_at_milliseconds"] = Time.get_ticks_msec()
	_live_cancel_observation["timeout"] = feedback
	_check(stops.size() == 1 and stopped.get("reason", "") == "connection_timeout" and stopped.get("phase", "") == "first_pending" and bool(stopped.get("paused", false)) and int(stopped.get("at_milliseconds", 0)) >= int(first.deadline_milliseconds), "actual timeout callback occurs once while paused and never before the retained production deadline")
	_check(_live_browser_retry_ready(feedback, 0) and bool(feedback.copy_visible) and str(feedback.copy).begins_with("The session host did not admit the connection in time.") and str(feedback.copy).contains("NEXT ACTION // RETRY CONNECTION"), "natural timeout displays honest copy and its exact current retired fenced Retry action")
	var first_retired := _live_cancel_retirement(first_native)
	_check(bool(first_retired.valid), "automatic no-answer timeout retires native peer, pending deadline and all unadmitted authority")
	_live_cancelled_native_peers.append(first_native)
	(_live_cancel_observation.retired as Array).append(first_retired)
	(_live_cancel_observation.old_native_ids as Array).append(str(first_native.get_instance_id()))
	_live_cancel_observation.phase = "timed_out"
	_live_write("guest.no_answer_timeout", _live_cancel_observation)
	if not _failures.is_empty():
		return
	var action := hud.find_child("ServerBrowserDisconnectButton", true, false) as Button
	_live_cancel_observation.phase = "retry_pending"
	if not await _live_activate(action) or not await _live_boundary(_live_pending_join, 5.0, "ordinary Retry Connection starts a fresh unanswered attempt"):
		return
	var retry_native := session.get("_peer") as ENetMultiplayerPeer
	var retry := _live_no_answer_pending_observation(retry_native, endpoint_port)
	_live_cancel_observation["retry_pending"] = retry
	_check(bool(retry.valid) and retry_native != first_native and int(retry.deadline_milliseconds) > int(first.deadline_milliseconds) and str(retry.address) == str(first.address) and int(retry.port) == int(first.port), "same ordinary Retry action retains endpoint and creates a different native CONNECTING peer with a fresh deadline")
	_check(action.text == "CANCEL CONNECTION" and action.is_visible_in_tree() and not action.disabled, "fresh no-answer Retry offers ordinary Cancel before its deadline")
	if not _failures.is_empty() or not await _live_activate(action) or not await _live_boundary(_live_cancelled_join, 5.0, "ordinary Cancel closes the fresh no-answer retry"):
		return
	var retry_retired := _live_cancel_retirement(retry_native)
	var cancelled_feedback := _live_browser_retry_observation()
	_check(bool(retry_retired.valid) and _live_browser_retry_ready(cancelled_feedback), "retry Cancel retires every owner and preserves its exact explicit-shutdown Retry fence")
	_check((_live_cancel_observation.stops as Array).size() == 2 and str((_live_cancel_observation.stops as Array)[1].get("reason", "")) == "ui_cancel" and int((_live_cancel_observation.stops as Array)[1].get("at_milliseconds", 0)) < int(retry.deadline_milliseconds), "retry is cancelled promptly before expiry, with no second automatic timeout")
	_live_cancelled_native_peers.append(retry_native)
	(_live_cancel_observation.retired as Array).append(retry_retired)
	(_live_cancel_observation.old_native_ids as Array).append(str(retry_native.get_instance_id()))
	_live_cancel_observation["retry_cancelled"] = cancelled_feedback
	_live_cancel_observation.phase = "fresh_join"
	_live_write("guest.no_answer_reusable", _live_cancel_observation)
	if not _failures.is_empty():
		return
	# Remain in this same paused browser: the existing guest flow refreshes,
	# selects the actual independent Main host, walks and normally leaves.
	await _live_guest()


func _live_no_answer_pending_observation(native: ENetMultiplayerPeer, endpoint_port: int) -> Dictionary:
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	var observed := Time.get_ticks_msec()
	var deadline := int(session.get("_pending_join_deadline_milliseconds"))
	var endpoint := {"address": str(_live_game.get("_network_session_address")), "port": int(_live_game.get("_network_session_port"))}
	var valid := native != null and native == session.get("_pending_join_peer") and native.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and session.get_admitted_peer_ids().is_empty() and session.get_server_offer().is_empty() and deadline > observed and session.is_processing() and paused and str(endpoint.address) == "127.0.0.1" and int(endpoint.port) == endpoint_port
	return {"valid": valid, "native_id": str(native.get_instance_id()) if native != null else "", "observed_at_milliseconds": observed, "deadline_milliseconds": deadline, "started_at_milliseconds": deadline - SessionType.HANDSHAKE_DEFAULT_TIMEOUT_MILLISECONDS, "paused": paused, "address": str(endpoint.get("address", "")), "port": int(endpoint.get("port", 0)), "expected_port": endpoint_port}


func _live_cancel_retirement(native: ENetMultiplayerPeer) -> Dictionary:
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	var snapshot: Dictionary = session.get_snapshot()
	var empty_authority := ((snapshot.get("lifecycle", {}) as Dictionary).get("peers", []) as Array).is_empty()
	empty_authority = empty_authority and ((session.get("_ship_ownership").get_snapshot().get("ships", [])) as Array).all(func(ship: Dictionary): return int(ship.get("owner_peer_id", 0)) == 0)
	empty_authority = empty_authority and (session.get("_seat_authority").get_snapshot().get("assignments", []) as Array).is_empty()
	empty_authority = empty_authority and int(session.get_crew_role_snapshot().get("admitted_peer_count", -1)) == 0
	for role: Dictionary in (session.get_crew_role_snapshot().get("roles", {}) as Dictionary).values():
		empty_authority = empty_authority and int(role.get("peer_id", 0)) == 0
	empty_authority = empty_authority and (session.get_boarding_snapshot().get("occupancies", []) as Array).is_empty()
	var simulator := _live_game._network_remote_body_simulation
	empty_authority = empty_authority and (simulator == null or simulator.get_body_count() == 0)
	var retired := {"native_id": str(native.get_instance_id()), "native_closed": native.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "peer_null": session.get("_peer") == null, "api_offline": session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "inactive": not session.is_session_active(), "pending_null": session.get("_pending_join_peer") == null, "deadline_zero": int(session.get("_pending_join_deadline_milliseconds")) == 0, "offer_empty": session.get_server_offer().is_empty(), "admissions_empty": session.get_admitted_peer_ids().is_empty(), "authority_empty": empty_authority, "body_source_null": _live_game.get_network_remote_body_intent_source() == null, "on_foot": not (_live_game.get_node("Player") as PlayerController).is_seated()}
	var valid := true
	for key: String in retired:
		if key != "native_id":
			valid = valid and bool(retired[key])
	retired["valid"] = valid
	return retired


func _live_cancel_then_join() -> void:
	_live_cancel_observation = {"player": _live_player_identity(), "retired": [], "old_native_ids": [], "fresh_admissions": 0}
	var endpoint_port := int(_live_read("cancel_endpoint.ready").get("port", 0))
	_check(endpoint_port > 0 and endpoint_port != _live_port, "pending fixture is separate from the actual live Main host port")
	if not _failures.is_empty():
		return
	await _live_cancel_guest(endpoint_port)
	if not _failures.is_empty() or not await _live_button("ServerBrowserBackButton"):
		return
	await _live_guest()


func _live_pending_join() -> bool:
	var session := _live_game.network_session
	var snapshot: Dictionary = _live_game.hud.get("_network_status_presenter").get_snapshot()
	return is_instance_valid(session) and session.is_session_active() and session.get_server_offer().is_empty() and snapshot.get("state", &"") == &"connecting"


func _live_cancelled_join() -> bool:
	var session := _live_game.network_session
	var snapshot: Dictionary = _live_game.hud.get("_network_status_presenter").get_snapshot()
	return is_instance_valid(session) and not session.is_session_active() and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty() and snapshot.get("state", &"") == &"disconnected"


func _live_check_two_guest_receipts(host: Dictionary, guest: Dictionary, counts: Array) -> void:
	var second_host := _live_read("host.guest2_admitted")
	var second := _live_read("guest2.admitted")
	var remaining := _live_read("guest2.remaining")
	_check(int(second.get("pid", 0)) > 0 and int(second.get("pid", 0)) != int(host.get("pid", 0)) and int(second.get("pid", 0)) != int(guest.get("pid", 0)), "three independent actual Main processes have distinct PIDs")
	_check(int(second_host.get("guest_peer_id", 0)) == int(second.get("peer_id", -1)) and int(second_host.get("guest_generation", 0)) == int(second.get("peer_generation", -1)), "host and second guest agree on authenticated peer identity and generation")
	_check(int(second.get("peer_id", 0)) > 1 and int(second.get("peer_id", 0)) != int(guest.get("peer_id", 0)) and int(second.get("peer_generation", 0)) > 0 and second.get("player", {}) != guest.get("player", {}) and second.get("player", {}) != host.get("player", {}), "two authenticated peer/generation identities and three Main players are distinct")
	_check(int(second_host.get("pid", 0)) == int(host.get("pid", -1)) and second_host.get("player", {}) == host.get("player", {}) and int(second_host.get("host_peer_id", 0)) == 1, "same menu host admits both guests")
	_check(bool(remaining.get("authenticated", false)) and int(remaining.get("pid", 0)) == int(second.get("pid", -1)) and int(remaining.get("peer_id", 0)) == int(second.get("peer_id", -1)) and int(remaining.get("peer_generation", 0)) == int(second.get("peer_generation", -1)), "remaining guest receipt preserves original authenticated identity after first guest clears")
	_check(counts.size() == 5 and counts[0] == 0 and counts[1] == 1 and counts[2] == 2 and counts[3] == 1 and counts[4] == 0, "real host guest counts reconcile 0 → 1 → 2 → 1 → 0")


func _live_spawn(role: String) -> int:
	var profile := _live_directory.path_join(role + "-profile")
	for folder in ["data", "config", "cache", "state", "runtime", "tmp", "data-dirs", "config-dirs"]:
		DirAccess.make_dir_recursive_absolute(profile.path_join(folder))
		_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile.path_join(folder)])) == 0, "private profile directory permissions: " + folder)
	_check(OS.execute("/bin/chmod", PackedStringArray(["700", profile])) == 0, "private peer profile root permissions")
	var args := PackedStringArray(["--display-driver", "x11", "--disable-render-loop", "--rendering-driver", "dummy", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/network/game_flow_server_browser_integration_test.gd", "--", "--live-menu-cancel" if _live_cancel else ("--live-menu-two-guests" if _live_two_guests else "--live-menu-one-guest"), "--live-peer", role, _live_directory, str(_live_port)])
	if _live_no_answer:
		args[args.find("--live-menu-one-guest")] = "--live-menu-no-answer"
	elif _live_cancel_rejoin:
		args[args.find("--live-menu-one-guest")] = "--live-menu-cancel-rejoin"
	elif _live_full:
		args[args.find("--live-menu-one-guest")] = "--live-menu-full"
	elif _live_stale:
		args[args.find("--live-menu-one-guest")] = "--live-menu-stale"
	elif _live_rejoin:
		args[args.find("--live-menu-one-guest")] = "--live-menu-disconnect-rejoin"
	elif _live_gameplay:
		args[args.find("--live-menu-one-guest")] = "--live-menu-one-guest-gameplay"
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
		if _live_cancel:
			await _live_cancel_guest()
		elif _live_full and _live_role == "candidate":
			await _live_full_candidate()
		elif _live_role == "host":
			await _live_host()
		else:
			if _live_no_answer:
				await _live_no_answer_then_join()
			elif _live_cancel_rejoin:
				await _live_cancel_then_join()
			else:
				await _live_guest()
	if (_live_two_guests or _live_cancel or _live_gameplay or _live_full) and not _failures.is_empty():
		_live_write("abort", {"reason": "first_failed_boundary", "role": _live_role})
	# Cleanup is independent of menu success, focus, pause state or input capture.
	if _live_gameplay or _live_full:
		_live_release_movement()
	if _live_full or _live_rejoin or _live_stale or _live_cancel_rejoin:
		_live_stop_full_guard()
	if _live_full:
		var pointer_release := InputEventMouseButton.new()
		pointer_release.button_index = MOUSE_BUTTON_LEFT
		pointer_release.pressed = false
		Input.parse_input_event(pointer_release)
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
	if _live_cancel_rejoin and _live_role == "guest":
		_live_cancel_observation["guard"] = _live_full_guard.duplicate(true)
	var done := {"assertions": _assertions, "failures": Array(_failures), "pid": OS.get_process_id()}
	if _live_gameplay:
		done["gameplay"] = _live_walks
	if _live_full:
		done["full"] = _live_full_observation
		done["gameplay"] = _live_walks
	if _live_stale:
		done["stale"] = _live_stale_observation
	if _live_cancel_rejoin and _live_role == "guest":
		done["no_answer" if _live_no_answer else "cancel_rejoin"] = _live_cancel_observation
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
	if _live_full:
		# Fixture configuration only; ordinary Host still owns all startup work.
		_live_game.runtime_settings.multiplayer_max_players = 1
	if not await _live_button("ServerBrowserHostButton"):
		return
	if not await _live_boundary(func(): return is_instance_valid(_live_game.network_session) and _live_game.network_session.is_server() and is_instance_valid(_live_game.get_lan_discovery()) and _live_game.get_lan_discovery().is_responding(), 10.0, "host UI starts real ENet and LAN responder"):
		return
	var session := _live_game.network_session
	if _live_rejoin or _live_stale:
		_live_original_native_peer = session.get("_peer") as ENetMultiplayerPeer
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_check(_live_counts == [0] and session.get_admitted_peer_ids().is_empty(), "hosting excludes own player from guest capacity")
	var discovery := _live_game.get_lan_discovery()
	_live_write("host.ready", {"pid": OS.get_process_id(), "session_id": str(discovery.get("_responder_session_id")), "port": session.get_local_port()})
	if _live_stale:
		var hosted_id := str(discovery.get("_responder_session_id"))
		_live_start_full_guard(func():
			return _live_original_host_available(session, hosted_id) and (FileAccess.file_exists(_live_directory.path_join("guest.stale_join_ready")) or session.get_admitted_peer_ids().is_empty()),
			"original host stays available and unadmitted throughout actual stale-row expiry")
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
	if _live_stale:
		_check(bool(_live_full_guard.get("valid", false)) and int(_live_full_guard.get("samples", 0)) > 0, "host independently observes no stale admission and retained original transport/responder")
		_live_stale_observation = {"guard": _live_full_guard.duplicate(true), "native_peer_id": str(_live_original_native_peer.get_instance_id()), "session_id": str(discovery.get("_responder_session_id"))}
		_live_stop_full_guard()
	if _live_full:
		if not await _live_full_hold():
			return
		if not await _live_begin_shift():
			return
		_live_write("host.allow_leave", {})
	elif _live_two_guests:
		if not await _live_host_second_guest(session, guest_id):
			return
	else:
		if not await _live_begin_shift():
			return
		if _live_gameplay and not await _live_walk("connected", &"move_forward", true):
			return
		_live_write("host.allow_leave", {})
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().is_empty() and int(session.get_session_capacity_snapshot().occupancy) == 0, 20.0, "guest UI disconnect returns real host guest count to zero"):
		return
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_check(_live_guest_ownership_clear(session, guest_id), "host releases guest admissions, seat/ship/crew ownership and remote body")
	if _live_rejoin and not await _live_host_rejoin(session, guest_id):
		return
	if _live_two_guests:
		_check(_live_guest_ownership_clear(session, int(_live_read("guest2.admitted").get("peer_id", 0))), "host releases second guest admissions and all ownership")
	if not await _live_open_pause_browser():
		return
	_live_write("host.cleared", {})
	if not await _live_button("ServerBrowserDisconnectButton"):
		return
	_check(not session.is_session_active() and not discovery.is_responding(), "host UI disconnect closes session and LAN responder")
	if not await _live_browser_after_leave():
		return
	if _live_gameplay:
		await _live_walk("solo", &"move_back", false)


func _live_host_second_guest(session: NetworkEnetSessionAdapter, first_id: int) -> bool:
	if not await _live_wait_file("guest2.main_ready", 60.0):
		return false
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().size() == 2, 50.0, "same host observes two authenticated menu guests"):
		return false
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	if not await _live_wait_file("guest2.admitted", 20.0):
		return false
	var second := _live_read("guest2.admitted")
	var second_id := int(second.get("peer_id", 0))
	var generation := _live_host_peer_generation(session, second_id)
	var first := _live_read("guest.admitted")
	var both_authenticated := second_id > 1 and second_id != first_id and generation > 0 and generation == int(second.get("peer_generation", 0)) and _live_host_peer_generation(session, first_id) == int(first.get("peer_generation", -1)) and int(session.get_session_capacity_snapshot().occupancy) == 2
	_check(both_authenticated, "host matches both distinct authenticated guest identities and excludes itself from count two")
	if not both_authenticated:
		return false
	_live_write("host.guest2_admitted", {"pid": OS.get_process_id(), "host_peer_id": session.multiplayer.get_unique_id(), "player": _live_player_identity(), "guest_peer_id": second_id, "guest_generation": generation})
	if not await _live_begin_shift():
		return false
	_live_write("host.allow_leave", {})
	if not await _live_boundary(func(): return first_id not in session.get_admitted_peer_ids() and session.get_admitted_peer_ids().size() == 1 and int(session.get_session_capacity_snapshot().occupancy) == 1 and _live_departed_identity_clear(session, first_id), 20.0, "first guest UI disconnect clears only its admission and ownership; count becomes one"):
		return false
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	var remains := session.is_session_active() and session.is_server() and _live_game.get_lan_discovery().is_responding() and _live_host_peer_generation(session, second_id) == generation and int(session.get_crew_role_snapshot().get("admitted_peer_count", -1)) == 1
	_check(remains, "host remains active with second guest's original authenticated admission")
	if not remains:
		return false
	_live_write("host.first_cleared", {"departed_peer_id": first_id, "remaining_peer_id": second_id, "remaining_generation": generation})
	if not await _live_wait_file("guest2.remaining", 20.0):
		return false
	var receipt := _live_read("guest2.remaining")
	var agreed := bool(receipt.get("authenticated", false)) and int(receipt.get("peer_id", 0)) == second_id and int(receipt.get("peer_generation", 0)) == generation and _live_host_peer_generation(session, second_id) == generation
	_check(agreed, "host verifies remaining guest active-authentication receipt before allowing second departure")
	if not agreed:
		return false
	_live_write("host.allow_second_leave", {})
	return true


func _live_host_peer_generation(session: NetworkEnetSessionAdapter, peer_id: int) -> int:
	if peer_id not in session.get_admitted_peer_ids():
		return 0
	for peer: Dictionary in (session.get_snapshot().get("lifecycle", {}) as Dictionary).get("peers", []):
		if int(peer.get("peer_id", 0)) == peer_id:
			return int(peer.get("peer_generation", 0))
	return 0


func _live_guest() -> void:
	if not _live_no_answer and not await _live_button("IntroServerBrowserButton"):
		return
	if _live_stale and (not await _live_begin_shift() or not await _live_open_pause_browser()):
		return
	if not await _live_button("ServerBrowserRefreshButton"):
		return
	var hosted := _live_read("host.ready")
	var session_id := StringName(str(hosted.get("session_id", "")))
	if not await _live_boundary(func(): return _live_row(session_id) != null, 10.0, "refresh receives the actual host's LAN-advertised session row"):
		return
	var discovery := _live_game.get_lan_discovery()
	var endpoint := discovery.get_endpoint(session_id)
	_check(not session_id.is_empty() and int(endpoint.get("port", 0)) == int(hosted.get("port", -1)) and not str(endpoint.get("address", "")).is_empty(), "selected LAN row resolves the owned live host endpoint")
	_live_write(_live_role + ".discovered", {"session_id": str(session_id), "endpoint": endpoint})
	if _live_stale and not await _live_stale_expiry(session_id):
		return
	if _live_cancel_rejoin:
		_check(_live_cancel_retirement(_live_cancelled_native_peers.back()).valid, "no cancelled callback admitted before fresh live-row activation")
		_live_row(session_id).pressed.connect(func(): _live_cancel_fresh_requested = true, CONNECT_ONE_SHOT)
	if not _failures.is_empty() or not await _live_activate(_live_row(session_id)):
		return
	if not await _live_boundary(_live_authenticated, 20.0, "selected real HUD row joins and authenticates guest"):
		return
	var session := _live_game.network_session
	if _live_cancel_rejoin:
		var fresh_native := session.get("_peer") as ENetMultiplayerPeer
		var fresh_id := str(fresh_native.get_instance_id()) if fresh_native != null else ""
		_check(not fresh_id.is_empty() and fresh_id not in _live_cancel_observation.old_native_ids, "actual fresh authenticated join owns a new native peer")
		_live_cancel_observation["fresh_native_id"] = fresh_id
	if _live_rejoin:
		_live_original_native_peer = session.get("_peer") as ENetMultiplayerPeer
	var peer := (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	var guest_id := session.multiplayer.get_unique_id()
	_live_write(_live_role + ".admitted", {"pid": OS.get_process_id(), "peer_id": guest_id, "peer_generation": int(peer.get("peer_generation", 0)), "player": _live_player_identity()})
	if _live_full:
		if not await _live_full_hold():
			return
	elif _live_two_guests:
		if _live_role == "guest":
			# A second cold Main startup has its own boundary, never a wider handoff.
			if not await _live_wait_file("guest2.main_ready", 60.0):
				return
		else:
			if not await _live_wait_file("host.allow_leave", 20.0) or not await _live_wait_file("host.first_cleared", 20.0):
				return
			var still_admitted := _live_authenticated() and session.multiplayer.get_unique_id() == guest_id and int(((session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary).get("peer_generation", 0)) == int(peer.get("peer_generation", -1))
			_check(still_admitted, "remaining guest retains active transport and original authenticated identity after first departure")
			if not still_admitted:
				return
			_live_write("guest2.remaining", {"pid": OS.get_process_id(), "peer_id": guest_id, "peer_generation": int(peer.get("peer_generation", 0)), "authenticated": true})
	if not await _live_wait_file("host.allow_second_leave" if _live_role == "guest2" else "host.allow_leave", 20.0):
		return
	if _live_stale or _live_no_answer:
		if not await _live_button("ServerBrowserBackButton") or not await _live_button("ResumeButton"):
			return
	elif not await _live_begin_shift():
		return
	if _live_gameplay and not await _live_walk("connected", &"move_forward", true):
		return
	if not await _live_open_pause_browser() or not await _live_button("ServerBrowserDisconnectButton"):
		return
	_check(not session.is_session_active() and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty(), "guest UI disconnect clears transport and admission")
	_check(_live_game.get_network_remote_body_intent_source() == null and not (_live_game.get_node("Player") as PlayerController).is_seated(), "menu guest has no retained body or chair ownership")
	if _live_rejoin and not _live_record_guest_retirement("guest.retired", guest_id, _live_original_native_peer):
		return
	if not await _live_browser_after_leave():
		return
	if _live_gameplay and not await _live_walk("solo", &"move_back", false):
		return
	if _live_rejoin:
		await _live_guest_rejoin(session, session_id)
		return
	await _live_wait_file("host.first_cleared" if _live_two_guests and _live_role == "guest" else "host.cleared", 20.0)


func _live_stale_client_clear() -> bool:
	var session := _live_game.network_session
	return not session.is_session_active() and session.get("_peer") == null and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty() and _live_game.get_network_remote_body_intent_source() == null and int(_live_stale_observation.get("join_intents", -1)) == 0 and int(_live_stale_observation.get("admissions", -1)) == 0


func _live_stale_ui_state(session_id: StringName) -> Dictionary:
	var hud := _live_game.hud
	var retry := hud.find_child("ServerBrowserRetryButton", true, false) as Button
	var refresh := hud.find_child("ServerBrowserRefreshButton", true, false) as Button
	var back := hud.find_child("ServerBrowserBackButton", true, false) as Button
	var title := (hud.get("_server_browser_title") as Label).text
	var detail := (hud.get("_server_browser_detail") as Label).text
	# Read stored state only: polling must expire the cache while paused, without
	# this observer calling get_endpoint/expire_stale to drive the transition.
	var endpoints: Dictionary = _live_game.get_lan_discovery().get("_last_endpoints")
	var ready := paused and _live_row(session_id) == null and _live_game.network_session.query_server_directory().is_empty() and not endpoints.has(str(session_id)) and title == "SERVER LIST EXPIRED" and detail.contains("Server list expired. Refresh to see current servers.") and retry != null and retry.is_visible_in_tree() and not retry.disabled and root.gui_get_focus_owner() == retry and refresh != null and refresh.is_visible_in_tree() and not refresh.disabled and back != null and back.is_visible_in_tree() and not back.disabled and _live_stale_client_clear()
	return {"valid": ready, "paused": paused, "title": title, "detail": detail, "row_removed": _live_row(session_id) == null, "endpoint_removed": not endpoints.has(str(session_id)), "directory_empty": _live_game.network_session.query_server_directory().is_empty(), "retry_focused": retry != null and root.gui_get_focus_owner() == retry, "refresh_enabled": refresh != null and not refresh.disabled, "back_enabled": back != null and not back.disabled}


func _live_stale_expiry(session_id: StringName) -> bool:
	var session := _live_game.network_session
	var discovery := _live_game.get_lan_discovery()
	var row := _live_row(session_id)
	var player := _live_player_identity()
	var seen: Dictionary = discovery.get("_last_seen_usec")
	var seen_usec := int(seen.get(str(session_id), 0))
	_check(seen_usec > 0 and paused and row != null and row.is_visible_in_tree() and not row.disabled, "real fresh LAN row is available in the ordinary paused browser")
	if not _failures.is_empty():
		return false
	row.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == row, "fresh row owns selection focus before expiry")
	_live_stale_observation = {"join_intents": 0, "admissions": 0, "player": player, "session_id": str(session_id), "last_reply_usec": seen_usec, "fresh_generation": int(_live_game.get("_lan_directory_generation")), "focused_row_id": str(row.get_instance_id())}
	_live_game.hud.presentation_intent_requested.connect(func(kind: StringName, payload: Dictionary):
		if kind == &"server_browser" and StringName(payload.get("action", &"")) in [&"join", &"manual_join"]:
			_live_stale_observation.join_intents = int(_live_stale_observation.join_intents) + 1
	)
	session.peer_admitted.connect(func(_peer_id: int, _receipt: Dictionary):
		_live_stale_observation.admissions = int(_live_stale_observation.admissions) + 1
	)
	_live_start_full_guard(func():
		if not paused or not _live_stale_client_clear():
			return false
		if Time.get_ticks_usec() < seen_usec + 30_000_000:
			var cached: Dictionary = discovery.get("_last_endpoints")
			return _live_row(session_id) != null and cached.has(str(session_id))
		return true,
		"paused client remains unadmitted and fresh listing does not expire before thirty seconds")
	if not await _live_boundary(func(): return bool(_live_stale_ui_state(session_id).valid), 35.0, "production always-processing discovery expires actual thirty-second LAN row during paused gameplay"):
		return false
	var expired := _live_stale_ui_state(session_id)
	expired["age_seconds"] = float(Time.get_ticks_usec() - seen_usec) / 1_000_000.0
	expired["guard"] = _live_full_guard.duplicate(true)
	_live_stale_observation["expired"] = expired
	_check(float(expired.age_seconds) >= 30.0 and float(expired.age_seconds) <= 35.0 and bool(_live_full_guard.valid) and int(_live_full_guard.samples) > 0, "actual monotonic expiry honors frozen thirty-second boundary without early removal")
	_live_write("guest.stale_expired", _live_stale_observation)
	# The previously focused row has retired; ordinary Accept is now owned by
	# the production Retry control, rather than a stale join callback.
	var retry := _live_game.hud.find_child("ServerBrowserRetryButton", true, false) as Button
	if not _failures.is_empty() or not await _live_activate(retry):
		return false
	if not await _live_boundary(func(): return _live_row(session_id) != null and int(_live_game.get("_lan_directory_generation")) > int(_live_stale_observation.fresh_generation), 10.0, "ordinary Retry refresh rediscovers the original still-live host after expiry"):
		return false
	_check(_live_stale_client_clear() and _live_player_identity() == player, "expired focused selection creates no join intent/transport/admission and retains the actual Player")
	_live_stale_observation["refreshed"] = {"directory_generation": int(_live_game.get("_lan_directory_generation")), "endpoint": discovery.get_endpoint(session_id), "player": _live_player_identity(), "join_intents": int(_live_stale_observation.join_intents), "admissions": int(_live_stale_observation.admissions)}
	_live_stop_full_guard()
	_live_write("guest.stale_join_ready", _live_stale_observation)
	return _failures.is_empty()


func _live_check_stale_receipts(host: Dictionary, guest: Dictionary) -> void:
	var ready := _live_read("guest.stale_join_ready")
	var expired: Dictionary = ready.get("expired", {})
	var refreshed: Dictionary = ready.get("refreshed", {})
	var held: Dictionary = _live_read("host.done").get("stale", {})
	var guard: Dictionary = held.get("guard", {})
	_check(bool(expired.get("valid", false)) and bool(expired.get("paused", false)) and float(expired.get("age_seconds", 0.0)) >= 30.0 and float(expired.get("age_seconds", 36.0)) <= 35.0, "immutable expiry receipt proves actual paused monotonic thirty-second terminal refusal")
	_check(int(refreshed.get("join_intents", -1)) == 0 and int(refreshed.get("admissions", -1)) == 0 and int(refreshed.get("directory_generation", 0)) > int(ready.get("fresh_generation", 0)) and not (refreshed.get("endpoint", {}) as Dictionary).is_empty(), "actual Retry restores current endpoint and directory without stale admission")
	_check(ready.get("player", {}) == guest.get("player", {}) and refreshed.get("player", {}) == guest.get("player", {}), "same original guest Player proceeds from expired selection to real fresh admission")
	_check(bool(guard.get("valid", false)) and int(guard.get("samples", 0)) > 0 and held.get("session_id", "") == ready.get("session_id", ""), "independent host remained available and unadmitted through stale refusal and refresh")


func _live_expected_admission(role: String = "") -> Dictionary:
	return _live_read((_live_role if role.is_empty() else role) + (".rejoined" if _live_rejoin and _live_rejoined else ".admitted"))


func _live_rejoin_tuple_fresh(first: Dictionary, second: Dictionary, host: bool = false) -> bool:
	var id_key := "guest_peer_id" if host else "peer_id"
	var generation_key := "guest_generation" if host else "peer_generation"
	var first_id := int(first.get(id_key, 0))
	var second_id := int(second.get(id_key, 0))
	var generation := int(second.get(generation_key, 0))
	return first_id > 1 and second_id > 1 and generation > 0 and (second_id != first_id or generation > int(first.get(generation_key, 0)))


func _live_original_host_available(session: NetworkEnetSessionAdapter, session_id: String) -> bool:
	var discovery := _live_game.get_lan_discovery()
	return is_instance_valid(session) and session == _live_game.network_session and session.is_session_active() and session.is_server() and session.get("_peer") == _live_original_native_peer and _live_original_native_peer != null and _live_original_native_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and is_instance_valid(discovery) and discovery.is_responding() and str(discovery.get("_responder_session_id")) == session_id


func _live_host_rejoin(session: NetworkEnetSessionAdapter, old_id: int) -> bool:
	var hosted := _live_read("host.ready")
	var session_id := str(hosted.get("session_id", ""))
	_check(_live_original_host_available(session, session_id) and _live_guest_ownership_clear(session, old_id), "original host and LAN responder remain available with zero guests after ordinary Disconnect")
	if not _failures.is_empty():
		return false
	# Reuse the independent passive physics guard; only the original host's
	# continued availability is required while the guest walks and refreshes.
	_live_start_full_guard(_live_original_host_available.bind(session, session_id), "original host native peer and LAN responder survive guest retirement, solo walking and readmission")
	_live_write("host.first_cleared", {"guest_peer_id": old_id, "authority_clear": _live_guest_ownership_clear(session, old_id), "occupancy": int(session.get_session_capacity_snapshot().occupancy), "host_available": _live_original_host_available(session, session_id), "session_id": session_id, "native_peer_id": str(_live_original_native_peer.get_instance_id())})
	if not await _live_wait_file("guest.rejoin_requested", 20.0):
		return false
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().size() == 1, 20.0, "original host receives fresh authenticated admission after ordinary guest Disconnect"):
		return false
	var new_id := int(session.get_admitted_peer_ids()[0])
	var rejoined := {"pid": OS.get_process_id(), "host_peer_id": session.multiplayer.get_unique_id(), "player": _live_player_identity(), "guest_peer_id": new_id, "guest_generation": _live_host_peer_generation(session, new_id), "session_id": session_id, "native_peer_id": str(_live_original_native_peer.get_instance_id())}
	_check(_live_rejoin_tuple_fresh(_live_read("host.admitted"), rejoined, true), "host second admission has a fresh peer/generation tuple")
	if not _failures.is_empty():
		return false
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_live_write("host.rejoined", rejoined)
	if not await _live_wait_file("guest.rejoined", 20.0):
		return false
	var guest := _live_read("guest.rejoined")
	_check(int(guest.get("peer_id", 0)) == new_id and int(guest.get("peer_generation", 0)) == int(rejoined.guest_generation), "host and guest independently agree on second authenticated tuple")
	if not _failures.is_empty():
		return false
	_live_rejoined = true
	if not await _live_walk("rejoined_connected", &"move_forward", true):
		return false
	_live_write("host.allow_final_leave", {})
	if not await _live_boundary(func(): return session.get_admitted_peer_ids().is_empty() and int(session.get_session_capacity_snapshot().occupancy) == 0, 20.0, "guest second ordinary Disconnect returns original host to zero guests"):
		return false
	_live_counts.append(int(session.get_session_capacity_snapshot().occupancy))
	_check(_live_guest_ownership_clear(session, new_id), "host retires second admission and its body/seat/ship/crew authority")
	_check(bool(_live_full_guard.get("valid", false)) and int(_live_full_guard.get("samples", 0)) > 0, "independent physics observations continuously retain original host availability")
	_live_write("host.second_cleared", {"guest_peer_id": new_id, "guest_generation": int(rejoined.guest_generation), "authority_clear": _live_guest_ownership_clear(session, new_id), "host_available": _live_original_host_available(session, session_id), "guard": _live_full_guard.duplicate(true)})
	_live_stop_full_guard()
	return _failures.is_empty()


func _live_record_guest_retirement(name: String, old_id: int, old_native: ENetMultiplayerPeer) -> bool:
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	var retired := {"player": _live_player_identity(), "native_peer_id": str(old_native.get_instance_id()) if old_native != null else "", "native_closed": old_native != null and old_native.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "peer_cleared": session.get("_peer") == null, "api_offline": session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "session_inactive": not session.is_session_active(), "offer_empty": session.get_server_offer().is_empty(), "admissions_empty": session.get_admitted_peer_ids().is_empty(), "authority_clear": _live_retired_client_ownership_clear(session, old_id), "body_source_clear": _live_game.get_network_remote_body_intent_source() == null, "on_foot": not (_live_game.get_node("Player") as PlayerController).is_seated()}
	var clear := true
	for key: String in ["native_closed", "peer_cleared", "api_offline", "session_inactive", "offer_empty", "admissions_empty", "authority_clear", "body_source_clear", "on_foot"]:
		clear = clear and bool(retired.get(key, false))
	_check(clear, name + " ordinary Disconnect retires native peer/API/offer/admissions/body/seat/ship/crew ownership")
	_live_write(name, retired)
	return _failures.is_empty()


func _live_retired_client_ownership_clear(session: NetworkEnetSessionAdapter, old_id: int) -> bool:
	if old_id <= 1 or session.is_session_active() or session.is_server() or old_id in session.get_admitted_peer_ids():
		return false
	# Read the client's actual ledgers. A client need not own the host-only body
	# simulator; if one exists, retirement still requires it to contain no bodies.
	var lifecycle: Dictionary = session.get_snapshot()["lifecycle"]
	var ships: Dictionary = session.get("_ship_ownership").get_snapshot()
	var seats: Dictionary = session.get("_seat_authority").get_snapshot()
	var crew: Dictionary = session.get_crew_role_snapshot()
	var boarding: Dictionary = session.get_boarding_snapshot()
	for peer: Dictionary in lifecycle["peers"]:
		if int(peer.get("peer_id", 0)) == old_id:
			return false
	for ship: Dictionary in ships["ships"]:
		if int(ship.get("owner_peer_id", 0)) == old_id:
			return false
	for assignment: Dictionary in seats["assignments"]:
		if int(assignment.get("occupant_peer_id", 0)) == old_id:
			return false
	if int(crew["admitted_peer_count"]) != 0:
		return false
	for assignment: Dictionary in (crew["roles"] as Dictionary).values():
		if int(assignment.get("peer_id", 0)) == old_id:
			return false
	for occupancy: Dictionary in boarding["occupancies"]:
		if int(occupancy.get("peer_id", 0)) == old_id:
			return false
	var simulator := _live_game._network_remote_body_simulation
	return simulator == null or simulator.get_body_count() == 0


func _live_guest_rejoin(session: NetworkEnetSessionAdapter, session_id: StringName) -> bool:
	if not await _live_wait_file("host.first_cleared", 20.0):
		return false
	if not await _live_open_pause_browser():
		return false
	var previous_generation := int(_live_game.get("_lan_directory_generation"))
	if not await _live_button("ServerBrowserRefreshButton"):
		return false
	if not await _live_boundary(func(): return int(_live_game.get("_lan_directory_generation")) > previous_generation and _live_row(session_id) != null, 10.0, "fresh actual Refresh rediscovers the still-available original host"):
		return false
	var hosted := _live_read("host.ready")
	var endpoint := _live_game.get_lan_discovery().get_endpoint(session_id)
	_check(int(endpoint.get("port", 0)) == int(hosted.get("port", -1)) and not str(endpoint.get("address", "")).is_empty(), "refreshed real LAN row resolves original host endpoint")
	_live_write("guest.rejoin_requested", {"session_id": str(session_id), "endpoint": endpoint, "directory_generation": int(_live_game.get("_lan_directory_generation"))})
	if not _failures.is_empty() or not await _live_activate(_live_row(session_id)):
		return false
	if not await _live_boundary(_live_authenticated, 20.0, "actual refreshed row produces fresh authenticated guest admission"):
		return false
	var peer := (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	var new_native := session.get("_peer") as ENetMultiplayerPeer
	var rejoined := {"pid": OS.get_process_id(), "peer_id": session.multiplayer.get_unique_id(), "peer_generation": int(peer.get("peer_generation", 0)), "player": _live_player_identity(), "session_id": str(session_id), "native_peer_id": str(new_native.get_instance_id()) if new_native != null else "", "old_native_closed": _live_original_native_peer != null and _live_original_native_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED}
	# Preserve the actual observation even if validation rejects readmission.
	_live_write("guest.rejoin_observed", rejoined)
	_check(session == _live_game.network_session and _live_rejoin_tuple_fresh(_live_read("guest.admitted"), rejoined) and new_native != null and new_native != _live_original_native_peer and bool(rejoined.old_native_closed), "same guest adapter obtains fresh native transport and tuple while old peer remains closed")
	# JSON decodes the admitted PID as a float; compare explicit identity fields.
	var original_player: Dictionary = _live_read("guest.admitted").get("player", {})
	var rejoined_player: Dictionary = rejoined.player
	var original_pid := int(original_player.get("pid", 0))
	var original_object_id := str(original_player.get("object_id", ""))
	var original_path := str(original_player.get("path", ""))
	_check(original_pid > 0 and original_object_id.is_valid_int() and int(original_object_id) > 0 and not original_path.is_empty() and int(rejoined_player.get("pid", 0)) == original_pid and str(rejoined_player.get("object_id", "")) == original_object_id and str(rejoined_player.get("path", "")) == original_path, "readmission preserves the original runtime Player")
	if not _failures.is_empty():
		return false
	_live_write("guest.rejoined", rejoined)
	if not await _live_wait_file("host.rejoined", 20.0):
		return false
	var host := _live_read("host.rejoined")
	_check(int(host.get("guest_peer_id", 0)) == int(rejoined.peer_id) and int(host.get("guest_generation", 0)) == int(rejoined.peer_generation), "guest independently matches host's second authenticated tuple")
	if not _failures.is_empty():
		return false
	_live_rejoined = true
	if not await _live_button("ServerBrowserBackButton") or not await _live_button("ResumeButton"):
		return false
	if not await _live_walk("rejoined_connected", &"move_forward", true) or not await _live_wait_file("host.allow_final_leave", 20.0):
		return false
	if not await _live_open_pause_browser() or not await _live_button("ServerBrowserDisconnectButton"):
		return false
	if not _live_record_guest_retirement("guest.second_retired", int(rejoined.peer_id), new_native):
		return false
	if not await _live_browser_after_leave() or not await _live_walk("final_solo", &"move_back", false):
		return false
	return await _live_wait_file("host.cleared", 20.0)


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


func _live_open_pause_browser() -> bool:
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
	return await _live_button("ServerBrowserButton")


func _live_browser_retry_observation() -> Dictionary:
	var disconnect := _live_game.hud.find_child("ServerBrowserDisconnectButton", true, false) as Button
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	var presenter := _live_game.hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	var presentation: Dictionary = presenter.get_snapshot()
	var selected_action: Dictionary = _live_game.hud.call("_server_browser_session_action", presentation)
	return {
		"state": str(presentation.get("state", "")), "retryable": bool(presentation.get("retryable", false)), "has_error": presentation.has("error"),
		"source_session_id": str(presentation.get("session_id", "")),
		"source_generation": int(presentation.get("source_generation", -1)), "source_sequence": int(presentation.get("source_sequence", -1)),
		"retired_session_id": str(presenter.get("_retired_session_id")), "retired_generation": int(presenter.get("_retired_generation")), "retired_sequence": int(presenter.get("_retired_sequence")),
		"active_session_id": str(presenter.get("_source_session_id")), "active_generation": int(presenter.get("_source_generation")), "active_sequence": int(presenter.get("_source_sequence")),
		"game_flow_session_id": "game-flow-%d" % _live_game.get_instance_id(),
		"game_flow_generation": int(_live_game.get("_network_hud_session_epoch")), "game_flow_sequence": int(_live_game.get("_network_hud_snapshot_generation")),
		"game_flow_retired": bool(_live_game.get("_network_hud_session_retired")),
		"selected_action": str(selected_action.get("id", "")), "action_focusable": bool(selected_action.get("focusable", false)),
		"button_visible": disconnect != null and disconnect.is_visible_in_tree(), "button_enabled": disconnect != null and not disconnect.disabled,
		"button_text": disconnect.text if disconnect != null else "", "button_focus_mode": disconnect.focus_mode if disconnect != null else Control.FOCUS_NONE,
		"session_active": session.is_session_active(), "offer_empty": session.get_server_offer().is_empty(), "admissions_empty": session.get_admitted_peer_ids().is_empty(),
	}


func _live_browser_after_leave() -> bool:
	var observation := _live_browser_retry_observation()
	if _live_gameplay:
		_live_walks["after_rejoined_leave" if _live_rejoin and _live_rejoined and _live_role == "guest" else "after_leave"] = observation
	var ready := _live_browser_retry_ready(observation)
	_check(ready, "ordinary UI leave presents own current fenced disconnected Retry Connection with cleared session")
	if not ready or not _failures.is_empty():
		return false
	return await _live_button("ServerBrowserRefreshButton") and await _live_button("ServerBrowserBackButton") and await _live_button("ResumeButton")


func _live_browser_retry_ready(observation: Dictionary, terminal_updates_after_retirement: int = 1) -> bool:
	return (
		observation.get("state", "") == "disconnected" and bool(observation.get("retryable", false)) and not bool(observation.get("has_error", true))
		and observation.get("source_session_id", "") == observation.get("game_flow_session_id", "missing")
		and observation.get("source_session_id", "") == observation.get("retired_session_id", "missing")
		and int(observation.get("source_generation", -1)) == int(observation.get("game_flow_generation", -2)) and int(observation.get("source_generation", 0)) > 0
		and int(observation.get("source_generation", -1)) == int(observation.get("retired_generation", -2))
		and int(observation.get("source_sequence", -1)) == int(observation.get("retired_sequence", -2)) and int(observation.get("source_sequence", 0)) > 0
		# Adapter session_stopped publishes and retires the accepted tuple; the
		# explicit GameFlow shutdown then publishes one rejected terminal update.
		# Natural adapter expiry publishes only the accepted retired tuple (delta 0).
		and int(observation.get("game_flow_sequence", -1)) == int(observation.get("retired_sequence", -3)) + terminal_updates_after_retirement
		and bool(observation.get("game_flow_retired", false))
		and observation.get("active_session_id", "missing") == "" and int(observation.get("active_generation", 0)) == -1 and int(observation.get("active_sequence", 0)) == -1
		and observation.get("selected_action", "") == "retry" and bool(observation.get("action_focusable", false))
		and bool(observation.get("button_visible", false)) and bool(observation.get("button_enabled", false))
		and observation.get("button_text", "") == "RETRY CONNECTION" and int(observation.get("button_focus_mode", -1)) == Control.FOCUS_ALL
		and not bool(observation.get("session_active", true)) and bool(observation.get("offer_empty", false)) and bool(observation.get("admissions_empty", false))
	)


func _live_release_movement() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint_boost", &"jump", &"pause", &"ui_accept"]:
		var release := InputEventAction.new()
		release.action = action
		release.pressed = false
		Input.parse_input_event(release)
		Input.action_release(action)


func _live_walk_network_ready(connected: bool) -> bool:
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	if not is_instance_valid(session):
		return false
	if not connected:
		return not session.is_session_active() and session.get_server_offer().is_empty() and session.get_admitted_peer_ids().is_empty() and _live_game.get_network_remote_body_intent_source() == null
	var admitted: Dictionary = _live_expected_admission()
	if _live_role == "host":
		var guest_id := int(admitted.get("guest_peer_id", 0))
		return session.is_session_active() and session.is_server() and session.multiplayer.get_unique_id() == 1 and session.get_admitted_peer_ids().size() == 1 and _live_host_peer_generation(session, guest_id) == int(admitted.get("guest_generation", -1))
	var peer: Dictionary = (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	return _live_authenticated() and session.multiplayer.get_unique_id() == int(admitted.get("peer_id", 0)) and int(peer.get("peer_generation", 0)) == int(admitted.get("peer_generation", -1))


func _live_walk_snapshot(player: PlayerController) -> Dictionary:
	var session: NetworkEnetSessionAdapter = _live_game.network_session
	var peer: Dictionary = (session.get_server_offer().get("admission", {}) as Dictionary).get("peer", {}) as Dictionary
	var ships: Dictionary = session.get("_ship_ownership").get_snapshot()
	var seats: Dictionary = session.get("_seat_authority").get_snapshot()
	var crew: Dictionary = session.get_crew_role_snapshot()
	var support_query := PhysicsRayQueryParameters3D.create(player.global_position + player.up_direction * 0.15, player.global_position - player.up_direction * 0.5, 1, [player.get_rid()])
	var support: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(support_query)
	var collider: Object = support.get("collider") as Object
	var normal: Vector3 = support.get("normal", Vector3.ZERO)
	var collision := player.get_node("PlayerCollision") as CollisionShape3D
	var audit: Dictionary = player.get_remote_drive_audit()
	var host_admitted: Dictionary = _live_expected_admission("host")
	var host_guest_id := int(host_admitted.get("guest_peer_id", 0))
	return {"player": _live_player_identity(), "frame": Engine.get_physics_frames(),
		"position": _live_walk_vector(player.global_position), "velocity": _live_walk_vector(player.velocity),
		"basis": [_live_walk_vector(player.global_basis.x), _live_walk_vector(player.global_basis.y), _live_walk_vector(player.global_basis.z)],
		"grounded": player.is_on_floor(), "collider": str((collider as Node).get_path()) if collider is Node else "",
		"support_normal": _live_walk_vector(normal), "support_position": _live_walk_vector(support.get("position", Vector3.ZERO)),
		"supported": collider is CollisionObject3D and normal.dot(player.up_direction) >= cos(player.floor_max_angle),
		"paused": paused, "phase": int(_live_game.phase), "on_foot": int(player.get("_embodiment_state")) == PlayerController.EmbodimentState.ON_FOOT,
		"control_enabled": player.is_control_enabled(), "camera_active": bool(audit.get("camera_active", false)), "remote_driven": bool(audit.get("remote_driven", true)),
		"capsule_enabled": not collision.disabled, "processing": player.can_process() and player.is_physics_processing(),
		"input": [Input.get_axis("move_left", "move_right"), Input.get_axis("move_forward", "move_back")],
		"authority": {"main_id": str(_live_game.get_instance_id()), "session_id": str(session.get_instance_id()),
			"player_authority": player.get_multiplayer_authority(), "active_ship": str(_live_game.active_ship.get_instance_id()), "piloting": bool(_live_game.get("_piloting")),
			"network_active": session.is_session_active(), "server": session.is_server(), "peer_id": session.multiplayer.get_unique_id(),
			"peer_generation": int(peer.get("peer_generation", 0)), "admitted": Array(session.get_admitted_peer_ids()),
			"authenticated": _live_walk_network_ready(true), "host_guest_id": host_guest_id,
			"host_guest_generation": _live_host_peer_generation(session, host_guest_id) if _live_role == "host" else 0,
			"ships": ships.get("ships", []), "seats": seats.get("assignments", []), "crew": crew.get("roles", {})}}


func _live_walk_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _live_walk_vector_from(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) if value.size() == 3 else Vector3.ZERO


func _live_walk_sample_valid(sample: Dictionary, identity: Dictionary, authority: Dictionary) -> bool:
	return (
		sample.get("player", {}) == identity and sample.get("authority", {}) == authority
		and bool(sample.get("grounded", false)) and bool(sample.get("supported", false))
		and not str(sample.get("collider", "")).is_empty() and not bool(sample.get("paused", true))
		and int(sample.get("phase", GameFlow.Phase.INTRO)) != GameFlow.Phase.INTRO
		and bool(sample.get("on_foot", false)) and bool(sample.get("control_enabled", false))
		and bool(sample.get("camera_active", false)) and not bool(sample.get("remote_driven", true))
		and bool(sample.get("capsule_enabled", false)) and bool(sample.get("processing", false))
	)


func _live_walk(name: String, action: StringName, connected: bool, expected_identity: Dictionary = {}) -> bool:
	# Only input changes here. The same Main/player/session keep their production
	# physics, controls, collision, authority and authored spawn throughout.
	_live_release_movement()
	var player := _live_game.get_node("Player") as PlayerController
	var identity: Dictionary = _live_player_identity()
	var admitted_identity: Dictionary = expected_identity if not expected_identity.is_empty() else _live_expected_admission().get("player", {})
	_check(int(identity.pid) == int(admitted_identity.get("pid", 0)) and str(identity.object_id) == str(admitted_identity.get("object_id", "")) and str(identity.path) == str(admitted_identity.get("path", "")), name + " walk retains the original runtime Player identity")
	if not _failures.is_empty():
		return false
	if not await _live_boundary(func():
		var sample: Dictionary = _live_walk_snapshot(player)
		return _live_walk_sample_valid(sample, identity, sample.authority) and _live_walk_network_ready(connected) and player.velocity.length() <= 0.05 and Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx(), 5.0, name + " walking starts supported with neutral local controls"):
		_live_release_movement()
		return false
	var start: Dictionary = _live_walk_snapshot(player)
	var authority: Dictionary = start.authority
	var origin := player.global_position
	var camera_yaw := player.get_node("CameraRig/CameraYaw") as Node3D
	var direction: Vector3 = -camera_yaw.global_basis.z if action == &"move_forward" else camera_yaw.global_basis.z
	direction = direction.slide(player.up_direction).normalized()
	var receipt := {"action": str(action), "connected": connected, "start": start,
		"samples": [], "settle": [], "neutral": [], "direction": _live_walk_vector(direction)}
	_live_walks[name] = receipt
	var state := {"phase": "walk", "done": false, "valid": true, "receipt": receipt,
		"identity": identity, "authority": authority, "origin": origin, "direction": direction,
		"action": action, "connected": connected, "last_frame": int(start.frame),
		"started": Time.get_ticks_msec(), "deadline": Time.get_ticks_msec() + 5_000}
	var sampler := LiveWalkSampler.new()
	sampler.process_mode = Node.PROCESS_MODE_ALWAYS
	sampler.process_physics_priority = 1_000_000
	sampler.observe = _live_walk_step.bind(state, player)
	root.add_child(sampler)
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	while not bool(state.done):
		# This clock/abort path is independent of physics and the pause menu.
		if Time.get_ticks_msec() >= int(state.deadline) or FileAccess.file_exists(_live_directory.path_join("abort")):
			_live_walk_stop(state, false)
			break
		await process_frame
	_live_release_movement()
	sampler.queue_free()
	_check(bool(state.valid) and (receipt.neutral as Array).size() == 12,
		name + " actual supported one-metre walk, continuous settle and twelve consecutive neutral physics ticks")
	return _failures.is_empty()


func _live_walk_stop(state: Dictionary, valid: bool) -> void:
	state["valid"] = valid
	state["done"] = true
	_live_release_movement()


func _live_walk_step(state: Dictionary, player: PlayerController) -> void:
	if bool(state.done):
		return
	if not is_instance_valid(player):
		_live_walk_stop(state, false)
		return
	var sample: Dictionary = _live_walk_snapshot(player)
	var receipt: Dictionary = state.receipt
	var phase: String = state.phase
	var samples: Array = receipt["samples" if phase == "walk" else phase]
	samples.append(sample)
	var consecutive := int(sample.frame) == int(state.last_frame) + 1
	state["last_frame"] = int(sample.frame)
	var valid := (
		consecutive and _live_walk_sample_valid(sample, state.identity, state.authority)
		and _live_walk_network_ready(bool(state.connected))
		and Time.get_ticks_msec() < int(state.deadline)
		and not FileAccess.file_exists(_live_directory.path_join("abort"))
	)
	if not valid:
		_live_walk_stop(state, false)
		return
	if phase == "walk":
		var action: StringName = state.action
		var origin: Vector3 = state.origin
		var direction: Vector3 = state.direction
		var distance := (player.global_position - origin).slide(player.up_direction).dot(direction)
		var peak_speed := maxf(float(receipt.get("peak_speed_mps", 0.0)), player.velocity.slide(player.up_direction).length())
		receipt["end"] = sample
		receipt["distance_m"] = distance
		receipt["peak_speed_mps"] = peak_speed
		receipt["walk_seconds"] = float(Time.get_ticks_msec() - int(state.started)) / 1000.0
		if not Input.is_action_pressed(action):
			_live_walk_stop(state, false)
		elif distance >= 1.0:
			_live_release_movement()
			if peak_speed <= 0.1:
				_live_walk_stop(state, false)
				return
			state["phase"] = "settle"
			state["settle_started"] = Time.get_ticks_msec()
			state["deadline"] = Time.get_ticks_msec() + 5_000
		return
	# Once input releases, support/control/auth/identity failures never recover
	# inside a wait predicate: the first bad completed physics step stops here.
	if not Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx():
		_live_walk_stop(state, false)
		return
	if phase == "settle":
		receipt["settle_seconds"] = float(Time.get_ticks_msec() - int(state.settle_started)) / 1000.0
		if player.velocity.length() <= 0.05:
			receipt["neutral_start"] = sample
			state["neutral_origin"] = player.global_position
			state["phase"] = "neutral"
			state["deadline"] = Time.get_ticks_msec() + 5_000
		return
	var neutral_origin: Vector3 = state.neutral_origin
	var drift := maxf(float(receipt.get("neutral_drift_m", 0.0)), player.global_position.distance_to(neutral_origin))
	receipt["neutral_drift_m"] = drift
	if player.velocity.length() > 0.05 or drift > 0.02:
		_live_walk_stop(state, false)
	elif samples.size() == 12:
		_live_walk_stop(state, true)


func _live_check_gameplay_receipts() -> void:
	for role: String in ["host", "guest"]:
		var admitted: Dictionary = _live_read(role + ".admitted")
		var walks: Dictionary = _live_read(role + ".done").get("gameplay", {})
		var after_leave: Dictionary = walks.get("after_leave", {})
		var connected_walk: Dictionary = walks.get("connected", {})
		var connected_start: Dictionary = connected_walk.get("start", {})
		var connected_authority: Dictionary = connected_start.get("authority", {})
		_check(_live_browser_retry_ready(after_leave) and str(after_leave.get("source_session_id", "")) == "game-flow-" + str(connected_authority.get("main_id", "")), role + " ordinary leave receipt proves current own fenced retry action before Refresh/Back/Resume")
		for name: String in ["connected", "solo"]:
			_live_check_walk_receipt(role, name, admitted, name == "connected")


func _live_check_walk_receipt(role: String, name: String, admitted: Dictionary, connected: bool) -> void:
	var walks: Dictionary = _live_read(role + ".done").get("gameplay", {})
	var walk: Dictionary = walks.get(name, {})
	var start: Dictionary = walk.get("start", {})
	var end: Dictionary = walk.get("end", {})
	var authority: Dictionary = start.get("authority", {})
	var direction := _live_walk_vector_from(walk.get("direction", []))
	var displacement := _live_walk_vector_from(end.get("position", [])) - _live_walk_vector_from(start.get("position", []))
	_check(
		walk.get("action", "") == ("move_forward" if connected else "move_back")
		and bool(walk.get("connected", not connected)) == connected
		and bool(authority.get("network_active", not connected)) == connected
		and float(walk.get("walk_seconds", 6.0)) <= 5.0
		and direction.is_finite() and is_equal_approx(direction.length(), 1.0)
		and displacement.is_finite() and displacement.dot(direction) >= 1.0
		and float(walk.get("peak_speed_mps", 0.0)) > 0.1,
		role + " " + name + " receipt proves ordinary one-metre input walk in its original boundary")
	var generation_valid: bool = (
		int(authority.get("host_guest_id", 0)) == int(admitted.get("guest_peer_id", -1))
		and int(authority.get("host_guest_generation", 0)) == int(admitted.get("guest_generation", -1))
		if role == "host" else int(authority.get("peer_generation", 0)) == int(admitted.get("peer_generation", -1))
	)
	_check(
		bool(authority.get("authenticated", not connected)) == connected
		and not bool(authority.get("piloting", true))
		and (not connected or (generation_valid and int(authority.get("peer_id", 0)) == int(admitted.get("host_peer_id" if role == "host" else "peer_id", -1)))),
		role + " " + name + " preserves the actual admitted identity or cleared solo session")
	_check(_live_walk_sample_valid(start, admitted.get("player", {}), authority) and _live_walk_sample_valid(end, admitted.get("player", {}), authority), role + " " + name + " start and end retain the same supported actor and grants")
	var samples: Array = walk.get("samples", [])
	var settle: Array = walk.get("settle", [])
	var neutral: Array = walk.get("neutral", [])
	_check(not samples.is_empty() and not settle.is_empty() and neutral.size() == 12 and float(walk.get("settle_seconds", 6.0)) <= 5.0, role + " " + name + " contains actual movement, bounded continuous settling and twelve neutral observations")
	var previous_frame := int(start.get("frame", -1))
	var observed_peak := 0.0
	for sample: Dictionary in samples:
		_check(_live_walk_sample_valid(sample, admitted.get("player", {}), authority) and int(sample.get("frame", -1)) == previous_frame + 1 and sample.get("input", []) == [0.0, -1.0 if connected else 1.0] and _live_walk_vector_from(sample.get("velocity", [])).is_finite(), role + " " + name + " movement preserves every physics step's actual support/player/control/auth/grants")
		observed_peak = maxf(observed_peak, _live_walk_vector_from(sample.get("velocity", [])).length())
		previous_frame = int(sample.get("frame", -1))
	_check(observed_peak > 0.1, role + " " + name + " has measured movement velocity")
	_check(not samples.is_empty() and end == samples.back(), role + " " + name + " end is the last actual held-input physics sample")
	for sample: Dictionary in settle:
		_check(_live_walk_sample_valid(sample, admitted.get("player", {}), authority) and int(sample.get("frame", -1)) == previous_frame + 1 and sample.get("input", []) == [0.0, 0.0] and _live_walk_vector_from(sample.get("velocity", [])).is_finite(), role + " " + name + " settling preserves support/control/auth/identity/grants on every physics step")
		previous_frame = int(sample.get("frame", -1))
	var neutral_start: Dictionary = walk.get("neutral_start", {})
	_check(not settle.is_empty() and neutral_start == settle.back() and _live_walk_sample_valid(neutral_start, admitted.get("player", {}), authority) and _live_walk_vector_from(neutral_start.get("velocity", [])).length() <= 0.05, role + " " + name + " last settle sample starts neutral with original actor and ownership")
	var neutral_origin := _live_walk_vector_from(neutral_start.get("position", []))
	for sample: Dictionary in neutral:
		_check(_live_walk_sample_valid(sample, admitted.get("player", {}), authority) and int(sample.get("frame", -1)) == previous_frame + 1 and sample.get("input", []) == [0.0, 0.0] and _live_walk_vector_from(sample.get("velocity", [])).length() <= 0.05 and _live_walk_vector_from(sample.get("position", [])).distance_to(neutral_origin) <= 0.02, role + " " + name + " neutral sample retains every fresh physics step's released supported pose without drift")
		previous_frame = int(sample.get("frame", -1))


func _live_check_rejoin_receipts(host: Dictionary, guest: Dictionary) -> void:
	var host_second := _live_read("host.rejoined")
	var guest_second := _live_read("guest.rejoined")
	var first_cleared := _live_read("host.first_cleared")
	var second_cleared := _live_read("host.second_cleared")
	var requested := _live_read("guest.rejoin_requested")
	var ready := _live_read("host.ready")
	_check(_live_rejoin_tuple_fresh(host, host_second, true) and _live_rejoin_tuple_fresh(guest, guest_second), "both independent second admissions are fresh tuples without assuming generation increases for a changed peer ID")
	_check(int(host_second.get("guest_peer_id", 0)) == int(guest_second.get("peer_id", -1)) and int(host_second.get("guest_generation", 0)) == int(guest_second.get("peer_generation", -1)), "second host/guest receipts match the actual authenticated tuple")
	_check(host_second.get("player", {}) == host.get("player", {}) and guest_second.get("player", {}) == guest.get("player", {}) and int(host_second.get("pid", 0)) == int(host.get("pid", -1)) and int(guest_second.get("pid", 0)) == int(guest.get("pid", -1)), "both readmission actors retain original actual Main processes and Players")
	_check(not str(ready.get("session_id", "")).is_empty() and first_cleared.get("session_id", "") == ready.get("session_id") and host_second.get("session_id", "") == ready.get("session_id") and guest_second.get("session_id", "") == ready.get("session_id") and requested.get("session_id", "") == ready.get("session_id"), "readmission comes from the same live host LAN session discovered by a fresh actual Refresh")
	_check(bool(first_cleared.get("host_available", false)) and bool(first_cleared.get("authority_clear", false)) and int(first_cleared.get("occupancy", -1)) == 0 and int(first_cleared.get("guest_peer_id", 0)) == int(host.get("guest_peer_id", -1)) and not str(first_cleared.get("native_peer_id", "")).is_empty() and first_cleared.get("native_peer_id") == host_second.get("native_peer_id"), "first guest tuple retires completely while the original host native peer remains available")
	_check(bool(second_cleared.get("host_available", false)) and bool(second_cleared.get("authority_clear", false)) and int(second_cleared.get("guest_peer_id", 0)) == int(host_second.get("guest_peer_id", -1)) and int(second_cleared.get("guest_generation", 0)) == int(host_second.get("guest_generation", -1)), "second ordinary Disconnect retires the second host tuple and authority before host stops")
	var guard: Dictionary = second_cleared.get("guard", {})
	_check(bool(guard.get("valid", false)) and int(guard.get("samples", 0)) > 0, "independent physics guard observed original host availability throughout solo walking and rejoin")
	for receipt_name: String in ["guest.retired", "guest.second_retired"]:
		var retired := _live_read(receipt_name)
		_check(retired.get("player", {}) == guest.get("player", {}), receipt_name + " retains original supported Player")
		for key: String in ["native_closed", "peer_cleared", "api_offline", "session_inactive", "offer_empty", "admissions_empty", "authority_clear", "body_source_clear", "on_foot"]:
			_check(bool(retired.get(key, false)), receipt_name + " independently recorded " + key)
	var original_native := str(_live_read("guest.retired").get("native_peer_id", ""))
	_check(not original_native.is_empty() and not str(guest_second.get("native_peer_id", "")).is_empty() and original_native != str(guest_second.get("native_peer_id", "")) and bool(guest_second.get("old_native_closed", false)) and _live_read("guest.second_retired").get("native_peer_id", "") == guest_second.get("native_peer_id"), "second guest native peer differs from closed first peer and is itself closed by final ordinary Disconnect")
	for role: String in ["host", "guest"]:
		_live_check_walk_receipt(role, "rejoined_connected", _live_read(role + ".rejoined"), true)
	var walks: Dictionary = _live_read("guest.done").get("gameplay", {})
	_check(_live_browser_retry_ready(walks.get("after_rejoined_leave", {})), "second ordinary Disconnect presents its own current retired HUD cursor and usable browser retry action")
	_live_check_walk_receipt("guest", "final_solo", guest_second, false)


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
	return _live_departed_identity_clear(session, guest_id) and int(session.get_crew_role_snapshot().get("admitted_peer_count", -1)) == 0 and _live_game._network_remote_body_simulation.get_body_count() == 0


func _live_departed_identity_clear(session: NetworkEnetSessionAdapter, guest_id: int) -> bool:
	if guest_id in session.get_admitted_peer_ids():
		return false
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
	for entity_id in _live_game._network_remote_body_simulation.get_body_entity_ids():
		if int(_live_game._network_remote_body_simulation.get_body_record(entity_id).get("owner_peer_id", 0)) == guest_id:
			return false
	return true


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
		for role in (["cancel"] if _live_cancel else (["host", "guest", "candidate"] if _live_full else (["host", "guest", "guest2"] if _live_two_guests else ["host", "guest"]))):
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
	var label := "GAME_FLOW_LIVE_MENU_CANCEL" if _live_cancel else ("GAME_FLOW_LIVE_MENU_TWO_GUESTS" if _live_two_guests else "GAME_FLOW_LIVE_MENU_ONE_GUEST")
	if _live_full:
		label = "GAME_FLOW_LIVE_MENU_FULL"
	elif _live_gameplay:
		label = "GAME_FLOW_LIVE_MENU_ONE_GUEST_GAMEPLAY"
	if _live_rejoin:
		label = "GAME_FLOW_LIVE_MENU_DISCONNECT_REJOIN"
	if _live_stale:
		label = "GAME_FLOW_LIVE_MENU_STALE"
	if _live_cancel_rejoin:
		label = "GAME_FLOW_LIVE_MENU_CANCEL_REJOIN"
	if _live_no_answer:
		label = "GAME_FLOW_LIVE_MENU_NO_ANSWER"
	print(label + ": %d assertions, %d failures" % [_assertions, _failures.size()])
	if _failures.is_empty() and _live_role == "coordinator":
		print(label + "_TEST_OK")
	quit(0 if _failures.is_empty() else 1)
