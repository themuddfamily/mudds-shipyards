class_name NetworkServerBrowserLanDiscovery
extends Node

## LAN session discovery feeding the server browser's detached directory.
##
## A hosting game binds the fixed discovery port and answers probes; a browsing
## game sends one probe (UDP broadcast plus loopback, so a host on the same PC
## is found too) from an ephemeral port and collects answers for a short window.
## The collected rows use NetworkServerBrowser's entry shape and are published
## by the caller through the session adapter's directory, which stays the only
## record authority. Endpoints are kept here, beside the directory, because the
## directory deliberately never accepts an address as authoritative data.
##
## Every packet is size-bounded, parsed as JSON, type-checked and nonce-matched;
## a malformed reply is dropped without affecting any other host's row.

signal discovery_completed(request_id: int, entries: Array)

const DISCOVERY_PORT := 27102
const PROTOCOL_MAGIC := "MUDDS_LAN_DISCOVERY"
const PROTOCOL_REVISION := 1
const MAX_PACKET_BYTES := 1024
const MAX_HOSTS := 64
const MAX_TITLE_LENGTH := 64
const MAX_PLAYERS := 256
const DEFAULT_WINDOW_SECONDS := 0.8
const MIN_WINDOW_SECONDS := 0.05
const MAX_WINDOW_SECONDS := 5.0
const BROADCAST_ADDRESS := "255.255.255.255"
const LOOPBACK_ADDRESS := "127.0.0.1"
const REGION_ID := "LAN"
const HOST_PEER_ID := 1

## Overridable for tests; production uses the fixed port and both targets.
var discovery_port := DISCOVERY_PORT
var probe_targets: PackedStringArray = PackedStringArray([BROADCAST_ADDRESS, LOOPBACK_ADDRESS])

var _responder: PacketPeerUDP
var _responder_session_id := ""
var _responder_announce: Dictionary = {}
var _capacity_provider := Callable()

var _prober: PacketPeerUDP
var _request_id := 0
var _probe_nonce := ""
var _probe_sent_usec := 0
var _window_remaining := 0.0
var _replies: Dictionary = {}
var _endpoints: Dictionary = {}
var _last_endpoints: Dictionary = {}


func _process(delta: float) -> void:
	poll(delta)


func _exit_tree() -> void:
	stop_responding()
	cancel_refresh()


## Starts answering probes for a hosted session. `announce` carries title,
## game_port, protocol_version and build_version; `capacity_provider` returns
## {occupancy, max_players} each time a probe is answered so rows stay current.
func start_responding(announce: Dictionary, capacity_provider: Callable = Callable()) -> Dictionary:
	stop_responding()
	var game_port := int(announce.get("game_port", 0))
	var title := _clean_title(announce.get("title", ""))
	if game_port < 1 or game_port > 65535:
		return {"accepted": false, "status": &"invalid_game_port"}
	if title.is_empty():
		return {"accepted": false, "status": &"invalid_title"}
	var responder := PacketPeerUDP.new()
	var bind_error := responder.bind(discovery_port, "*")
	if bind_error != OK:
		responder.close()
		# Hosting still works; only LAN discovery is unavailable (for example a
		# second host on the same PC already owns the discovery port).
		return {"accepted": false, "status": &"discovery_port_unavailable", "error": bind_error}
	_responder = responder
	_responder_session_id = "lan_%08x%08x" % [randi(), randi()]
	_responder_announce = {
		"title": title,
		"game_port": game_port,
		"protocol_version": int(announce.get("protocol_version", 1)),
		"build_version": int(announce.get("build_version", 1)),
	}
	_capacity_provider = capacity_provider
	return {"accepted": true, "status": &"responding", "session_id": _responder_session_id, "port": discovery_port}


func stop_responding() -> void:
	if _responder != null:
		_responder.close()
	_responder = null
	_responder_session_id = ""
	_responder_announce = {}
	_capacity_provider = Callable()


func is_responding() -> bool:
	return _responder != null and _responder.is_bound()


## Sends one probe and collects replies for `window_seconds`. Starting a new
## refresh supersedes the previous one; only the newest request completes.
func begin_refresh(window_seconds: float = DEFAULT_WINDOW_SECONDS) -> int:
	cancel_refresh()
	_request_id += 1
	var prober := PacketPeerUDP.new()
	prober.set_broadcast_enabled(true)
	if prober.bind(0, "*") != OK:
		prober.close()
		_window_remaining = 0.0
		_finish_refresh.call_deferred(_request_id)
		return _request_id
	_prober = prober
	_probe_nonce = "%08x%08x" % [randi(), randi()]
	_replies.clear()
	_endpoints.clear()
	_window_remaining = clampf(window_seconds, MIN_WINDOW_SECONDS, MAX_WINDOW_SECONDS)
	var probe := JSON.stringify({
		"magic": PROTOCOL_MAGIC,
		"revision": PROTOCOL_REVISION,
		"type": "probe",
		"nonce": _probe_nonce,
	}).to_utf8_buffer()
	_probe_sent_usec = Time.get_ticks_usec()
	for target in probe_targets:
		# A target that cannot be reached (no broadcast route) is not fatal; the
		# other target may still find hosts.
		if _prober.set_dest_address(target, discovery_port) == OK:
			_prober.put_packet(probe)
	return _request_id


func cancel_refresh() -> void:
	if _prober != null:
		_prober.close()
	_prober = null
	_probe_nonce = ""
	_window_remaining = 0.0
	_replies.clear()
	_endpoints.clear()


func is_refreshing() -> bool:
	return _prober != null


func get_request_id() -> int:
	return _request_id


## {address, port} for a session found by the latest completed refresh, or {}.
func get_endpoint(session_id: StringName) -> Dictionary:
	var endpoint: Variant = _last_endpoints.get(String(session_id))
	return (endpoint as Dictionary).duplicate(true) if endpoint is Dictionary else {}


## Drives both roles. Called every frame from `_process`; tests may call it
## directly with a synthetic delta.
func poll(delta: float = 0.0) -> void:
	_poll_responder()
	if _prober == null:
		return
	while _prober != null and _prober.get_available_packet_count() > 0:
		var packet := _prober.get_packet()
		if _prober.get_packet_error() != OK:
			continue
		_accept_reply(packet, _prober.get_packet_ip())
	_window_remaining -= maxf(delta, 0.0)
	if _window_remaining <= 0.0:
		_finish_refresh(_request_id)


func _poll_responder() -> void:
	if _responder == null:
		return
	while _responder != null and _responder.get_available_packet_count() > 0:
		var packet := _responder.get_packet()
		if _responder.get_packet_error() != OK:
			continue
		var sender_ip := _responder.get_packet_ip()
		var sender_port := _responder.get_packet_port()
		var message := _parse(packet)
		if message.is_empty() or str(message.get("type", "")) != "probe":
			continue
		var nonce := str(message.get("nonce", ""))
		if not _valid_nonce(nonce) or sender_ip.is_empty() or sender_port <= 0:
			continue
		var reply := _build_announce(nonce)
		if reply.is_empty():
			continue
		if _responder.set_dest_address(sender_ip, sender_port) == OK:
			_responder.put_packet(JSON.stringify(reply).to_utf8_buffer())


func _build_announce(nonce: String) -> Dictionary:
	var occupancy := 1
	var max_players := 4
	if _capacity_provider.is_valid():
		var capacity: Variant = _capacity_provider.call()
		if capacity is Dictionary:
			occupancy = int((capacity as Dictionary).get("occupancy", occupancy))
			max_players = int((capacity as Dictionary).get("max_players", max_players))
	max_players = clampi(max_players, 1, MAX_PLAYERS)
	occupancy = clampi(occupancy, 0, max_players)
	return {
		"magic": PROTOCOL_MAGIC,
		"revision": PROTOCOL_REVISION,
		"type": "announce",
		"nonce": nonce,
		"session_id": _responder_session_id,
		"title": _responder_announce.get("title", ""),
		"game_port": int(_responder_announce.get("game_port", 0)),
		"player_count": occupancy,
		"max_players": max_players,
		"protocol_version": int(_responder_announce.get("protocol_version", 1)),
		"build_version": int(_responder_announce.get("build_version", 1)),
	}


func _accept_reply(packet: PackedByteArray, sender_ip: String) -> void:
	if _replies.size() >= MAX_HOSTS or sender_ip.is_empty():
		return
	var message := _parse(packet)
	if message.is_empty() or str(message.get("type", "")) != "announce":
		return
	if str(message.get("nonce", "")) != _probe_nonce:
		return
	var session_id := str(message.get("session_id", ""))
	if session_id.is_empty() or session_id.length() > 64 or not session_id.is_valid_identifier():
		return
	if _replies.has(session_id):
		return
	var title := _clean_title(message.get("title", ""))
	var game_port := _as_int(message.get("game_port"))
	var player_count := _as_int(message.get("player_count"))
	var max_players := _as_int(message.get("max_players"))
	var protocol_version := _as_int(message.get("protocol_version"))
	var build_version := _as_int(message.get("build_version"))
	if title.is_empty() or game_port < 1 or game_port > 65535:
		return
	if max_players < 1 or max_players > MAX_PLAYERS or player_count < 0 or player_count > max_players:
		return
	if protocol_version < 0 or build_version < 0:
		return
	var ping_ms := clampi(int((Time.get_ticks_usec() - _probe_sent_usec) / 1000), 0, 60_000)
	_replies[session_id] = {
		"session_id": session_id,
		"host_peer_id": HOST_PEER_ID,
		"title": title,
		"region_id": REGION_ID,
		"ping_ms": ping_ms,
		"player_count": player_count,
		"max_players": max_players,
		"available_slots": max_players - player_count,
		"capacity_generation": 1,
		"protocol_version": protocol_version,
		"build_version": build_version,
	}
	_endpoints[session_id] = {"address": sender_ip, "port": game_port}


func _finish_refresh(request_id: int) -> void:
	if request_id != _request_id:
		return
	var ids := _replies.keys()
	ids.sort()
	var entries: Array = []
	for session_id in ids:
		entries.append((_replies[session_id] as Dictionary).duplicate(true))
	_last_endpoints = _endpoints.duplicate(true)
	if _prober != null:
		_prober.close()
	_prober = null
	_probe_nonce = ""
	_window_remaining = 0.0
	_replies.clear()
	_endpoints.clear()
	discovery_completed.emit(request_id, entries)


static func _parse(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES:
		return {}
	var text := packet.get_string_from_utf8()
	if text.is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	var message := parser.data as Dictionary
	if str(message.get("magic", "")) != PROTOCOL_MAGIC:
		return {}
	if _as_int(message.get("revision")) != PROTOCOL_REVISION:
		return {}
	return message


static func _valid_nonce(nonce: String) -> bool:
	return nonce.length() >= 8 and nonce.length() <= 32 and nonce.is_valid_hex_number()


static func _clean_title(value: Variant) -> String:
	if not (value is String or value is StringName):
		return ""
	var text := String(value).strip_edges()
	return text if text.length() <= MAX_TITLE_LENGTH else text.left(MAX_TITLE_LENGTH).strip_edges()


## JSON numbers arrive as floats; accept only integral finite values.
static func _as_int(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float and not is_nan(float(value)) and not is_inf(float(value)) \
			and float(value) == floorf(float(value)) and absf(float(value)) < 1.0e9:
		return int(value)
	return -1
