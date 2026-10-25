extends SceneTree

## LAN discovery round trip on loopback: a hosting responder answers a
## browser's probe, the collected rows are accepted by NetworkServerBrowser as a
## directory snapshot, the join endpoint is the answering address, junk packets
## are ignored, and a stopped host is no longer found.

const Discovery := preload("res://scripts/network/network_server_browser_lan_discovery.gd")
const ServerBrowser := preload("res://scripts/network/network_server_browser.gd")

## Off the production port so a running game on this machine cannot interfere.
const TEST_DISCOVERY_PORT := 27192
const TEST_GAME_PORT := 27191
const MAX_POLL_FRAMES := 240
const AUTOMATIC_COMPLETION_BUDGET_MS := 2000
const PAUSED_COMPLETION_LABEL := "paused automatic LAN refresh completes within 2 seconds"


class PauseHeartbeat extends Node:
	var ticks := 0

	func _process(_delta: float) -> void:
		ticks += 1

var _assertions := 0
var _failures := PackedStringArray()
var _completions: Array = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Discovery.new() as NetworkServerBrowserLanDiscovery
	var browser := Discovery.new() as NetworkServerBrowserLanDiscovery
	for node: NetworkServerBrowserLanDiscovery in [host, browser]:
		node.discovery_port = TEST_DISCOVERY_PORT
		node.probe_targets = PackedStringArray(["127.0.0.1"])
		node.set_process(false)
		root.add_child(node)
	browser.discovery_completed.connect(func(request_id: int, entries: Array) -> void:
		_completions.append({"request_id": request_id, "entries": entries})
	)
	var capacity := {"occupancy": 2, "max_players": 4}
	var responding := host.start_responding({
		"title": "Loopback's shipyard",
		"game_port": TEST_GAME_PORT,
		"protocol_version": 1,
		"build_version": 1,
	}, func() -> Dictionary: return capacity)
	_check(bool(responding.accepted) and host.is_responding(), "the host binds the discovery port and answers probes")
	var session_id := StringName(str(responding.get("session_id", "")))

	var first_request := browser.begin_refresh(0.5)
	var entries := await _await_completion(host, browser, first_request)
	_check(entries.size() == 1, "one hosted session is discovered over loopback")
	if entries.size() == 1:
		var entry := entries[0] as Dictionary
		_check(StringName(str(entry.session_id)) == session_id, "the row carries the host's session id")
		_check(str(entry.title) == "Loopback's shipyard" and str(entry.region_id) == "LAN", "the row shows the host title in the LAN region")
		_check(int(entry.player_count) == 2 and int(entry.max_players) == 4 and int(entry.available_slots) == 2, "live capacity comes from the host's provider")
		_check(int(entry.ping_ms) >= 0, "a measured ping is recorded")
		var directory := ServerBrowser.new(1)
		var published: Dictionary = directory.publish_snapshot(1, 1, 1, entries)
		_check(bool(published.accepted), "discovered rows are a valid server-browser directory snapshot")
		_check(directory.query().size() == 1, "the directory lists the discovered host")
		var endpoint := browser.get_endpoint(session_id)
		_check(str(endpoint.get("address", "")) == "127.0.0.1" and int(endpoint.get("port", 0)) == TEST_GAME_PORT, "joining uses the answering address and the host's game port")

	# Junk sent at the responder is dropped without breaking the next refresh.
	var junk := PacketPeerUDP.new()
	junk.set_dest_address("127.0.0.1", TEST_DISCOVERY_PORT)
	junk.put_packet("not json".to_utf8_buffer())
	junk.put_packet(JSON.stringify({"magic": "MUDDS_LAN_DISCOVERY", "revision": 1, "type": "probe", "nonce": "zz"}).to_utf8_buffer())
	junk.close()
	var second_request := browser.begin_refresh(0.5)
	var after_junk := await _await_completion(host, browser, second_request)
	_check(after_junk.size() == 1, "malformed packets do not stop the host answering real probes")

	# A superseded refresh never completes; only the newest request reports.
	_completions.clear()
	var superseded := browser.begin_refresh(0.5)
	var newest := browser.begin_refresh(0.5)
	await _await_completion(host, browser, newest)
	_check(_completions.all(func(item: Variant) -> bool: return int((item as Dictionary).request_id) != superseded), "a superseded refresh is never reported")

	host.stop_responding()
	_check(not host.is_responding(), "stopping the session stops answering")
	var third_request := browser.begin_refresh(0.3)
	var after_stop := await _await_completion(host, browser, third_request)
	_check(after_stop.is_empty(), "a stopped host is no longer discovered")
	_check(browser.get_endpoint(session_id).is_empty(), "stale endpoints are dropped with the stale rows")

	host.queue_free()
	browser.queue_free()
	await process_frame
	_run_expiry_boundaries()
	await _run_paused_round_trip()
	_finish()


## Keep the production 30-second policy intact while testing exact boundaries
## from explicit monotonic packet observations, without sleeping for each case.
func _run_expiry_boundaries() -> void:
	var browser := Discovery.new() as NetworkServerBrowserLanDiscovery
	browser.set_process(false)
	browser.probe_targets = PackedStringArray()
	var expirations: Array = []
	browser.listings_expired.connect(func(request_id: int, session_ids: Array) -> void:
		expirations.append({"request_id": request_id, "session_ids": session_ids})
	)
	var request_id := browser.begin_refresh(0.5)
	var base_usec := Time.get_ticks_usec()
	var old_packet := _expiry_announce(browser._probe_nonce, "lan_older")
	var newer_packet := _expiry_announce(browser._probe_nonce, "lan_newer")
	browser._accept_reply(old_packet, "127.0.0.1", base_usec)
	# A later valid duplicate is a real observation; malformed duplicates cannot
	# extend the deadline simply because their nonce/session id matches.
	browser._accept_reply(old_packet, "127.0.0.1", base_usec + 1_000_000)
	browser._accept_reply(newer_packet, "127.0.0.2", base_usec + 5_000_000)
	var malformed: Dictionary = JSON.parse_string(old_packet.get_string_from_utf8())
	malformed["game_port"] = 0
	browser._accept_reply(JSON.stringify(malformed).to_utf8_buffer(), "127.0.0.1", base_usec + 8_000_000)
	browser._finish_refresh(request_id)
	_check(browser.expire_stale(base_usec + 30_999_999).is_empty(), "LAN reply remains fresh one microsecond before its 30-second deadline")
	var expired := browser.expire_stale(base_usec + 31_000_000)
	_check(expired == [&"lan_older"] and browser.get_endpoint(&"lan_older").is_empty(), "LAN endpoint expires exactly 30 seconds after its last valid reply")
	_check(not browser.get_endpoint(&"lan_newer").is_empty(), "expiring an older endpoint preserves a separately observed fresh host")
	_check(browser.is_discovered_session(&"lan_older"), "expired LAN identity remains recognized for delayed join refusal")
	_check(expirations.size() == 1 and int(expirations[0].request_id) == request_id
		and expirations[0].session_ids == [&"lan_older"], "expiry reports only the affected host with its completed refresh generation")
	browser.expire_stale(base_usec + 31_000_000)
	_check(expirations.size() == 1, "an expired endpoint is retired once")
	var refreshed_request := browser.begin_refresh(0.5)
	var fresh_packet := _expiry_announce(browser._probe_nonce, "lan_older")
	browser._accept_reply(fresh_packet, "127.0.0.1", base_usec + 32_000_000)
	browser._finish_refresh(refreshed_request)
	browser._finish_refresh(request_id)
	_check(not browser.get_endpoint(&"lan_older").is_empty()
		and browser.get_endpoint(&"lan_newer").is_empty(), "a new refresh restores the live endpoint and an old completion cannot resurrect its rows")
	_check(browser.expire_stale(base_usec + 61_999_999).is_empty(), "a fresh reply starts its own full 30-second lifetime")
	_check(browser.expire_stale(base_usec + 62_000_000) == [&"lan_older"]
		and int(expirations.back().request_id) == refreshed_request, "renewed listing expires at its new deadline under the new refresh generation")
	browser.free()


func _expiry_announce(nonce: String, session_id: String) -> PackedByteArray:
	return JSON.stringify({
		"magic": Discovery.PROTOCOL_MAGIC,
		"revision": Discovery.PROTOCOL_REVISION,
		"type": "announce", "nonce": nonce, "session_id": session_id,
		"title": "Expiry boundary host", "game_port": TEST_GAME_PORT,
		"player_count": 1, "max_players": 4,
		"protocol_version": 1, "build_version": 1,
	}).to_utf8_buffer()


## Exercise the production automatic clock, including both paused responder and
## paused browser. The earlier packet tests intentionally retain manual polling.
func _run_paused_round_trip() -> void:
	var previous_paused := paused
	var previous_mouse_mode := Input.mouse_mode
	var heartbeat := PauseHeartbeat.new()
	var host := Discovery.new() as NetworkServerBrowserLanDiscovery
	var browser := Discovery.new() as NetworkServerBrowserLanDiscovery
	root.add_child(heartbeat)
	for node: NetworkServerBrowserLanDiscovery in [host, browser]:
		node.discovery_port = TEST_DISCOVERY_PORT
		node.probe_targets = PackedStringArray(["127.0.0.1"])
		root.add_child(node)
	var automatic_completions: Array = []
	browser.discovery_completed.connect(func(request_id: int, entries: Array) -> void:
		automatic_completions.append({"request_id": request_id, "entries": entries})
	)
	var capacity := {"occupancy": 3, "max_players": 5}
	var responding := host.start_responding({
		"title": "Paused host's shipyard",
		"game_port": TEST_GAME_PORT,
		"protocol_version": 1,
		"build_version": 1,
	}, func() -> Dictionary: return capacity)
	_check(bool(responding.accepted), "automatic paused fixture binds the responder")
	if not bool(responding.accepted):
		_cleanup_paused_fixture(host, browser, heartbeat, previous_paused, previous_mouse_mode)
		return
	var session_id := StringName(str(responding.get("session_id", "")))
	paused = true
	var frozen_ticks := heartbeat.ticks
	var request_id := browser.begin_refresh(0.5)
	var completion := await _await_automatic_completion(automatic_completions, request_id)
	_check(not completion.is_empty(), PAUSED_COMPLETION_LABEL)
	if completion.is_empty():
		# One expected pre-fix diagnostic, with sockets and global state restored.
		_cleanup_paused_fixture(host, browser, heartbeat, previous_paused, previous_mouse_mode)
		return
	var entries := completion.get("entries", []) as Array
	_check(entries.size() == 1, "automatic refresh discovers the paused host over real loopback UDP")
	if entries.size() == 1:
		var entry := entries[0] as Dictionary
		_check(StringName(str(entry.session_id)) == session_id
			and str(entry.title) == "Paused host's shipyard"
			and str(entry.region_id) == "LAN", "paused automatic result retains the advertised host row")
		_check(int(entry.player_count) == 3 and int(entry.max_players) == 5
			and int(entry.available_slots) == 2, "paused automatic result reports live host capacity")
		var endpoint := browser.get_endpoint(session_id)
		_check(str(endpoint.get("address", "")) == "127.0.0.1"
			and int(endpoint.get("port", 0)) == TEST_GAME_PORT, "paused automatic result retains the answering join endpoint")
	_check(paused and heartbeat.ticks == frozen_ticks, "ordinary gameplay heartbeat remains frozen during discovery")
	host.stop_responding()
	var empty_request := browser.begin_refresh(0.3)
	var empty_completion := await _await_automatic_completion(automatic_completions, empty_request)
	_check(not empty_completion.is_empty(), "paused automatic refresh completes after the host stops")
	if empty_completion.is_empty():
		_cleanup_paused_fixture(host, browser, heartbeat, previous_paused, previous_mouse_mode)
		return
	_check((empty_completion.get("entries", []) as Array).is_empty()
		and browser.get_endpoint(session_id).is_empty(), "paused refresh drops stopped host rows and endpoints")
	var cancelled_request := browser.begin_refresh(0.3)
	browser.cancel_refresh()
	var cancellation_deadline := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < cancellation_deadline:
		await process_frame
	_check(not browser.is_refreshing()
		and automatic_completions.all(func(item: Variant) -> bool:
			return int((item as Dictionary).request_id) != cancelled_request), "cancelled paused refresh never completes")
	_check(paused and heartbeat.ticks == frozen_ticks, "gameplay stays paused through stopped-host refresh and cancellation")
	_cleanup_paused_fixture(host, browser, heartbeat, previous_paused, previous_mouse_mode)
	var released_port := PacketPeerUDP.new()
	_check(released_port.bind(TEST_DISCOVERY_PORT, "*") == OK, "paused fixture teardown releases its UDP responder port")
	released_port.close()
	_check(paused == previous_paused and Input.mouse_mode == previous_mouse_mode, "paused fixture restores prior pause and cursor state")


func _await_automatic_completion(completions: Array, request_id: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + AUTOMATIC_COMPLETION_BUDGET_MS
	while Time.get_ticks_msec() < deadline:
		for item: Dictionary in completions:
			if int(item.request_id) == request_id:
				return item
		await process_frame
	return {}


func _cleanup_paused_fixture(host: NetworkServerBrowserLanDiscovery,
		browser: NetworkServerBrowserLanDiscovery, heartbeat: Node,
		previous_paused: bool, previous_mouse_mode: int) -> void:
	host.stop_responding()
	browser.cancel_refresh()
	host.free()
	browser.free()
	heartbeat.free()
	paused = previous_paused
	Input.mouse_mode = previous_mouse_mode


func _await_completion(host: NetworkServerBrowserLanDiscovery, browser: NetworkServerBrowserLanDiscovery, request_id: int) -> Array:
	for _frame in MAX_POLL_FRAMES:
		host.poll(0.0)
		browser.poll(1.0 / 60.0)
		for item: Dictionary in _completions:
			if int(item.request_id) == request_id:
				return item.entries as Array
		await process_frame
	_check(false, "refresh %d completed within the poll budget" % request_id)
	return []


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("NETWORK_SERVER_BROWSER_LAN_DISCOVERY_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("NETWORK_SERVER_BROWSER_LAN_DISCOVERY_TEST_FAILED: %d/%d assertions failed" % [_failures.size(), _assertions])
	for failure in _failures:
		printerr(" - ", failure)
	quit(1)
