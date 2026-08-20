extends SceneTree

const Browser := preload("res://scripts/network/network_server_browser.gd")
const Presenter := preload("res://scripts/ui/server_browser_presenter.gd")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var browser := Browser.new(77, 3)
	var entries := [
		{"session_id": &"cinder_run", "host_peer_id": 7, "title": "Cinder Run", "region_id": &"eu-west", "ping_ms": 42, "player_count": 1, "max_players": 4},
		{"session_id": &"ember_duel", "host_peer_id": 8, "title": "Ember Duel", "region_id": &"us-east", "ping_ms": 220, "player_count": 4, "max_players": 4},
	]
	_check(browser.publish_snapshot(77, 1, 10, entries).accepted, "directory fixture publishes")
	var presenter := Presenter.new()
	var snapshot := presenter.present(browser)
	_check(snapshot.row_count == 2, "fresh directory records become visible rows")
	_check(snapshot.rows[0].region_label == "EU-WEST" and snapshot.rows[0].ping_label == "Fast", "region and ping labels are textual")
	_check(snapshot.rows[1].full and snapshot.rows[1].occupancy_label == "4/4 players", "occupancy label exposes full state")
	_check(presenter.configure_filters(&"eu-west", 100, false).accepted, "region/ping/full filters apply atomically")
	snapshot = presenter.present(browser)
	_check(snapshot.row_count == 1 and snapshot.rows[0].session_id == &"cinder_run", "filters narrow presentation rows")
	_check(snapshot.accessibility_prompts.refresh == "Refresh server list" and snapshot.accessibility_prompts.join_hint is String, "accessibility prompts are textual")
	_check(not presenter.request_join(&"cinder_run").accepted, "presenter cannot authorize joining")
	browser.advance_clock(77, 14)
	_check(presenter.present(browser).row_count == 0, "stale directory rows are omitted on refresh")
	var audit := presenter.audit()
	_check(bool(audit.presentation_only) and bool(audit.filters_stale_rows) and not bool(audit.browser_owns_join_authority), "audit records presentation boundary")
	if _failures.is_empty():
		print("OK: server browser presenter (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
