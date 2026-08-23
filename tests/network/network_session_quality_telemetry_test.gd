extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Buffer := preload("res://scripts/network/network_snapshot_jitter_buffer.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(70).accepted, "telemetry starts at a migration boundary")
	var buffer := Buffer.new()
	_check(buffer.reset(70).accepted, "timing buffer resets counters")
	_check(buffer.push({"revision": 1, "server_tick": 100}).accepted, "telemetry records an accepted packet")
	_check(buffer.pop_ready().revision == 1, "telemetry records a released packet")
	_check(buffer.push({"revision": 1, "server_tick": 100}).status == &"stale_or_duplicate", "telemetry records stale rejection")
	_check(buffer.push({"revision": 2, "server_tick": 110}).status == &"snapshot_gap_too_large", "telemetry records gap rejection")
	var telemetry := buffer.get_telemetry()
	_check(int(telemetry.accepted_count) == 1 and int(telemetry.released_count) == 1
		and int(telemetry.stale_rejection_count) == 1
		and int(telemetry.gap_rejection_count) == 1
		and int(telemetry.pending_depth) == 0
		and int(telemetry.max_pending_depth) == 1,
		"telemetry reports bounded accepted/released/stale/gap/depth counters")
	var aggregate := adapter.get_session_quality_telemetry()
	_check(int(aggregate.buffer_count) == 7 and int(aggregate.pending_depth) == 0,
		"adapter exposes detached aggregate telemetry across presentation cursors")
	_check(adapter.reset_snapshot_jitter(71).accepted
		and int(adapter.get_session_quality_telemetry().accepted_count) == 0,
		"migration reset clears session timing telemetry")
	if _failures.is_empty():
		print("OK: network session quality telemetry (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
