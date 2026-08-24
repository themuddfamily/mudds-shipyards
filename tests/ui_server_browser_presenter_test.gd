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
		{"session_id": &"cinder_run", "host_peer_id": 7, "title": "Cinder Run", "region_id": &"eu-west", "ping_ms": 42, "player_count": 1, "max_players": 4, "password_required": false, "compatible": true},
		{"session_id": &"ember_duel", "host_peer_id": 8, "title": "Ember Duel", "region_id": &"us-east", "ping_ms": 220, "player_count": 4, "max_players": 4, "password_required": true, "compatible": false},
	]
	_check(browser.publish_snapshot(77, 1, 10, entries).accepted, "directory fixture publishes")
	var presenter := Presenter.new()
	var snapshot := presenter.present(browser)
	_check(snapshot.row_count == 2, "fresh directory records become visible rows")
	_check(snapshot.rows[0].region_label == "EU-WEST" and snapshot.rows[0].latency_band == "Latency Excellent", "region and latency bands are textual")
	_check(snapshot.rows[1].full and snapshot.rows[1].occupancy_label == "4/4 players", "occupancy label exposes full state")
	_check(snapshot.rows[0].capacity_label == "AVAILABLE" and snapshot.rows[1].capacity_label == "FULL", "capacity state is textual and color-independent")
	_check(str(snapshot.rows[0].focus_label).begins_with("[ ]") and str(snapshot.accessibility_prompts.focus_marker) == "[FOCUS]", "server rows expose high-contrast textual focus labels")
	var rich_snapshot := presenter.present_result({
		"accepted": true,
		"rows": [
			{"session_id": &"rich", "title": "Rich Run", "ping_ms": 42, "player_count": 1, "max_players": 4, "password_required": false, "compatible": true},
			{"session_id": &"locked", "title": "Locked Run", "ping_ms": 220, "player_count": 4, "max_players": 4, "password_required": true, "compatible": false},
		],
	})
	var rich_row: Dictionary = rich_snapshot.rows.filter(func(row: Variant) -> bool: return (row as Dictionary).session_id == &"rich")[0]
	var locked_row: Dictionary = rich_snapshot.rows.filter(func(row: Variant) -> bool: return (row as Dictionary).session_id == &"locked")[0]
	_check(rich_row.password_label == "No Password" and locked_row.password_label == "Password Required", "password state is textual")
	_check(rich_row.compatibility_label == "Compatible" and locked_row.compatibility_label == "Incompatible", "compatibility state is textual")
	_check("Latency Excellent" in rich_row.focus_label and "No Password" in rich_row.focus_label and "Compatible" in rich_row.focus_label, "spoken focus label composes all row status fields")
	var filtered := presenter.set_accessibility_filters({"compatible_only": true, "not_full": true, "no_password": true, "latency_band": &"excellent"})
	_check(filtered.accepted and filtered.row_count == 1 and filtered.rows[0].session_id == &"rich", "caller-owned accessibility filters narrow rows")
	_check(filtered.active_filter_summary == "FILTERS: COMPATIBLE ONLY, NOT FULL, NO PASSWORD, LATENCY EXCELLENT", "active filter summary is explicit and textual")
	_check((filtered.filter_controls as Array).size() == 5 and filtered.focus_order == [&"refresh", &"host_session", &"manual_join", &"compatible_only", &"not_full", &"no_password", &"latency_band", &"clear_filters", &"retry", &"cancel"], "filter controls expose bounded presentation metadata")
	var cleared := presenter.clear_accessibility_filters()
	_check(cleared.accepted and cleared.row_count == 2 and cleared.active_filter_summary == "FILTERS: NONE", "clear-all restores the unfiltered caller snapshot")
	var sorted_latency := presenter.set_sort(&"latency", false)
	_check(sorted_latency.accepted and sorted_latency.rows[0].session_id == &"rich", "latency sort orders rows from caller data")
	_check(sorted_latency.sort.summary == "SORT: LATENCY ↑", "sort summary exposes key and direction")
	var sorted_descending := presenter.set_sort(&"latency", true)
	_check(sorted_descending.rows[0].session_id == &"locked", "descending sort is explicit")
	var cleared_sort := presenter.clear_sort()
	_check(cleared_sort.sort.summary == "SORT: NAME ↑", "clear sort restores deterministic name order")
	var generation_presenter := Presenter.new()
	var generation_snapshot := generation_presenter.present_result({
		"accepted": true,
		"rows": [
			{"session_id": &"new", "title": "New", "player_count": 2, "max_players": 4, "capacity_generation": 4},
			{"session_id": &"stale", "title": "Old", "player_count": 1, "max_players": 4, "capacity_generation": 3},
		],
	})
	_check(generation_snapshot.row_count == 1 and generation_snapshot.rows[0].session_id == &"new", "older capacity generations are ignored")
	_check(generation_snapshot.rows[0].capacity_generation == 4, "capacity generation is exposed with bounded counts")
	_check(presenter.configure_filters(&"eu-west", 100, false).accepted, "region/ping/full filters apply atomically")
	snapshot = presenter.present(browser)
	_check(snapshot.row_count == 1 and snapshot.rows[0].session_id == &"cinder_run", "filters narrow presentation rows")
	_check(snapshot.accessibility_prompts.refresh == "Refresh server list" and snapshot.accessibility_prompts.join_hint is String, "accessibility prompts are textual")
	_check(not presenter.request_join(&"cinder_run").accepted, "presenter cannot authorize joining")
	browser.advance_clock(77, 14)
	_check(presenter.present(browser).row_count == 0, "stale directory rows are omitted on refresh")
	var failure_snapshot := presenter.present_result({
		"accepted": false,
		"reason": &"directory_timeout",
		"message": "Directory timed out. Try again.",
		"retryable": true,
	})
	_check(
		failure_snapshot.status == &"error"
		and failure_snapshot.error_code == &"directory_timeout"
		and "timed out" in failure_snapshot.error_message,
		"caller failure results become explicit textual error state"
	)
	_check(failure_snapshot.focus_target == &"retry" and failure_snapshot.accessibility_prompts.status_reason == "Connection status reason", "failure chooses deterministic retry focus and textual reason")
	_check(
		failure_snapshot.actions.size() == 2
		and failure_snapshot.actions[0].id == &"retry"
		and failure_snapshot.actions[0].focusable
		and failure_snapshot.actions[1].id == &"cancel"
		and failure_snapshot.actions[1].focusable,
		"failure state exposes controller-focusable retry and cancel actions"
	)
	_check(presenter.request_retry().accepted and presenter.request_cancel().accepted, "retry and cancel return external caller intents")
	var retry_request := presenter.get_last_snapshot()
	_check(retry_request.status == &"refreshing" and retry_request.request_generation == 1, "retry enters a concise fenced refresh state")
	var stale := presenter.present_result({"accepted": true, "request_generation": 99, "rows": entries})
	_check(not stale.accepted and stale.reason == &"stale_result_ignored" and presenter.get_last_snapshot().status == &"refreshing", "a mismatched completion cannot replace the active refresh")
	var current := presenter.present_result({"accepted": true, "request_generation": 1, "rows": entries})
	_check(current.status == &"ready" and current.row_count == 2, "the current refresh completion is presented")
	var expired := presenter.present_result({"accepted": false, "status": &"expired", "reason": &"directory_expired"})
	_check(expired.status == &"expired" and expired.focus_target == &"retry" and "expired" in expired.error_message, "expired results expose textual recovery status")
	var delayed := presenter.present_result({"accepted": false, "reason": &"directory_timeout", "retryable": true, "retry_after_milliseconds": 750})
	_check(delayed.retry_after_milliseconds == 750 and "750 ms" in delayed.error_message, "caller retry timing is shown exactly without a presenter-owned clock")
	_check(presenter.set_focus_target(&"cancel").accepted and presenter.get_last_snapshot().focus_target == &"cancel", "focus target can be restored after a failed join")
	var terminal := presenter.present_result({"accepted": false, "reason": &"directory_closed", "retryable": false})
	_check(terminal.status == &"error" and terminal.actions.size() == 1 and terminal.actions[0].id == &"cancel", "non-retryable failure keeps an explicit cancel action")
	var pending := presenter.begin_refresh()
	presenter.close_view()
	var after_close := presenter.present_result({"accepted": true, "request_generation": pending.request_generation, "rows": entries})
	_check(not after_close.accepted and after_close.reason == &"stale_result_ignored" and presenter.get_last_snapshot().status == &"idle", "close invalidates pending results and clears transient browser rows")
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
