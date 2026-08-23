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
var _pending: Dictionary = {}
var _last_result: Dictionary = {"accepted": false, "status": &"uninitialized"}


func reset(migration_generation: int = 1) -> Dictionary:
	if migration_generation <= 0:
		return _remember({"accepted": false, "status": &"invalid_migration_generation"})
	_migration_generation = migration_generation
	_next_revision = 1
	_last_released_revision = 0
	_pending.clear()
	return _remember({"accepted": true, "status": &"reset", "migration_generation": _migration_generation})


func push(packet: Dictionary) -> Dictionary:
	if not packet.has("revision") or not packet.has("server_tick"):
		return _remember({"accepted": false, "status": &"invalid_snapshot"})
	var revision := int(packet.get("revision", 0))
	var server_tick := int(packet.get("server_tick", -1))
	if revision <= 0 or server_tick < 0:
		return _remember({"accepted": false, "status": &"invalid_snapshot"})
	if revision < _next_revision or _pending.has(revision):
		return _remember({"accepted": false, "status": &"stale_or_duplicate"})
	if server_tick > _last_released_revision + MAX_TICK_GAP and _last_released_revision > 0:
		return _remember({"accepted": false, "status": &"snapshot_gap_too_large"})
	if _pending.size() >= MAX_PACKETS:
		return _remember({"accepted": false, "status": &"buffer_full"})
	_pending[revision] = packet.duplicate(true)
	return _remember({"accepted": true, "status": &"buffered", "revision": revision})


func pop_ready() -> Dictionary:
	if not _pending.has(_next_revision):
		return {}
	var packet: Dictionary = _pending[_next_revision]
	_pending.erase(_next_revision)
	_last_released_revision = _next_revision
	_next_revision += 1
	_last_result = {"accepted": true, "status": &"released", "revision": _last_released_revision}
	return packet.duplicate(true)


func get_snapshot() -> Dictionary:
	return {
		"migration_generation": _migration_generation,
		"next_revision": _next_revision,
		"last_released_revision": _last_released_revision,
		"pending_revisions": _pending.keys(),
		"capacity": MAX_PACKETS,
	}.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _remember(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	return _last_result.duplicate(true)
