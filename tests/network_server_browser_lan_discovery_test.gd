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
	_finish()


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
