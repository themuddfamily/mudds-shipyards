class_name NetworkTransportSecurity
extends RefCounted

## Detached transport admission/authentication boundary for multiplayer.
##
## The server owns peer generations and the session secret.  Clients receive
## an opaque HMAC token and may only send exact, bounded envelopes carrying
## that token.  This contract does not open sockets or replicate gameplay; a
## MultiplayerPeer adapter calls `accept_packet()` before forwarding a
## command to an authority ledger.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_transport_security_v1"
const PROTOCOL_ID: StringName = &"mudds_shipyards"
const MAX_PACKET_BYTES := 1024
const MAX_PAYLOAD_BYTES := 768
const MAX_STREAM_ID_LENGTH := 64
const MAX_TOKEN_BYTES := 32
const MAX_SAFE_INTEGER := 9_007_199_254_740_991

const _PACKET_KEYS := [
	"schema_version", "protocol_id", "session_generation", "peer_id",
	"peer_generation", "stream_id", "sequence", "auth_token", "payload",
]

var _authority_peer_id := 1
var _protocol_version := 1
var _session_generation := 1
var _secret: PackedByteArray = PackedByteArray()
var _peers: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_session_generation: int = 1,
	p_secret: String = "mudds-shipyards-development-secret"
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_protocol_version = maxi(1, p_protocol_version)
	_session_generation = maxi(1, p_session_generation)
	_secret = p_secret.to_utf8_buffer()
	_last_result = _result(false, &"uninitialized")


## Registers a peer generation before its transport is admitted.  Only the
## server may create or replace a peer record; generation reuse is rejected.
func register_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_positive(peer_id) or not _valid_positive(peer_generation):
		return _remember(_result(false, &"invalid_peer_identity"))
	var previous: Dictionary = _peers.get(peer_id, {})
	if not previous.is_empty() and peer_generation <= int(previous.get("peer_generation", 0)):
		return _remember(_result(false, &"stale_peer_generation"))
	var token_generation := int(previous.get("token_generation", 0)) + 1
	var record := {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"token_generation": token_generation,
		"auth_token": _make_token(peer_id, peer_generation, token_generation),
		"streams": {},
		"active": true,
	}
	_peers[peer_id] = record
	return _remember(_result(true, &"peer_registered", {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"auth_token": record.auth_token,
	}))


## Issues the current generation's token through a server-only boundary.  The
## token is bound to peer, generation, session, and a one-up token generation.
func issue_auth_token(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _peers.has(peer_id):
		return _remember(_result(false, &"unknown_peer"))
	var peer := _peers[peer_id] as Dictionary
	if int(peer.get("peer_generation", 0)) != peer_generation:
		return _remember(_result(false, &"stale_peer_generation"))
	var token_generation := int(peer.get("token_generation", 0)) + 1
	peer["token_generation"] = token_generation
	peer["auth_token"] = _make_token(peer_id, peer_generation, token_generation)
	peer["streams"] = {}
	return _remember(_result(true, &"auth_token_issued", {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"token_generation": token_generation,
		"auth_token": peer.auth_token,
	}))


## Serializes a packet with the peer's current token.  It is a client adapter
## helper only; the server still validates the resulting envelope.
func make_packet(
	peer_id: int,
	peer_generation: int,
	stream_id: StringName,
	sequence: int,
	payload: Dictionary
) -> Dictionary:
	if not _peers.has(peer_id):
		return {}
	var peer := _peers[peer_id] as Dictionary
	return {
		"schema_version": SCHEMA_VERSION,
		"protocol_id": PROTOCOL_ID,
		"session_generation": _session_generation,
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"stream_id": stream_id,
		"sequence": sequence,
		"auth_token": peer.get("auth_token", ""),
		"payload": payload.duplicate(true),
	}.duplicate(true)


## Validates an authenticated transport packet before it reaches gameplay.
## Replay high-water marks advance only after every schema, size, generation,
## source, and token check passes.
func accept_packet(source_peer_id: int, packet: Dictionary) -> Dictionary:
	var checked := _validate_packet(source_peer_id, packet)
	if not bool(checked.get("valid", false)):
		return _remember(_result(false, checked.get("status", &"invalid_packet")))
	var peer_id := int(packet.get("peer_id", 0))
	var peer := _peers[peer_id] as Dictionary
	var stream_id := StringName(packet.get("stream_id", ""))
	var streams := peer.get("streams", {}) as Dictionary
	var sequence := int(packet.get("sequence", -1))
	var previous := int(streams.get(stream_id, -1))
	if sequence <= previous:
		return _remember(_result(false, &"replayed_or_out_of_order"))
	streams[stream_id] = sequence
	peer["streams"] = streams
	return _remember(_result(true, &"packet_accepted", {
		"peer_id": peer_id,
		"stream_id": stream_id,
		"sequence": sequence,
		"payload": (packet.get("payload", {}) as Dictionary).duplicate(true),
	}))


func rotate_session(source_peer_id: int, next_session_generation: int = -1) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var next := _session_generation + 1 if next_session_generation == -1 else next_session_generation
	if not _valid_positive(next) or next <= _session_generation:
		return _remember(_result(false, &"invalid_session_generation"))
	_session_generation = next
	for peer_variant in _peers.values():
		var peer := peer_variant as Dictionary
		peer["streams"] = {}
	return _remember(_result(true, &"session_rotated", {"session_generation": _session_generation}))


func get_peer(peer_id: int) -> Dictionary:
	if not _peers.has(peer_id):
		return {}
	return (_peers[peer_id] as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var peers: Array = []
	for peer_variant in _peers.values():
		var peer := (peer_variant as Dictionary).duplicate(true)
		peer.erase("auth_token")
		peers.append(peer)
	peers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("peer_id", 0)) < int(right.get("peer_id", 0))
	)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"session_generation": _session_generation,
		"max_packet_bytes": MAX_PACKET_BYTES,
		"peers": peers,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": not _secret.is_empty() and _protocol_version > 0,
		"server_owns_token_generation": true,
		"server_owns_replay_cursor": true,
		"exact_packet_schema": true,
		"bounded_packet_bytes": true,
		"forged_source_rejected": true,
		"stale_generation_rejected": true,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_packet(source_peer_id: int, packet: Dictionary) -> Dictionary:
	if source_peer_id <= 0:
		return {"valid": false, "status": &"invalid_source_peer"}
	if packet.size() != _PACKET_KEYS.size():
		return {"valid": false, "status": &"invalid_packet_schema"}
	for key in _PACKET_KEYS:
		if not packet.has(key):
			return {"valid": false, "status": &"invalid_packet_schema"}
	var encoded := JSON.stringify(packet)
	var encoded_bytes := encoded.to_utf8_buffer()
	if encoded.is_empty() or encoded_bytes.size() > MAX_PACKET_BYTES:
		return {"valid": false, "status": &"packet_too_large"}
	var payload_value: Variant = packet.get("payload")
	if not payload_value is Dictionary:
		return {"valid": false, "status": &"invalid_payload"}
	var payload_bytes := JSON.stringify(payload_value).to_utf8_buffer()
	if payload_bytes.size() > MAX_PAYLOAD_BYTES:
		return {"valid": false, "status": &"payload_too_large"}
	for key in ["schema_version", "session_generation", "peer_id", "peer_generation", "sequence"]:
		if not packet.get(key) is int:
			return {"valid": false, "status": &"invalid_packet_schema"}
	if not packet.get("protocol_id") is String and not packet.get("protocol_id") is StringName:
		return {"valid": false, "status": &"invalid_packet_schema"}
	if not packet.get("stream_id") is String and not packet.get("stream_id") is StringName:
		return {"valid": false, "status": &"invalid_packet_schema"}
	if not packet.get("auth_token") is String:
		return {"valid": false, "status": &"invalid_auth_token"}
	if int(packet.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"valid": false, "status": &"schema_version_mismatch"}
	if StringName(packet.get("protocol_id")) != PROTOCOL_ID:
		return {"valid": false, "status": &"protocol_mismatch"}
	if int(packet.get("session_generation", 0)) != _session_generation:
		return {"valid": false, "status": &"stale_session_generation"}
	var peer_id := int(packet.get("peer_id", 0))
	if source_peer_id != peer_id:
		return {"valid": false, "status": &"spoofed_peer"}
	if not _peers.has(peer_id):
		return {"valid": false, "status": &"unknown_peer"}
	var peer := _peers[peer_id] as Dictionary
	if int(packet.get("peer_generation", 0)) != int(peer.get("peer_generation", 0)):
		return {"valid": false, "status": &"stale_peer_generation"}
	var stream_text := String(packet.get("stream_id", ""))
	if stream_text.is_empty() or stream_text.length() > MAX_STREAM_ID_LENGTH:
		return {"valid": false, "status": &"invalid_stream_id"}
	var sequence := int(packet.get("sequence", -1))
	if not _valid_nonnegative(sequence):
		return {"valid": false, "status": &"invalid_sequence"}
	var token := String(packet.get("auth_token", ""))
	if token.length() != MAX_TOKEN_BYTES * 2 or not _constant_time_equal(token, String(peer.get("auth_token", ""))):
		return {"valid": false, "status": &"invalid_auth_token"}
	return {"valid": true, "status": &"packet_valid"}


func _make_token(peer_id: int, peer_generation: int, token_generation: int) -> String:
	var material := "%s|%d|%d|%d|%d|%s" % [
		String(PROTOCOL_ID), _protocol_version, _session_generation,
		peer_id, peer_generation, token_generation,
	]
	var crypto := Crypto.new()
	return crypto.hmac_digest(
		HashingContext.HASH_SHA256,
		_secret,
		material.to_utf8_buffer()
	).hex_encode()


func _constant_time_equal(left: String, right: String) -> bool:
	if left.length() != right.length():
		return false
	var difference := 0
	for index in left.length():
		difference |= left.unicode_at(index) ^ right.unicode_at(index)
	return difference == 0


func _valid_positive(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, details: Dictionary = {}) -> Dictionary:
	var output := {"accepted": accepted, "status": status}
	for key in details:
		output[key] = details[key]
	return output.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
