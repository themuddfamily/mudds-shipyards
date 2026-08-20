extends SceneTree

const Browser := preload("res://scripts/network/network_server_browser.gd")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var browser := Browser.new(99, 3)
	var entries := [
		{"session_id": &"cinder_run", "host_peer_id": 7, "title": "Cinder Run", "region_id": &"eu-west", "ping_ms": 42, "player_count": 1, "max_players": 4},
		{"session_id": &"ember_duel", "host_peer_id": 8, "title": "Ember Duel", "region_id": &"us-east", "ping_ms": 220, "player_count": 4, "max_players": 4},
		{"session_id": &"quiet_dock", "host_peer_id": 9, "title": "Quiet Dock", "region_id": &"eu-west", "ping_ms": -1, "player_count": 0, "max_players": 2},
	]
	_check(not browser.publish_snapshot(7, 1, 10, entries).accepted, "untrusted client cannot publish directory records")
	_check(browser.publish_snapshot(99, 1, 10, entries).accepted, "directory publishes one atomic snapshot")
	var eu := browser.query(&"eu-west")
	_check(eu.size() == 2 and eu[0]["session_id"] == &"cinder_run", "region filter and ping ordering are deterministic")
	_check(eu[0]["ping_label"] == Browser.PING_FAST and eu[1]["ping_label"] == Browser.PING_UNAVAILABLE, "ping labels expose fast and unavailable states")
	_check(browser.query(&"", -1, false).size() == 2, "full sessions can be excluded without mutating records")
	_check(browser.query(&"", 100).size() == 1, "ping ceiling filters visible sessions")
	var copy := browser.get_session(&"cinder_run")
	copy["player_count"] = 4
	_check(int(browser.get_session(&"cinder_run")["player_count"]) == 1, "browser result copies cannot mutate authority")
	_check(not browser.publish_snapshot(99, 0, 11, entries).accepted, "older directory generation is rejected")
	_check(not browser.publish_snapshot(99, 2, 9, entries).accepted, "older directory tick is rejected")
	_check(browser.advance_clock(99, 14).accepted, "directory clock advances through trusted source")
	_check(browser.get_session(&"cinder_run").is_empty(), "entries beyond freshness window are stale")
	_check(not browser.publish_snapshot(99, 3, 15, [{"session_id": &"bad", "host_peer_id": 1, "title": "Bad", "region_id": &"eu", "ping_ms": 1, "player_count": 5, "max_players": 2}]).accepted, "invalid capacity rejects atomically")
	_check(browser.get_session(&"ember_duel").is_empty(), "failed snapshot does not partially replace existing cache")
	var audit := browser.audit()
	_check(bool(audit.directory_owns_records) and not bool(audit.client_can_mutate_records) and not bool(audit.browser_owns_join_authority) and not bool(audit.uses_live_sockets), "audit separates discovery from join and socket authority")
	if _failures.is_empty():
		print("OK: network server browser (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
