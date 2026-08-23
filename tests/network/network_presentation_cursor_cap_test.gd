extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.reset_snapshot_jitter(80).accepted, "presentation cap starts at a clean migration")
	for revision in 257:
		var entity_id := StringName("entity_%03d" % revision)
		var result := adapter.consume_interest_snapshot({
			"revision": revision + 1,
			"server_tick": 8000 + revision,
			"interest": {
				"entity_id": entity_id,
				"in_interest": true,
				"state_revision": 1,
				"state": {"index": revision},
			},
		})
		if not result.accepted:
			_failures.append("FAIL: interest entry %d was rejected" % revision)
	var audit := adapter.get_presentation_cursor_audit()
	_check(int(audit.interest_count) == 256 and int(audit.eviction_count) == 1,
		"interest presentation state remains capped with deterministic eviction")
	_check(adapter.consume_interest_snapshot({
		"revision": 258,
		"server_tick": 8257,
		"interest": {"entity_id": &"entity_256", "in_interest": false, "state_revision": 2, "state": {}},
	}).accepted and int(adapter.get_presentation_cursor_audit().interest_count) == 255,
		"interest exit immediately frees presentation state")
	_check(adapter.reset_snapshot_jitter(81).accepted
		and int(adapter.get_presentation_cursor_audit().interest_count) == 0
		and int(adapter.get_presentation_cursor_audit().eviction_count) == 0,
		"migration reset clears bounded presentation audit")
	if _failures.is_empty():
		print("OK: presentation cursor cap (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
