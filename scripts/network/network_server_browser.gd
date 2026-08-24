class_name NetworkServerBrowser
extends RefCounted

## Detached server-browser/session-discovery contract.
##
## This is a bounded directory cache, not a socket, matchmaking service, or
## join authority. A trusted directory source publishes complete snapshots;
## callers can filter and inspect them, but cannot edit a session record or
## infer that a visible entry is still joinable after its freshness window.

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"network_server_browser_v1"
const MAX_SESSIONS := 256
const MAX_ID_LENGTH := 64
const DEFAULT_STALE_AFTER_TICKS := 30
const MAX_REGION_LABEL_LENGTH := 32
const MAX_TITLE_LENGTH := 64

const PING_UNKNOWN := -1
const PING_FAST: StringName = &"fast"
const PING_MEDIUM: StringName = &"medium"
const PING_SLOW: StringName = &"slow"
const PING_UNAVAILABLE: StringName = &"unavailable"

var _directory_peer_id := 1
var _stale_after_ticks := DEFAULT_STALE_AFTER_TICKS
var _directory_generation := 0
var _directory_tick := 0
var _snapshot_sequence := 0
var _sessions: Dictionary = {}
var _last_result: Dictionary = {}


func _init(p_directory_peer_id: int = 1, p_stale_after_ticks: int = DEFAULT_STALE_AFTER_TICKS) -> void:
	_directory_peer_id = maxi(1, p_directory_peer_id)
	_stale_after_ticks = maxi(1, p_stale_after_ticks)
	_last_result = _result(false, &"uninitialized")


## Replaces the cache atomically. A session publisher cannot partially update
## another host's record, and an older directory generation cannot resurrect
## stale entries. No endpoint or join token is accepted as authoritative data.
func publish_snapshot(source_peer_id: int, directory_generation: int, server_tick: int, entries: Array) -> Dictionary:
	if source_peer_id != _directory_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative(directory_generation) or directory_generation < _directory_generation:
		return _remember(_result(false, &"stale_directory_generation"))
	if not _valid_nonnegative(server_tick) or server_tick < _directory_tick:
		return _remember(_result(false, &"stale_directory_tick"))
	if entries.size() > MAX_SESSIONS:
		return _remember(_result(false, &"session_capacity"))
	var replacement: Dictionary = {}
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			return _remember(_result(false, &"invalid_session_entry"))
		var checked := _validate_entry(raw_entry as Dictionary, directory_generation, server_tick)
		if not checked.accepted:
			return _remember(checked)
		var session_id: StringName = checked.session_id
		if replacement.has(session_id):
			return _remember(_result(false, &"duplicate_session_id"))
		replacement[session_id] = checked.entry
	_sessions = replacement
	_directory_generation = directory_generation
	_directory_tick = server_tick
	_expire_stale_entries()
	_snapshot_sequence += 1
	return _remember(_result(true, &"snapshot_published", {
		"directory_generation": _directory_generation,
		"server_tick": _directory_tick,
		"snapshot_sequence": _snapshot_sequence,
		"session_count": _sessions.size(),
	}))


func advance_clock(source_peer_id: int, server_tick: int) -> Dictionary:
	if source_peer_id != _directory_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	if not _valid_nonnegative(server_tick) or server_tick < _directory_tick:
		return _remember(_result(false, &"stale_directory_tick"))
	_directory_tick = server_tick
	var expired := _expire_stale_entries()
	_snapshot_sequence += 1
	return _remember(_result(true, &"clock_advanced", {
		"directory_generation": _directory_generation,
		"server_tick": _directory_tick,
		"snapshot_sequence": _snapshot_sequence,
		"expired_session_ids": expired,
		"session_count": _sessions.size(),
	}))


## Caller-driven expiry; no timer or network polling is owned here.
func expire_stale(source_peer_id: int, server_tick: int) -> Dictionary:
	return advance_clock(source_peer_id, server_tick)


## Detach clears all presentation records before a reconnect or migration.
func detach(source_peer_id: int) -> Dictionary:
	if source_peer_id != _directory_peer_id:
		return _remember(_result(false, &"unauthorized_source"))
	var removed := _sessions.keys()
	_sessions.clear()
	_snapshot_sequence += 1
	return _remember(_result(true, &"detached", {
		"directory_generation": _directory_generation,
		"server_tick": _directory_tick,
		"snapshot_sequence": _snapshot_sequence,
		"removed_session_ids": removed,
	}))


## Returns only fresh entries. Filtering is presentation-only and does not
## grant admission or reserve a player slot.
func query(region_filter: StringName = &"", max_ping_ms: int = -1, include_full: bool = true) -> Array:
	var visible: Array = []
	for session_id in _sessions:
		var entry: Dictionary = _sessions[session_id]
		if _is_stale(entry):
			continue
		if region_filter != &"" and entry["region_id"] != region_filter:
			continue
		var ping_ms := int(entry["ping_ms"])
		if max_ping_ms >= 0 and (ping_ms < 0 or ping_ms > max_ping_ms):
			continue
		if not include_full and int(entry["player_count"]) >= int(entry["max_players"]):
			continue
		visible.append(entry.duplicate(true))
	visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := int(a["ping_ms"]) if int(a["ping_ms"]) >= 0 else 2147483647
		var bp := int(b["ping_ms"]) if int(b["ping_ms"]) >= 0 else 2147483647
		return [ap, String(a["region_id"]), String(a["session_id"])] < [bp, String(b["region_id"]), String(b["session_id"])]
	)
	return visible


func get_session(session_id: StringName) -> Dictionary:
	if not _sessions.has(session_id) or _is_stale(_sessions[session_id]):
		return {}
	return (_sessions[session_id] as Dictionary).duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"directory_generation": _directory_generation,
		"server_tick": _directory_tick,
		"snapshot_sequence": _snapshot_sequence,
		"session_count": _sessions.size(),
		"directory_owns_records": true,
		"client_can_mutate_records": false,
		"browser_owns_join_authority": false,
		"uses_live_sockets": false,
	}


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _validate_entry(raw: Dictionary, generation: int, tick: int) -> Dictionary:
	var required := [&"session_id", &"host_peer_id", &"title", &"region_id", &"ping_ms", &"player_count", &"max_players"]
	for key in required:
		if not raw.has(key):
			return _result(false, &"missing_session_field", {"field": key})
	var session_id := _as_id(raw["session_id"])
	var region_id := _as_label(raw["region_id"], MAX_REGION_LABEL_LENGTH)
	var title := _as_label(raw["title"], MAX_TITLE_LENGTH)
	var host_peer_id := int(raw["host_peer_id"])
	var ping_ms := int(raw["ping_ms"])
	var player_count := int(raw["player_count"])
	var max_players := int(raw["max_players"])
	var available_slots := int(raw.get("available_slots", max_players - player_count))
	var capacity_generation := int(raw.get("capacity_generation", generation))
	var protocol_version := int(raw.get("protocol_version", 1))
	var build_version := int(raw.get("build_version", 1))
	if session_id == &"" or region_id == &"" or title == &"":
		return _result(false, &"invalid_session_label")
	if host_peer_id <= 0 or player_count < 0 or max_players <= 0 or player_count > max_players \
		or available_slots != max_players - player_count or capacity_generation <= 0:
		return _result(false, &"invalid_capacity")
	if ping_ms < PING_UNKNOWN or ping_ms > 60_000:
		return _result(false, &"invalid_ping")
	var entry := {
		"session_id": session_id,
		"host_peer_id": host_peer_id,
		"title": title,
		"region_id": region_id,
		"ping_ms": ping_ms,
		"ping_label": _ping_label(ping_ms),
		"player_count": player_count,
		"max_players": max_players,
		"available_slots": available_slots,
		"is_full": available_slots == 0,
		"capacity_generation": capacity_generation,
		"protocol_version": protocol_version,
		"build_version": build_version,
		"directory_generation": generation,
		"last_seen_tick": tick,
	}
	return _result(true, &"valid", {"session_id": session_id, "entry": entry})


func _is_stale(entry: Dictionary) -> bool:
	return _directory_tick - int(entry["last_seen_tick"]) > _stale_after_ticks


func _expire_stale_entries() -> Array:
	var expired: Array = []
	for session_id_variant in _sessions.keys():
		var session_id := StringName(session_id_variant)
		if _is_stale(_sessions[session_id] as Dictionary):
			expired.append(session_id)
			_sessions.erase(session_id)
	expired.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return expired


func _ping_label(ping_ms: int) -> StringName:
	if ping_ms < 0:
		return PING_UNAVAILABLE
	if ping_ms <= 80:
		return PING_FAST
	if ping_ms <= 180:
		return PING_MEDIUM
	return PING_SLOW


func _as_id(value: Variant) -> StringName:
	if value is StringName:
		var text := String(value)
		return value if not text.is_empty() and text.length() <= MAX_ID_LENGTH and text.is_valid_identifier() else &""
	if value is String:
		var text := String(value)
		return StringName(text) if not text.is_empty() and text.length() <= MAX_ID_LENGTH and text.is_valid_identifier() else &""
	return &""


func _as_label(value: Variant, max_length: int) -> StringName:
	if not (value is String or value is StringName):
		return &""
	var text := String(value).strip_edges()
	return StringName(text) if not text.is_empty() and text.length() <= max_length else &""


func _valid_nonnegative(value: int) -> bool:
	return value >= 0


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return result
