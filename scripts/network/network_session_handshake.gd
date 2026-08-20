class_name NetworkSessionHandshake
extends RefCounted

## Server-owned protocol/package compatibility gate for multiplayer sessions.
##
## This detached contract runs before a peer is admitted to a session. It
## validates the exact wire schema, protocol identity/version, authored package
## generation, and session generation. It does not open a MultiplayerPeer,
## load a scene, or replicate gameplay state; a transport/session adapter owns
## those operations after this gate accepts a peer.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_session_handshake_v1"
const PROTOCOL_ID: StringName = &"mudds_shipyards"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_PEERS := 64

const _WIRE_KEYS := [
	"schema_version", "peer_id", "peer_generation", "protocol_id",
	"protocol_version", "package_generation", "session_generation",
]

var _authority_peer_id := 1
var _protocol_version := 1
var _package_generation := 1
var _session_generation := 1
var _event_sequence := 0
var _peers: Dictionary = {}
var _highest_peer_generation: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_package_generation: int = 1,
	p_session_generation: int = 1
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_protocol_version = maxi(1, p_protocol_version)
	_package_generation = maxi(1, p_package_generation)
	_session_generation = maxi(1, p_session_generation)
	_last_result = _result(false, &"uninitialized")


## Creates a detached client hello. The server remains the authority for all
## values and must validate this dictionary through accept_hello().
static func create_hello(
	p_peer_id: int,
	p_peer_generation: int,
	p_protocol_version: int,
	p_package_generation: int,
	p_session_generation: int,
	p_schema_version: int = SCHEMA_VERSION
) -> Dictionary:
	return {
		"schema_version": p_schema_version,
		"peer_id": p_peer_id,
		"peer_generation": p_peer_generation,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": p_protocol_version,
		"package_generation": p_package_generation,
		"session_generation": p_session_generation,
	}.duplicate(true)


func get_server_offer() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
	}.duplicate(true)


## The transport supplies source_peer_id; a packet cannot authenticate a
## different peer by changing its peer_id field. A newer peer generation may
## replace a disconnected/reconnected transport, but equal or older
## generations are stale and cannot resurrect an old session attachment.
func accept_hello(source_peer_id: int, wire: Dictionary) -> Dictionary:
	var checked := _decode_hello(wire)
	if not checked.valid:
		return _remember(_result(false, &"invalid_hello", {"errors": checked.errors}))
	var hello: Dictionary = checked.hello
	var peer_id := int(hello.peer_id)
	var peer_generation := int(hello.peer_generation)
	if source_peer_id <= 0:
		return _remember(_result(false, &"invalid_source_peer"))
	if source_peer_id != peer_id:
		return _remember(_result(false, &"spoofed_peer"))
	if peer_id == _authority_peer_id:
		return _remember(_result(false, &"authority_peer_reserved"))
	if StringName(hello.protocol_id) != PROTOCOL_ID:
		return _remember(_result(false, &"protocol_mismatch"))
	if int(hello.protocol_version) != _protocol_version:
		return _remember(_result(false, &"protocol_version_mismatch", {
			"expected": _protocol_version, "received": int(hello.protocol_version),
		}))
	if int(hello.schema_version) != SCHEMA_VERSION:
		return _remember(_result(false, &"schema_version_mismatch", {
			"expected": SCHEMA_VERSION, "received": int(hello.schema_version),
		}))
	if int(hello.package_generation) != _package_generation:
		return _remember(_result(false, &"package_generation_mismatch", {
			"expected": _package_generation, "received": int(hello.package_generation),
		}))
	if int(hello.session_generation) < _session_generation:
		return _remember(_result(false, &"stale_session_generation", {
			"expected": _session_generation, "received": int(hello.session_generation),
		}))
	if int(hello.session_generation) > _session_generation:
		return _remember(_result(false, &"future_session_generation", {
			"expected": _session_generation, "received": int(hello.session_generation),
		}))
	var known_generation := int(_highest_peer_generation.get(peer_id, 0))
	if peer_generation <= known_generation:
		return _remember(_result(false, &"stale_peer_generation", {
			"expected_above": known_generation, "received": peer_generation,
		}))
	if _peers.size() >= MAX_PEERS and not _peers.has(peer_id):
		return _remember(_result(false, &"peer_capacity"))
	var peer_record := {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"schema_version": SCHEMA_VERSION,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"connected": true,
		"accepted_event_sequence": _event_sequence + 1,
	}
	_peers[peer_id] = peer_record
	_highest_peer_generation[peer_id] = peer_generation
	_event_sequence += 1
	return _remember(_result(true, &"accepted", {
		"peer": peer_record.duplicate(true),
		"server_offer": get_server_offer(),
	}))


## Disconnect cleanup is server-only and generation-fenced. Keeping the high
## water mark after release makes a delayed old hello fail closed.
func release_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if peer_id <= 0 or peer_generation <= 0:
		return _remember(_result(false, &"invalid_peer_identity"))
	if not _peers.has(peer_id):
		return _remember(_result(false, &"unknown_peer"))
	var peer := _peers[peer_id] as Dictionary
	if int(peer.peer_generation) != peer_generation:
		return _remember(_result(false, &"stale_peer_generation"))
	_peers.erase(peer_id)
	_event_sequence += 1
	return _remember(_result(true, &"released", {
		"peer_id": peer_id, "peer_generation": peer_generation,
	}))


## Starts a new authoritative session epoch. Existing peer attachments are
## invalidated while their peer-generation water marks remain fenced.
func rotate_session(source_peer_id: int, next_package_generation: int = -1) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if next_package_generation != -1 and not _valid_positive_integer(next_package_generation):
		return _remember(_result(false, &"invalid_package_generation"))
	if _session_generation >= MAX_SAFE_INTEGER:
		return _remember(_result(false, &"session_generation_exhausted"))
	var released: Array = []
	for peer_variant in _peers.values():
		released.append((peer_variant as Dictionary).duplicate(true))
	_peers.clear()
	_session_generation += 1
	if next_package_generation != -1:
		_package_generation = next_package_generation
	_event_sequence += 1
	return _remember(_result(true, &"session_rotated", {
		"session_generation": _session_generation,
		"package_generation": _package_generation,
		"released_peers": released,
	}))


func get_peer(peer_id: int) -> Dictionary:
	if not _peers.has(peer_id):
		return {}
	return (_peers[peer_id] as Dictionary).duplicate(true)


func get_snapshot() -> Dictionary:
	var peers: Array = []
	for peer_variant in _peers.values():
		peers.append((peer_variant as Dictionary).duplicate(true))
	peers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("peer_id", 0)) < int(right.get("peer_id", 0)))
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
		"peers": peers,
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0 and _protocol_version > 0,
		"server_owns_compatibility": true,
		"server_owns_session_generation": true,
		"server_owns_peer_admission": true,
		"client_can_mutate_session": false,
		"stale_peer_generations_rejected": true,
		"connected_peer_count": _peers.size(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _decode_hello(data: Dictionary) -> Dictionary:
	if not _has_exact_wire_keys(data):
		return {"valid": false, "errors": PackedStringArray(["hello fields must match the wire schema"])}
	var errors := PackedStringArray()
	for key in ["schema_version", "peer_id", "peer_generation", "protocol_version", "package_generation", "session_generation"]:
		if not data.get(key) is int:
			errors.append("%s must remain an integer on the wire" % key)
	var protocol_value: Variant = data.get("protocol_id")
	if not protocol_value is String and not protocol_value is StringName:
		errors.append("protocol_id must remain an identifier on the wire")
	if errors.is_empty():
		if not _valid_positive_integer(int(data.schema_version)):
			errors.append("schema_version must be positive and safe")
		if not _valid_positive_integer(int(data.peer_id)):
			errors.append("peer_id must be positive and safe")
		if not _valid_positive_integer(int(data.peer_generation)):
			errors.append("peer_generation must be positive and safe")
		if not _valid_positive_integer(int(data.protocol_version)):
			errors.append("protocol_version must be positive and safe")
		if not _valid_positive_integer(int(data.package_generation)):
			errors.append("package_generation must be positive and safe")
		if not _valid_positive_integer(int(data.session_generation)):
			errors.append("session_generation must be positive and safe")
		if not _valid_id(StringName(protocol_value)):
			errors.append("protocol_id must be a stable identifier")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"hello": data.duplicate(true),
	}


func _has_exact_wire_keys(data: Dictionary) -> bool:
	if data.size() != _WIRE_KEYS.size():
		return false
	for key in _WIRE_KEYS:
		if not data.has(key):
			return false
	return true


func _valid_positive_integer(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var alpha_numeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (alpha_numeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _result(accepted: bool, status: StringName, details: Dictionary = {}) -> Dictionary:
	var output := {"accepted": accepted, "status": status}
	for key in details:
		output[key] = details[key]
	return output.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
