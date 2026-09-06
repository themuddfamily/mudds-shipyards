class_name NetworkSnapshotJitterBuffer
extends RefCounted

## Bounded client-side ordering window for authoritative snapshots.
##
## This buffer stores detached packets only. NetworkSnapshotLifecycleAdapter
## remains the authority validator and state applier; the buffer only releases
## contiguous revisions and drops stale or duplicate generations.

const MAX_PACKETS := 16
const MAX_TICK_GAP := 8

var _migration_generation := 1
var _next_revision := 1
var _last_released_revision := 0
var _last_released_server_tick := -1
var _pending: Dictionary = {}
var _last_result: Dictionary = {"accepted": false, "status": &"uninitialized"}
var _released_count := 0
var _accepted_count := 0
var _stale_rejection_count := 0
var _gap_rejection_count := 0
var _max_pending_depth := 0


func reset(migration_generation: int = 1, first_revision: int = 1) -> Dictionary:
	if migration_generation <= 0:
		return _remember({"accepted": false, "status": &"invalid_migration_generation"})
	if first_revision <= 0:
		return _remember({"accepted": false, "status": &"invalid_snapshot_revision"})
	_migration_generation = migration_generation
	_next_revision = first_revision
	_last_released_revision = 0
	_last_released_server_tick = -1
	_pending.clear()
	_released_count = 0
	_accepted_count = 0
	_stale_rejection_count = 0
	_gap_rejection_count = 0
	_max_pending_depth = 0
	return _remember({"accepted": true, "status": &"reset", "migration_generation": _migration_generation})


func push(packet: Dictionary) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick"):
		return _reject(&"invalid_snapshot")
	var revision := int(packet.get("revision", 0))
	var server_tick := int(packet.get("server_tick", -1))
	if revision <= 0 or server_tick < 0:
		return _reject(&"invalid_snapshot")
	if revision < _next_revision or _pending.has(revision):
		return _reject(&"stale_or_duplicate")
	if _last_released_server_tick >= 0 \
			and server_tick < _last_released_server_tick:
		return _reject(&"stale_server_tick")
	if server_tick > _last_released_server_tick + MAX_TICK_GAP \
			and _last_released_server_tick >= 0:
		return _reject(&"snapshot_gap_too_large")
	if _pending.size() >= MAX_PACKETS:
		return _reject(&"buffer_full")
	_pending[revision] = packet.duplicate(true)
	_accepted_count += 1
	_max_pending_depth = maxi(_max_pending_depth, _pending.size())
	return _remember({"accepted": true, "status": &"buffered", "revision": revision})


func pop_ready() -> Dictionary:
	if not _pending.has(_next_revision):
		return {}
	var packet: Dictionary = _pending[_next_revision]
	_pending.erase(_next_revision)
	_last_released_revision = _next_revision
	_last_released_server_tick = int(packet.get("server_tick", -1))
	_released_count += 1
	_next_revision += 1
	_last_result = {"accepted": true, "status": &"released", "revision": _last_released_revision}
	return packet.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"migration_generation": _migration_generation,
		"next_revision": _next_revision,
		"last_released_revision": _last_released_revision,
		"last_released_server_tick": _last_released_server_tick,
		"pending_revisions": _pending.keys(),
		"capacity": MAX_PACKETS,
		"telemetry": get_telemetry(),
	}.duplicate(true)


func get_telemetry() -> Dictionary:
	return {
		"accepted_count": _accepted_count,
		"released_count": _released_count,
		"stale_rejection_count": _stale_rejection_count,
		"gap_rejection_count": _gap_rejection_count,
		"pending_depth": _pending.size(),
		"max_pending_depth": _max_pending_depth,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)


func _reject(status: StringName) -> Dictionary:
	if status == &"stale_or_duplicate" or status == &"stale_server_tick":
		_stale_rejection_count += 1
	if status == &"snapshot_gap_too_large":
		_gap_rejection_count += 1
	return _remember({"accepted": false, "status": status})
