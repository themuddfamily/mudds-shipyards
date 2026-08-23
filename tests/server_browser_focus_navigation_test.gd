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
	var ordered: Array[Control] = [address, port, name, refresh, host, manual, back]
	for index in ordered.size():
		_check(ordered[index].focus_mode == Control.FOCUS_ALL, "browser control %d is focusable" % index)
		_check(ordered[index].focus_neighbor_bottom == ordered[index].get_path_to(ordered[mini(ordered.size() - 1, index + 1)]), "browser control %d has next focus" % index)
	hud.apply_server_browser_result({"accepted": false, "message": "Directory unavailable.", "retryable": true})
	_check((hud.get("_server_browser_title") as Label).text == "SERVER LIST UNAVAILABLE", "error state remains explicit")
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
