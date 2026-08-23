extends SceneTree

const Browser := preload("res://scripts/network/network_server_browser.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var browser := Browser.new(1, 3)
	var entries := [_entry("alpha"), _entry("bravo")]
	_check(browser.publish_snapshot(1, 10, 100, entries).accepted, "directory accepts the bounded initial snapshot")
	_check(browser.audit().session_count == 2, "directory exposes its bounded record count")
	var advanced := browser.advance_clock(1, 104)
	_check(advanced.accepted and advanced.expired_session_ids.size() == 2
		and browser.query().is_empty(), "caller-driven clock expiry removes stale records")
	_check(not browser.publish_snapshot(1, 9, 105, entries).accepted
		and browser.get_last_result().status == &"stale_directory_generation",
		"older directory generations are rejected")
	_check(not browser.advance_clock(1, 103).accepted
		and browser.get_last_result().status == &"stale_directory_tick",
		"replayed directory ticks are rejected")
	_check(browser.publish_snapshot(1, 10, 105, [_entry("charlie")]).accepted, "fresh generation snapshot can repopulate")
	var detached := browser.detach(1)
	_check(detached.accepted and detached.removed_session_ids.size() == 1
		and browser.audit().session_count == 0, "detach clears discovery state for migration/reconnect")
	_check(not browser.detach(2).accepted, "untrusted callers cannot clear discovery state")
	if _failures.is_empty():
		print("OK: server browser expiry (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _entry(session_id: String) -> Dictionary:
	return {
		"session_id": session_id,
		"host_peer_id": 2,
		"title": "Probe",
		"region_id": "lan",
		"ping_ms": 20,
		"player_count": 1,
		"max_players": 4,
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
