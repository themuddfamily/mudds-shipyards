class_name NetworkSessionMigration
extends RefCounted

## Detached, server-owned session migration/reconnect contract.
##
## A transport adapter can use this boundary when a server process rotates (or
## a package/session epoch changes) without making a client re-create its
## logical seat, ship, and replication-interest attachment from guesses. The
## contract retains only generation-bearing attachment metadata; it does not
## open sockets, move nodes, or own gameplay state. A reconnect must present a
## strictly newer peer generation and an exact current epoch. Every gameplay
## packet is fenced by the same epochs and a monotonic packet sequence.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_session_migration_v1"
const PROTOCOL_ID: StringName = &"mudds_shipyards"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_PEERS := 64
const MAX_INTEREST_RADIUS := 1_000_000.0

const _PACKET_KEYS := [
	"schema_version", "peer_id", "peer_generation", "protocol_id",
	"protocol_version", "package_generation", "session_generation",
	"migration_generation", "packet_sequence", "kind",
]

var _authority_peer_id := 1
var _protocol_version := 1
var _package_generation := 1
var _session_generation := 1
var _migration_generation := 1
var _event_sequence := 0
var _peers: Dictionary = {}
var _highest_peer_generation: Dictionary = {}
var _last_result: Dictionary = {}


func _init(
	p_authority_peer_id: int = 1,
	p_protocol_version: int = 1,
	p_package_generation: int = 1,
	p_session_generation: int = 1,
	p_migration_generation: int = 1
) -> void:
	_authority_peer_id = maxi(1, p_authority_peer_id)
	_protocol_version = maxi(1, p_protocol_version)
	_package_generation = maxi(1, p_package_generation)
	_session_generation = maxi(1, p_session_generation)
	_migration_generation = maxi(1, p_migration_generation)
	_last_result = _result(false, &"uninitialized")


## Creates an exact packet envelope for a client transport adapter. The server
## still validates it through accept_packet/rebind_peer; this is a serializer,
## not a permission grant.
func make_packet(
	p_peer_id: int,
	p_peer_generation: int,
	p_packet_sequence: int,
	p_kind: StringName = &"state"
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"peer_id": p_peer_id,
		"peer_generation": p_peer_generation,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
		"packet_sequence": p_packet_sequence,
		"kind": p_kind,
	}.duplicate(true)


## The server records the initial attachment after the normal handshake and
## authority ledgers have committed seat/ship/interest state. It never accepts
## client-side attachment data directly.
func register_peer(source_peer_id: int, peer_id: int, peer_generation: int) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_positive(peer_id) or not _valid_positive(peer_generation):
		return _remember(_result(false, &"invalid_peer_identity"))
	if _peers.has(peer_id):
		return _remember(_result(false, &"peer_already_registered"))
	if _peers.size() >= MAX_PEERS:
		return _remember(_result(false, &"peer_capacity"))
	_peers[peer_id] = {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"active": true,
		"rebind_required": false,
		"last_packet_sequence": -1,
		"attachment": {},
	}
	_highest_peer_generation[peer_id] = peer_generation
	_event_sequence += 1
	return _remember(_result(true, &"peer_registered", {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"epoch": _epoch(),
	}))


## Binds the already-authoritative seat, ship and interest records to this
## peer. Keeping all three in one receipt makes migration atomic from the
## reconnect adapter's perspective.
func bind_attachment(
	source_peer_id: int,
	peer_id: int,
	peer_generation: int,
	seat_id: StringName,
	seat_generation: int,
	ship_id: StringName,
	ship_generation: int,
	interest_center: Vector3,
	interest_radius: float,
	interest_max_entities: int = 512
) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var peer_status := _require_active_peer(peer_id, peer_generation)
	if not peer_status.is_empty():
		return _remember(_result(false, peer_status))
	if not _valid_id(seat_id) or not _valid_positive(seat_generation):
		return _remember(_result(false, &"invalid_seat_attachment"))
	if not _valid_id(ship_id) or not _valid_positive(ship_generation):
		return _remember(_result(false, &"invalid_ship_attachment"))
	if not interest_center.is_finite() or not is_finite(interest_radius) \
		or interest_radius <= 0.0 or interest_radius > MAX_INTEREST_RADIUS \
		or interest_max_entities <= 0 or interest_max_entities > 512:
		return _remember(_result(false, &"invalid_interest_attachment"))
	var attachment := {
		"seat": {
			"seat_id": seat_id,
			"seat_generation": seat_generation,
		},
		"ship": {
			"ship_id": ship_id,
			"ship_generation": ship_generation,
		},
		"interest": {
			"center": interest_center,
			"radius": interest_radius,
			"max_entities": interest_max_entities,
		},
	}
	(_peers[peer_id] as Dictionary)["attachment"] = attachment
	_event_sequence += 1
	return _remember(_result(true, &"attachment_bound", {
		"peer_id": peer_id,
		"attachment": attachment.duplicate(true),
		"event_sequence": _event_sequence,
	}))


## Rotates the server's migration epoch. Existing peers are disconnected from
## the transport but their committed attachment receipts remain pending. A
## newer package generation is optional; if supplied it must advance strictly.
func rotate_server(source_peer_id: int, next_package_generation: int = -1) -> Dictionary:
	if source_peer_id != _authority_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if next_package_generation != -1 and (
		not _valid_positive(next_package_generation) or next_package_generation <= _package_generation
	):
		return _remember(_result(false, &"invalid_package_generation"))
	if _session_generation >= MAX_SAFE_INTEGER or _migration_generation >= MAX_SAFE_INTEGER:
		return _remember(_result(false, &"generation_exhausted"))
	var released: Array = []
	for peer_variant in _peers.values():
		var peer := peer_variant as Dictionary
		peer["active"] = false
		peer["rebind_required"] = true
		peer["last_packet_sequence"] = -1
		released.append(int(peer.get("peer_id", 0)))
	_session_generation += 1
	_migration_generation += 1
	if next_package_generation != -1:
		_package_generation = next_package_generation
	_event_sequence += 1
	return _remember(_result(true, &"server_rotated", {
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
		"package_generation": _package_generation,
		"released_peer_ids": released,
		"event_sequence": _event_sequence,
	}))


## Rebind restores only the server-retained attachment receipt. The packet
## must use the current package/session/migration epoch and a strictly newer
## peer generation than the connection that was rotated away.
func rebind_peer(source_peer_id: int, packet: Dictionary) -> Dictionary:
	var checked := _validate_packet(source_peer_id, packet, true)
	if not checked.accepted:
		return _remember(checked)
	var peer_id := int(packet.get("peer_id", 0))
	if not _peers.has(peer_id):
		return _remember(_result(false, &"unknown_peer"))
	var peer := _peers[peer_id] as Dictionary
	if bool(peer.get("active", false)):
		return _remember(_result(false, &"peer_already_active"))
	var peer_generation := int(packet.get("peer_generation", 0))
	if peer_generation <= int(peer.get("peer_generation", 0)):
		return _remember(_result(false, &"stale_peer_generation"))
	if (peer.get("attachment", {}) as Dictionary).is_empty():
		return _remember(_result(false, &"attachment_unavailable"))
	peer["peer_generation"] = peer_generation
	peer["active"] = true
	peer["rebind_required"] = false
	peer["last_packet_sequence"] = int(packet.get("packet_sequence", -1))
	_highest_peer_generation[peer_id] = peer_generation
	_event_sequence += 1
	return _remember(_result(true, &"peer_rebound", {
		"peer_id": peer_id,
		"peer_generation": peer_generation,
		"attachment": (peer["attachment"] as Dictionary).duplicate(true),
		"epoch": _epoch(),
		"event_sequence": _event_sequence,
	}))


## Accepts a current-epoch gameplay packet and advances its peer stream. All
## epoch checks happen before sequence mutation, so stale packets cannot burn
## a sequence or alter a retained attachment.
func accept_packet(source_peer_id: int, packet: Dictionary) -> Dictionary:
	var checked := _validate_packet(source_peer_id, packet, false)
	if not checked.accepted:
		return _remember(checked)
	var peer_id := int(packet.get("peer_id", 0))
	var peer := _peers[peer_id] as Dictionary
	if not bool(peer.get("active", false)):
		return _remember(_result(false, &"rebind_required"))
	var packet_sequence := int(packet.get("packet_sequence", -1))
	if packet_sequence <= int(peer.get("last_packet_sequence", -1)):
		return _remember(_result(false, &"stale_packet_sequence"))
	peer["last_packet_sequence"] = packet_sequence
	_event_sequence += 1
	return _remember(_result(true, &"packet_accepted", {
		"peer_id": peer_id,
		"packet_sequence": packet_sequence,
		"event_sequence": _event_sequence,
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
		return int(left.get("peer_id", 0)) < int(right.get("peer_id", 0))
	)
	var result := {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"protocol_id": PROTOCOL_ID,
		"protocol_version": _protocol_version,
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
		"authority_peer_id": _authority_peer_id,
		"event_sequence": _event_sequence,
		"peers": peers,
	}
	return result.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": _authority_peer_id > 0 and _protocol_version > 0,
		"server_owns_rotation": true,
		"server_owns_package_generation": true,
		"server_owns_session_generation": true,
		"server_owns_attachment_rebind": true,
		"stale_packets_rejected": true,
		"client_can_mutate_attachment": false,
		"active_peer_count": _active_peer_count(),
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_packet(source_peer_id: int, packet: Dictionary, for_rebind: bool) -> Dictionary:
	if source_peer_id <= 0:
		return _result(false, &"invalid_source_peer")
	if packet.size() != _PACKET_KEYS.size():
		return _result(false, &"invalid_packet_schema")
	for key in _PACKET_KEYS:
		if not packet.has(key):
			return _result(false, &"invalid_packet_schema")
	for key in ["schema_version", "peer_id", "peer_generation", "protocol_version", "package_generation", "session_generation", "migration_generation", "packet_sequence"]:
		if not packet.get(key) is int:
			return _result(false, &"invalid_packet_schema")
	var protocol_value: Variant = packet.get("protocol_id")
	var kind_value: Variant = packet.get("kind")
	if (not protocol_value is String and not protocol_value is StringName) \
		or (not kind_value is String and not kind_value is StringName):
		return _result(false, &"invalid_packet_schema")
	if int(packet.get("schema_version", 0)) != SCHEMA_VERSION:
		return _result(false, &"schema_version_mismatch")
	var peer_id := int(packet.get("peer_id", 0))
	if source_peer_id != peer_id:
		return _result(false, &"spoofed_peer")
	if StringName(protocol_value) != PROTOCOL_ID:
		return _result(false, &"protocol_mismatch")
	if int(packet.get("protocol_version", 0)) != _protocol_version:
		return _result(false, &"protocol_version_mismatch")
	if int(packet.get("package_generation", 0)) != _package_generation:
		return _result(false, &"stale_package_generation")
	if int(packet.get("session_generation", 0)) != _session_generation:
		return _result(false, &"stale_session_generation")
	if int(packet.get("migration_generation", 0)) != _migration_generation:
		return _result(false, &"stale_migration_generation")
	if not _valid_positive(peer_id) or not _valid_positive(int(packet.get("peer_generation", 0))):
		return _result(false, &"invalid_peer_identity")
	if not _valid_nonnegative(int(packet.get("packet_sequence", -1))):
		return _result(false, &"invalid_packet_sequence")
	if for_rebind and StringName(kind_value) != &"rebind":
		return _result(false, &"invalid_rebind_kind")
	if not for_rebind and StringName(kind_value) == &"rebind":
		return _result(false, &"invalid_packet_kind")
	if not _peers.has(peer_id):
		return _result(false, &"unknown_peer")
	return _result(true, &"packet_valid")


func _require_active_peer(peer_id: int, peer_generation: int) -> StringName:
	if not _valid_positive(peer_id) or not _valid_positive(peer_generation):
		return &"invalid_peer_identity"
	if not _peers.has(peer_id):
		return &"unknown_peer"
	var peer := _peers[peer_id] as Dictionary
	if not bool(peer.get("active", false)):
		return &"rebind_required"
	if int(peer.get("peer_generation", 0)) != peer_generation:
		return &"stale_peer_generation"
	return &""


func _epoch() -> Dictionary:
	return {
		"package_generation": _package_generation,
		"session_generation": _session_generation,
		"migration_generation": _migration_generation,
	}.duplicate(true)


func _active_peer_count() -> int:
	var count := 0
	for peer_variant in _peers.values():
		if bool((peer_variant as Dictionary).get("active", false)):
			count += 1
	return count


func _valid_id(value: StringName) -> bool:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var ascii_alphanumeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (ascii_alphanumeric or codepoint == 95 or codepoint == 45):
			return false
	return true


func _valid_positive(value: int) -> bool:
	return value > 0 and value <= MAX_SAFE_INTEGER


func _valid_nonnegative(value: int) -> bool:
	return value >= 0 and value <= MAX_SAFE_INTEGER


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status, "event_sequence": _event_sequence}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
