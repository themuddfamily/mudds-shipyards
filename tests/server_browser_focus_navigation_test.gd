extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_paused(true)
	hud.call("_show_server_browser_page")
	var address := hud.get("_server_browser_address") as Control
	var port := hud.get("_server_browser_port") as Control
	var name := hud.get("_server_browser_player_name") as Control
	var refresh := hud.get("_server_browser_page").find_child("ServerBrowserRefreshButton", true, false) as Control
	var host := hud.get("_server_browser_page").find_child("ServerBrowserHostButton", true, false) as Control
	var manual := hud.get("_server_browser_page").find_child("ServerBrowserManualJoinButton", true, false) as Control
	var back := hud.get("_server_browser_page").find_child("ServerBrowserBackButton", true, false) as Control
	var compatible := hud.get("_server_browser_page").find_child("ServerBrowserFilterCompatibleOnly", true, false) as Control
	var not_full := hud.get("_server_browser_page").find_child("ServerBrowserFilterNotFull", true, false) as Control
	var no_password := hud.get("_server_browser_page").find_child("ServerBrowserFilterNoPassword", true, false) as Control
	var latency := hud.get("_server_browser_page").find_child("ServerBrowserFilterLatency", true, false) as Control
	var clear_filters := hud.get("_server_browser_page").find_child("ServerBrowserClearFiltersButton", true, false) as Control
	var sort_key := hud.get("_server_browser_page").find_child("ServerBrowserSortKey", true, false) as Control
	var sort_direction := hud.get("_server_browser_page").find_child("ServerBrowserSortDirection", true, false) as Control
	var clear_sort := hud.get("_server_browser_page").find_child("ServerBrowserClearSortButton", true, false) as Control
	var ordered: Array[Control] = [address, port, name, compatible, not_full, no_password, latency, clear_filters, sort_key, sort_direction, clear_sort, refresh, host, manual, back]
	for index in ordered.size():
		_check(ordered[index].focus_mode == Control.FOCUS_ALL, "browser control %d is focusable" % index)
		_check(ordered[index].focus_neighbor_bottom == ordered[index].get_path_to(ordered[mini(ordered.size() - 1, index + 1)]), "browser control %d has next focus" % index)
	address.grab_focus()
	await process_frame
	_check(
		hud.apply_first_sortie_tutorial_snapshot({"step_id": &"board", "generation": 3, "revision": 1})
		and root.get_viewport().gui_get_focus_owner() == address,
		"a tutorial redraw cannot steal controller focus from the open browser"
	)
	var scroll := hud.get("_server_browser_results_scroll") as ScrollContainer
	_check(
		scroll != null and scroll.follow_focus
			and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"browser results are vertically bounded and automatically follow controller focus",
	)
	var capacity_rows := _session_rows(9)
	_check(hud.apply_server_browser_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"snapshot_sequence": 1,
		"rows": capacity_rows,
	}), "initial capacity receipt renders scrollable sessions")
	await process_frame
	var rows := hud.get("_server_browser_rows") as VBoxContainer
	var first_row := _session_button(rows, &"session_00")
	var focused_row := _session_button(rows, &"session_08")
	_check(
		first_row != null and focused_row != null
			and clear_sort.focus_neighbor_bottom == clear_sort.get_path_to(first_row)
			and first_row.focus_neighbor_top == first_row.get_path_to(clear_sort)
			and focused_row.focus_neighbor_bottom == focused_row.get_path_to(refresh)
			and refresh.focus_neighbor_top == refresh.get_path_to(focused_row),
		"enabled result rows are spliced between sort and refresh in the focus graph",
	)
	focused_row.grab_focus()
	await process_frame
	_check(scroll.scroll_vertical > 0, "focusing the ninth session scrolls the bounded results viewport")
	var previous_row := focused_row
	capacity_rows[8]["player_count"] = 2
	_check(hud.apply_server_browser_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"snapshot_sequence": 2,
		"rows": capacity_rows,
	}), "advanced capacity receipt rebuilds the same session identities")
	await process_frame
	await process_frame
	var rebuilt_row := root.get_viewport().gui_get_focus_owner() as Button
	var scroll_rect := scroll.get_global_rect()
	var rebuilt_rect := rebuilt_row.get_global_rect() if is_instance_valid(rebuilt_row) else Rect2()
	_check(
		is_instance_valid(rebuilt_row) and rebuilt_row != previous_row
			and rows.is_ancestor_of(rebuilt_row)
			and StringName(rebuilt_row.get_meta(&"session_id", &"")) == &"session_08",
		"capacity rebuild restores focus to the same session identity",
	)
	_check(
		rebuilt_rect.position.y >= scroll_rect.position.y - 0.5
			and rebuilt_rect.end.y <= scroll_rect.end.y + 0.5
			and scroll.scroll_vertical > 0,
		"capacity rebuild keeps the restored session visible in the scrolled viewport",
	)
	capacity_rows.remove_at(8)
	_check(hud.apply_server_browser_result({
		"accepted": true,
		"directory_generation": 12,
		"server_tick": 44,
		"snapshot_sequence": 3,
		"rows": capacity_rows,
	}), "later capacity receipt may remove the focused session")
	await process_frame
	_check(
		root.get_viewport().gui_get_focus_owner() == refresh
			and hud.get("_server_browser_focus_target") == refresh
			and _session_button(rows, &"session_08") == null,
		"removed focused session returns to Refresh without selecting another identity",
	)
	hud.apply_server_browser_result({
		"accepted": true,
		"rows": [{"session_id": &"full", "title": "Full", "player_count": 4, "max_players": 4}],
	})
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == refresh,
		"all-full results keep controller focus on the enabled refresh action")
	hud.apply_server_browser_result({"accepted": false, "message": "Directory unavailable.", "retryable": true})
	_check((hud.get("_server_browser_title") as Label).text == "SERVER LIST UNAVAILABLE", "error state remains explicit")
	await process_frame
	var retry := hud.get("_server_browser_page").find_child("ServerBrowserRetryButton", true, false) as Control
	_check(
		is_instance_valid(retry)
		and retry.focus_mode == Control.FOCUS_ALL
		and retry.focus_neighbor_bottom == retry.get_path_to(refresh)
		and refresh.focus_neighbor_top == refresh.get_path_to(retry),
		"retry action is linked into the controller focus graph",
	)
	_check(
		root.get_viewport().gui_get_focus_owner() == retry,
		"retryable failure moves controller focus directly to recovery",
	)
	var retry_request := hud.request_server_browser_refresh()
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == refresh, "retry preserves controller recovery focus on the stable refresh control")
	_check(not hud.apply_server_browser_result({"accepted": true, "request_generation": int(retry_request.request_generation) + 1, "rows": []}), "out-of-order browser completion is ignored")
	hud.apply_server_browser_result({"accepted": false, "request_generation": retry_request.request_generation, "message": "Directory unavailable.", "retryable": true})
	await process_frame
	hud.call("_show_pause_main")
	await process_frame
	_check((hud.get("_server_browser_rows") as VBoxContainer).get_child_count() == 0, "closing browser clears transient retry controls")
	_check(not hud.apply_server_browser_result({"accepted": true, "rows": [{"session_id": &"late", "title": "Late", "player_count": 1, "max_players": 4}]}), "a late untagged completion cannot repaint the closed browser")
	hud.call("_show_server_browser_page")
	await process_frame
	_check(
		root.get_viewport().gui_get_focus_owner() == refresh,
		"browser re-entry returns controller focus to the stable refresh action",
	)
	address.grab_focus()
	await process_frame
	hud.call("_show_pause_main")
	hud.call("_show_server_browser_page")
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == address, "browser re-entry restores last focused field")
	hud.set_paused(false)
	await process_frame
	_check(not hud.apply_server_browser_result({"accepted": false, "message": "Late failure.", "retryable": true}), "closing the pause overlay also fences late browser results")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SERVER_BROWSER_FOCUS_NAVIGATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _session_rows(count: int) -> Array:
	var rows: Array = []
	for index in count:
		rows.append({
			"session_id": StringName("session_%02d" % index),
			"title": "Session %02d" % index,
			"region_id": &"local",
			"ping_ms": 20 + index,
			"player_count": 1,
			"max_players": 4,
		})
	return rows


func _session_button(rows: VBoxContainer, session_id: StringName) -> Button:
	for child in rows.get_children():
		if child is Button and StringName(child.get_meta(&"session_id", &"")) == session_id:
			return child as Button
	return null
