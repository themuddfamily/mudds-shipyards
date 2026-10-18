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
	_check(snapshot.rows[1].full and snapshot.rows[1].occupancy_label == "4/4 guests", "occupancy label exposes full state")
	_check(snapshot.rows[0].capacity_label == "AVAILABLE" and snapshot.rows[1].capacity_label == "FULL", "capacity state is textual and color-independent")
	_check(str(snapshot.rows[0].focus_label).begins_with("[ ]") and str(snapshot.accessibility_prompts.focus_marker) == "[FOCUS]", "server rows expose high-contrast textual focus labels")
	_check(str(snapshot.rows[1].focus_label).ends_with("SESSION FULL // REFRESH SERVER LIST") and not "SELECT TO REQUEST JOINING" in snapshot.rows[1].focus_label, "disabled full rows explain capacity and refresh recovery without offering selection")
	_check(str(snapshot.rows[0].focus_label).ends_with("SELECT TO REQUEST JOINING"), "available rows retain caller-owned join guidance")
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
	_check_session_capacity_generations()
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
	var fenced := Presenter.new()
	var first_request := fenced.begin_refresh()
	var wrong_request := fenced.present_result({
		"accepted": true,
		"request_generation": int(first_request.request_generation) + 1,
		"directory_generation": 7,
		"sequence": 10,
		"rows": entries,
	})
	_check(not wrong_request.accepted and wrong_request.fence_reason == &"request_generation_mismatch" and wrong_request.status == &"refreshing", "an exact source result cannot cross the active refresh request fence")
	var partial_cursor := fenced.present_result({
		"accepted": true,
		"request_generation": first_request.request_generation,
		"directory_generation": 7,
		"rows": entries,
	})
	_check(not partial_cursor.accepted and partial_cursor.fence_reason == &"invalid_result_cursor", "a partially tagged directory snapshot fails closed")
	var first_fenced := fenced.present_result({
		"accepted": true,
		"request_generation": first_request.request_generation,
		"directory_generation": 7,
		"snapshot_sequence": 10,
		"rows": entries,
	})
	_check(first_fenced.status == &"ready" and first_fenced.request_generation == first_request.request_generation and first_fenced.directory_generation == 7 and first_fenced.source_sequence == 10, "the exact request, directory generation, and sequence are retained with the presented rows")
	_check(first_fenced.next_action == "SELECT A SESSION TO REQUEST JOINING OR REFRESH" and first_fenced.color_independent and "SELECT TO REQUEST JOINING" in first_fenced.rows[0].focus_label, "ready rows give a colour-independent join-or-refresh next action")
	var second_request := fenced.begin_refresh()
	var replayed_cursor := fenced.present_result({
		"accepted": true,
		"request_generation": second_request.request_generation,
		"directory_generation": 7,
		"server_tick": 10,
		"rows": entries,
	})
	_check(not replayed_cursor.accepted and replayed_cursor.fence_reason == &"source_cursor_not_advanced" and replayed_cursor.status == &"refreshing", "a replayed generation and sequence cannot repaint a newer refresh")
	var current_failure := fenced.present_result({
		"accepted": false,
		"request_generation": second_request.request_generation,
		"directory_generation": 7,
		"sequence": 11,
		"reason": &"directory_timeout",
		"retryable": true,
	})
	_check(current_failure.status == &"error" and current_failure.next_action == "RETRY SERVER LIST OR CANCEL" and current_failure.error_message.contains("NEXT ACTION // RETRY SERVER LIST OR CANCEL"), "a current failure names retry or cancel in visible text")
	var third_request := fenced.request_retry()
	_check(third_request.accepted and third_request.presentation.next_action == "WAIT FOR RESULTS OR RETURN", "retry immediately presents the colour-independent waiting action")
	var detached := fenced.close_view()
	var late_exact := fenced.present_result({
		"accepted": true,
		"request_generation": third_request.request_generation,
		"directory_generation": 8,
		"sequence": 1,
		"rows": entries,
	})
	_check(not detached.attached and detached.rows.is_empty() and not late_exact.accepted and late_exact.fence_reason == &"view_detached", "close clears rows and rejects exact late completions while detached")
	var reused_request := fenced.begin_refresh()
	var reused := fenced.present_result({
		"accepted": true,
		"request_generation": reused_request.request_generation,
		"directory_generation": 1,
		"sequence": 1,
		"rows": [entries[0]],
	})
	_check(reused.attached and reused.status == &"ready" and reused.row_count == 1 and reused.directory_generation == 1, "a fresh request cleanly reuses the detached presenter without the retired source cursor")
	var published_snapshot := Presenter.new().present_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"rows": [entries[0]],
	})
	_check(published_snapshot.status == &"ready" and published_snapshot.directory_generation == 12 and published_snapshot.source_sequence == 44, "an unsolicited caller-owned directory publication keeps its existing generation and server-tick API")
	var capacity_presenter := Presenter.new()
	var capacity_open := capacity_presenter.present_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"snapshot_sequence": 1,
		"rows": [entries[0]],
	})
	var capacity_full_entry: Dictionary = entries[0].duplicate(true)
	capacity_full_entry.player_count = capacity_full_entry.max_players
	var capacity_full := capacity_presenter.present_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"snapshot_sequence": 2,
		"rows": [capacity_full_entry],
	})
	_check(capacity_open.status == &"ready" and capacity_full.status == &"full"
		and capacity_full.source_sequence == 2 and capacity_full.focus_target == &"refresh",
		"an advanced local receipt presents a same-directory capacity update and focuses refresh when all sessions are full")
	_check(capacity_full.next_action == "REFRESH SERVER LIST OR RETURN"
		and capacity_full.error_message.contains("The only session is full.")
		and not capacity_full.error_message.contains("SELECT A SESSION"),
		"all-full status gives an actionable colour-independent refresh instruction")
	var legacy_advanced := capacity_presenter.present_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 45,
		"rows": [entries[0]],
	})
	var receipt_after_legacy := capacity_presenter.present_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 45,
		"snapshot_sequence": 3,
		"rows": [entries[0]],
	})
	_check(legacy_advanced.status == &"ready" and legacy_advanced.source_sequence == 45
		and receipt_after_legacy.status == &"ready" and receipt_after_legacy.source_sequence == 3,
		"legacy server-tick and local receipt sequences remain independently monotonic public cursor shapes")
	_check_filter_sort_lifecycle(entries)
	_check_failure_action_guidance()
	_check_filtered_empty_recovery()
	var audit := presenter.audit()
	_check(bool(audit.presentation_only) and bool(audit.filters_stale_rows) and not bool(audit.browser_owns_join_authority) and bool(audit.exact_source_cursor_fencing), "audit records presentation and exact cursor boundaries")
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

func _check_filter_sort_lifecycle(entries: Array) -> void:
	var lifecycle := Presenter.new()
	lifecycle.present_result({"accepted": true, "rows": entries})
	var failure := lifecycle.present_result({"accepted": false, "reason": &"directory_timeout", "retryable": true, "retry_after_milliseconds": 750})
	var sorted_failure := lifecycle.set_sort(&"latency", true)
	_check(sorted_failure.status == &"error" and sorted_failure.rows.is_empty()
		and sorted_failure.error_message == failure.error_message
		and sorted_failure.actions == failure.actions and sorted_failure.focus_target == &"retry"
		and sorted_failure.retry_after_milliseconds == 750,
		"sorting after a directory failure preserves recovery and never resurrects retired rows")
	var filtered_failure := lifecycle.set_accessibility_filters({"compatible_only": true})
	_check(filtered_failure.status == &"error" and filtered_failure.rows.is_empty()
		and filtered_failure.sort.descending and filtered_failure.accessibility_filters.compatible_only
		and filtered_failure.active_filter_summary == "FILTERS: COMPATIBLE ONLY",
		"failure-state controls update preferences while retaining the unavailable directory state")
	var retry := lifecycle.request_retry()
	_check(retry.accepted, "filter and sort changes leave directory retry available")
	var filtered_wait := lifecycle.clear_accessibility_filters()
	_check(filtered_wait.status == &"refreshing" and filtered_wait.rows.is_empty()
		and filtered_wait.request_generation == retry.get("request_generation", -1)
		and filtered_wait.next_action == "WAIT FOR RESULTS OR RETURN",
		"changing filters during a pending retry keeps the request and waiting guidance")
	var recovered := lifecycle.present_result({"accepted": true, "request_generation": retry.get("request_generation", -1), "rows": entries})
	_check(recovered.status == &"ready" and recovered.row_count == 2
		and recovered.rows[0].session_id == &"ember_duel",
		"the exact retry completion restores fresh rows using preferences changed during failure")
	var expired := lifecycle.present_result({"accepted": false, "status": &"expired", "reason": &"directory_expired"})
	var sorted_expired := lifecycle.clear_sort()
	_check(sorted_expired.status == &"expired" and sorted_expired.rows.is_empty()
		and sorted_expired.actions == expired.actions and lifecycle.request_retry().accepted,
		"sorting expired results cannot revive sessions or hide retry")
	lifecycle.present_result({"accepted": false, "reason": &"directory_closed", "retryable": false})
	var filtered_terminal := lifecycle.clear_accessibility_filters()
	_check(filtered_terminal.status == &"error" and not filtered_terminal.retryable
		and filtered_terminal.actions.size() == 1 and filtered_terminal.actions[0].id == &"cancel"
		and filtered_terminal.focus_target == &"cancel" and not lifecycle.request_retry().accepted,
		"filtering a terminal failure retains cancel-only recovery")
	lifecycle.close_view()
	var sorted_closed := lifecycle.set_sort(&"latency")
	_check(sorted_closed.status == &"idle" and not sorted_closed.attached
		and sorted_closed.rows.is_empty(), "sorting a detached browser retains its idle lifecycle")


func _check_failure_action_guidance() -> void:
	var presenter := Presenter.new()
	for reason: StringName in [&"directory_timeout", &"directory_unavailable", &"join_failed"]:
		var terminal := presenter.present_result({"accepted": false, "reason": reason, "retryable": false})
		_check(terminal.status == &"error" and terminal.focus_target == &"cancel"
			and terminal.actions.size() == 1 and terminal.actions[0].id == &"cancel"
			and terminal.next_action == "CANCEL AND RETURN"
			and terminal.error_message.contains("NEXT ACTION // CANCEL AND RETURN")
			and not terminal.error_message.contains("Retry is available"),
			"%s never promises retry when the owner permits cancel only" % reason)
		var retryable := presenter.present_result({"accepted": false, "reason": reason, "retryable": true})
		_check(retryable.status == &"error" and retryable.focus_target == &"retry"
			and retryable.actions.size() == 2 and retryable.actions[0].id == &"retry"
			and retryable.error_message.contains("NEXT ACTION // RETRY SERVER LIST OR CANCEL"),
			"%s retains explicit retry guidance when the owner permits another request" % reason)


func _check_filtered_empty_recovery() -> void:
	var presenter := Presenter.new()
	var directory := {"accepted": true, "rows": [{"session_id": &"other_build", "title": "Other Build", "compatible": false, "player_count": 1, "max_players": 4}]}
	presenter.present_result(directory)
	var filtered := presenter.set_accessibility_filters({"compatible_only": true})
	_check(filtered.status == &"empty" and filtered.next_action == "CLEAR FILTERS OR REFRESH SERVER LIST"
		and filtered.error_message.contains("NEXT ACTION // CLEAR FILTERS OR REFRESH SERVER LIST"),
		"filtering every row names the existing clear-filters recovery action")
	var refreshed := presenter.present_result(directory)
	_check(refreshed.status == &"empty" and refreshed.next_action == filtered.next_action,
		"fresh results hidden by retained filters keep clear-filters guidance")
	var cleared := presenter.clear_accessibility_filters()
	_check(cleared.status == &"ready" and cleared.row_count == 1
		and cleared.rows[0].session_id == &"other_build" and not cleared.join_authority,
		"clearing filters restores the retained row without granting join authority")
	var empty := presenter.present_result({"accepted": true, "rows": []})
	_check(empty.status == &"empty" and empty.next_action == "REFRESH SERVER LIST"
		and not empty.error_message.contains("CLEAR FILTERS"),
		"an unfiltered empty directory retains refresh guidance")


func _check_session_capacity_generations() -> void:
	var browser := Browser.new(77, 3)
	var presenter := Presenter.new()
	var entries := [
		{"session_id": &"host_a", "host_peer_id": 7, "title": "Host A", "region_id": &"eu-west", "ping_ms": 42, "player_count": 2, "max_players": 4, "capacity_generation": 4},
		{"session_id": &"host_b", "host_peer_id": 8, "title": "Host B", "region_id": &"us-east", "ping_ms": 85, "player_count": 1, "max_players": 6, "capacity_generation": 1},
	]
	_check(browser.publish_snapshot(77, 1, 10, entries).accepted, "independent host generations publish through the real directory")
	var initial := presenter.present(browser)
	_check(initial.row_count == 2 and initial.rows[0].session_id == &"host_a"
		and initial.rows[0].capacity_generation == 4 and initial.rows[0].occupancy_label == "2/4 guests"
		and initial.rows[1].session_id == &"host_b" and initial.rows[1].capacity_generation == 1
		and initial.rows[1].occupancy_label == "1/6 guests",
		"independent generation4 and generation1 hosts both retain exact occupancy")
	entries[0].capacity_generation = 5
	entries[0].player_count = 3
	_check(browser.publish_snapshot(77, 1, 11, entries).accepted, "host A capacity advances in the directory")
	var advanced := presenter.present(browser)
	_check(advanced.row_count == 2 and advanced.rows[0].capacity_generation == 5
		and advanced.rows[0].occupancy_label == "3/4 guests" and advanced.rows[1].occupancy_label == "1/6 guests",
		"advancing host A leaves host B visible at its own generation1")
	entries[0].capacity_generation = 4
	entries[0].player_count = 1
	_check(browser.publish_snapshot(77, 1, 12, entries).accepted, "directory accepts a fresh snapshot containing an older same-session capacity")
	var stale := presenter.present(browser)
	_check(stale.row_count == 2 and stale.rows[0].capacity_generation == 5
		and stale.rows[0].occupancy_label == "3/4 guests" and stale.rows[1].occupancy_label == "1/6 guests",
		"older same-session capacity cannot roll occupancy back or suppress the other host")
	# Returned dictionaries cannot alter the retained same-session capacity floor.
	stale.rows[0].capacity_generation = 99
	stale.rows[0].occupancy_label = "changed by caller"
	var detached_copy := presenter.present(browser)
	_check(detached_copy.rows[0].capacity_generation == 5 and detached_copy.rows[0].occupancy_label == "3/4 guests",
		"per-session retained rows are detached from caller mutations")
	presenter.close_view()
	presenter.begin_refresh()
	entries[0].capacity_generation = 1
	entries[0].player_count = 1
	_check(browser.publish_snapshot(77, 1, 13, entries).accepted, "fresh generation1 hosts republish after view close")
	var reopened := presenter.present(browser)
	_check(reopened.row_count == 2 and reopened.rows[0].capacity_generation == 1
		and reopened.rows[0].occupancy_label == "1/4 guests" and reopened.rows[1].occupancy_label == "1/6 guests",
		"close and reopen discard retired session generations")
	entries[0].capacity_generation = 9
	browser.publish_snapshot(77, 1, 14, entries)
	presenter.present(browser)
	browser.advance_clock(77, 18)
	_check(presenter.present(browser).row_count == 0 and (presenter.get("_session_capacity_rows") as Dictionary).is_empty(),
		"real directory expiry removes rows and their retained capacity state")
	entries[0].capacity_generation = 1
	browser.publish_snapshot(77, 1, 19, entries)
	_check(presenter.present(browser).rows[0].capacity_generation == 1, "expired session identities can return at fresh generation1")
	presenter.present_result({"accepted": false, "status": &"expired", "reason": &"directory_expired"})
	_check((presenter.get("_session_capacity_rows") as Dictionary).is_empty(), "explicit expiry clears retained capacity state")
	var bounded_entries: Array = []
	for index in range(Presenter.MAX_ROWS + 10):
		bounded_entries.append({"session_id": StringName("bounded_%d" % index), "capacity_generation": index + 1})
	var bounded := presenter.present_result({"accepted": true, "rows": bounded_entries})
	_check(bounded.row_count == Presenter.MAX_ROWS and (presenter.get("_session_capacity_rows") as Dictionary).size() == Presenter.MAX_ROWS,
		"accepted snapshots bound retained per-session state to supported presentation rows")
	presenter.present_result({"accepted": true, "rows": [entries[1]]})
	_check((presenter.get("_session_capacity_rows") as Dictionary).size() == 1,
		"replacement snapshots prune capacity state for omitted sessions")
	presenter.present_result({"accepted": false, "reason": &"directory_timeout"})
	_check((presenter.get("_session_capacity_rows") as Dictionary).is_empty(), "directory failure drops retained session rows")
