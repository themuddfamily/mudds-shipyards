extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	var timeout := adapter.record_session_end(&"connection_timeout", 4, 9)
	_check(timeout.accepted and timeout.snapshot.reason == &"timeout"
		and int(timeout.snapshot.peer_generation) == 4, "timeout normalizes into a finite detached reason")
	var rejected := adapter.record_session_end(&"admission_rejected", 4, 9)
	_check(rejected.accepted and rejected.snapshot.reason == &"rejected", "rejection cause normalizes")
	var protocol := adapter.record_session_end(&"incompatible_protocol", 4, 9)
	_check(protocol.accepted and protocol.snapshot.reason == &"protocol_mismatch", "protocol cause normalizes")
	var migration := adapter.record_session_end(&"migration", 5, 10)
	_check(migration.accepted and migration.snapshot.reason == &"host_migration"
		and int(migration.snapshot.migration_generation) == 10, "migration cause advances its generation fence")
	var stale := adapter.record_session_end(&"timeout", 4, 9)
	_check(not stale.accepted and stale.status == &"stale_session_end_generation"
		and adapter.get_session_end_reason_snapshot().reason == &"host_migration",
		"older session-end generations cannot overwrite the current reason")
	var unknown := adapter.record_session_end(&"unexpected_disconnect", 5, 10)
	_check(unknown.accepted and unknown.snapshot.reason == &"unknown", "unrecognized causes fail closed to unknown")
	_check(adapter.reset_snapshot_jitter(11).accepted
		and adapter.get_session_end_reason_snapshot().reason == &"unknown"
		and int(adapter.get_session_end_reason_snapshot().sequence) == 0,
		"reconnect/migration reset clears detached session-end state")
	if _failures.is_empty():
		print("OK: session end reason normalization (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
