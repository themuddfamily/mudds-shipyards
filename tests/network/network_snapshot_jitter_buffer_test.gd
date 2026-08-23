extends SceneTree

const Buffer := preload("res://scripts/network/network_snapshot_jitter_buffer.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var buffer := Buffer.new()
	_check(buffer.reset(3).accepted, "buffer resets for the current migration generation")
	_check(buffer.push(_packet(2, 2)).accepted, "buffer accepts an out-of-order future snapshot")
	_check(buffer.pop_ready().is_empty(), "buffer withholds a future revision until the gap is filled")
	_check(buffer.push(_packet(1, 1)).accepted, "buffer accepts the missing ordered revision")
	_check(int(buffer.pop_ready().revision) == 1, "buffer releases the first contiguous revision")
	_check(int(buffer.pop_ready().revision) == 2, "buffer releases the queued next revision")
	_check(buffer.push(_packet(2, 2)).status == &"stale_or_duplicate", "buffer drops a replayed revision")
	_check(buffer.reset(5).accepted, "buffer resets before a realistic server tick trace")
	_check(buffer.push(_packet(1, 1200)).accepted, "buffer accepts a snapshot with a realistic server tick")
	_check(buffer.pop_ready().revision == 1, "buffer releases the realistic-tick baseline")
	_check(buffer.push(_packet(2, 1201)).accepted, "buffer compares tick gaps against server ticks, not revisions")
	_check(buffer.push(_packet(3, 1215)).status == &"snapshot_gap_too_large", "buffer rejects an excessive server tick gap")
	_check(buffer.push(_packet(4, 1199)).status == &"stale_server_tick", "buffer rejects a stale server tick")
	_check(buffer.reset(4).accepted and buffer.pop_ready().is_empty(), "migration reset clears pending snapshots and cursors")
	if _failures.is_empty():
		print("OK: network snapshot jitter buffer (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, server_tick: int) -> Dictionary:
	return {"revision": revision, "server_tick": server_tick, "event_sequence": revision}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
