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
	hud.call("_show_pause_main")
	hud.call("_show_server_browser_page")
	await process_frame
	_check(
		root.get_viewport().gui_get_focus_owner() == retry,
		"retained browser re-entry returns controller focus to retry",
	)
	address.grab_focus()
	await process_frame
	hud.call("_show_pause_main")
	hud.call("_show_server_browser_page")
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == address, "browser re-entry restores last focused field")
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
