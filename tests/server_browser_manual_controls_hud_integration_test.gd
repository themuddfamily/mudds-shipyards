extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []
var _intents: Array[Dictionary] = []
var _network_intents: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.presentation_intent_requested.connect(_on_intent)
	hud.request_server_browser_host()
	_check(_intents.size() == 1 and _intents[0].action == &"host_session", "Host Session forwards caller-owned intent")
	hud.request_server_browser_manual_join()
	_check(_intents.size() == 2 and _intents[1].action == &"manual_join", "Manual Join forwards caller-owned intent")
	var address := hud.get("_server_browser_address") as LineEdit
	var port := hud.get("_server_browser_port") as LineEdit
	var manual := hud.get("_server_browser_page").find_child(
		"ServerBrowserManualJoinButton", true, false
	) as Button
	address.text = "[FE80::1]"
	port.text = "027101"
	manual.grab_focus()
	await process_frame
	var ipv6 := hud.request_server_browser_manual_join()
	await process_frame
	_check(
		ipv6.accepted and address.text == "fe80::1" and port.text == "27101"
			and _intents.size() == 3 and _intents.back().address == "fe80::1"
			and int(_intents.back().port) == 27101,
		"accepted IPv6 and port are echoed and emitted in canonical transport form",
	)
	_check(root.get_viewport().gui_get_focus_owner() == manual, "canonical endpoint echo does not steal action focus")
	address.text = " EXAMPLE.TEST. "
	port.text = "00001"
	var hostname := hud.request_server_browser_manual_join()
	_check(
		hostname.accepted and address.text == "example.test" and port.text == "1"
			and _intents.size() == 4 and _intents.back().address == "example.test"
			and int(_intents.back().port) == 1,
		"accepted hostname and bounded port are echoed and emitted canonically",
	)
	_check(
		not (hud.get("_server_browser_feedback") as Label).text.contains(address.text),
		"canonical form echo does not disclose the endpoint through feedback",
	)
	address.text = "[fe80::1"
	var intent_count_before_rejection := _intents.size()
	var malformed := hud.request_server_browser_manual_join()
	_check(not malformed.accepted and malformed.reason == &"invalid_address", "invalid IPv6 manual join is rejected before intent emission")
	_check(_intents.size() == intent_count_before_rejection, "invalid endpoint emits no caller-owned intent")
	_check(root.get_viewport().gui_get_focus_owner() == address, "manual address rejection restores keyboard focus to the invalid field")
	port.text = "70000"
	var rejected := hud.request_server_browser_host()
	_check(not rejected.accepted and rejected.reason == &"invalid_port", "invalid host port is rejected before intent emission")
	_check((hud.get("_server_browser_feedback") as Label).text.contains("between"), "validation error is visible and readable")
	hud.apply_server_browser_feedback({"accepted": true, "message": "Session host ready."})
	_check((hud.get("_server_browser_feedback") as Label).text == "Session host ready.", "caller-applied session result updates feedback")
	hud.apply_server_browser_result({"accepted": true, "rows": []})
	_check((hud.get("_server_browser_feedback") as Label).text == "", "fresh directory result clears stale request feedback")
	await _check_inline_session_recovery(hud)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SERVER_BROWSER_MANUAL_CONTROLS_HUD_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_inline_session_recovery(hud: HudType) -> void:
	# Use the actual title/browser visibility split: the runtime card is hidden.
	var runtime_hud := hud.get("_hud") as Control
	var opened := hud.open_intro_server_browser()
	var page := hud.get("_server_browser_page") as Control
	var feedback := hud.get("_server_browser_feedback") as Label
	var address := hud.get("_server_browser_address") as LineEdit
	var port := hud.get("_server_browser_port") as LineEdit
	var manual := page.find_child("ServerBrowserManualJoinButton", true, false) as Button
	var action := page.find_child("ServerBrowserDisconnectButton", true, false) as Button
	var back := page.find_child("ServerBrowserBackButton", true, false) as Button
	address.text = " EXAMPLE.TEST. "
	port.text = "027101"
	hud.request_server_browser_manual_join()
	hud.apply_server_browser_feedback({"accepted": true, "message": "Joining session by address."})
	var connecting := _session_snapshot(1, 1, &"connecting", "Contacting the session host.")
	var timeout := _session_snapshot(1, 2, &"disconnected", "Session closed: connection_timeout", true)
	hud.update_network_session_status(connecting)
	hud.update_network_session_status(timeout)
	await process_frame
	var timeout_visible := feedback.text.begins_with("The session host did not admit the connection in time.") \
		and feedback.text.contains("NEXT ACTION // RETRY CONNECTION")
	_check(timeout_visible, "browser displays the accepted session timeout instead of the earlier join acknowledgement")
	# Keep the old build's completion failure singular; fixed-build checks follow.
	if not timeout_visible:
		return
	_check(opened and not runtime_hud.visible and page.is_visible_in_tree() and feedback.is_visible_in_tree(),
		"timeout is visible in the real open title browser while the runtime HUD stays hidden")
	_check(not action.disabled and action.text == "RETRY CONNECTION" and action.focus_mode == Control.FOCUS_ALL
		and manual.focus_neighbor_bottom == manual.get_path_to(action)
		and back.focus_neighbor_top == back.get_path_to(action)
		and manual.focus_neighbor_right == manual.get_path_to(action)
		and action.focus_neighbor_left == action.get_path_to(manual)
		and action.focus_neighbor_right == action.get_path_to(back),
		"inline Retry Connection is enabled and included in keyboard and controller focus navigation")
	action.grab_focus()
	await process_frame
	_check(root.get_viewport().gui_get_focus_owner() == action, "inline Retry Connection can receive focus")
	var browser_intent_count := _intents.size()
	action.pressed.emit()
	var presenter := hud.get("_network_status_presenter") as RefCounted
	var current: Dictionary = presenter.call("get_snapshot")
	_check(_network_intents.size() == 1 and _network_intents.back().action == &"retry"
		and _network_intents.back().snapshot == current
		and current.session_id == "game-flow-inline-recovery" and current.source_generation == 1
		and current.source_sequence == 2 and current.retryable,
		"inline retry forwards the current fenced caller-owned network snapshot")
	_check(_intents.size() == browser_intent_count and address.text == "example.test" and port.text == "27101",
		"retry emits no new browser join and preserves the normalized endpoint")
	var fresh := _session_snapshot(2, 3, &"connecting", "Contacting the session host.")
	hud.update_network_session_status(fresh)
	await process_frame
	_check(feedback.text.begins_with("Contacting the session host.") and not feedback.text.contains("did not admit")
		and action.text == "CANCEL CONNECTION" and not action.disabled
		and root.get_viewport().gui_get_focus_owner() == action,
		"fresh connecting replaces terminal guidance with Cancel Connection without losing focus")
	action.pressed.emit()
	current = presenter.call("get_snapshot")
	_check(_network_intents.size() == 2 and _network_intents.back().action == &"cancel"
		and _network_intents.back().snapshot == current and current.source_generation == 2
		and current.source_sequence == 3,
		"fresh connecting forwards Cancel using the new network snapshot")
	# Local endpoint validation is newer copy than any rejected status receipt.
	address.text = "[fe80::1"
	hud.request_server_browser_manual_join()
	var validation := feedback.text
	var invalid_cursor := _session_snapshot(2, 4, &"disconnected", "Session closed: connection_timeout", true)
	invalid_cursor["sequence"] = "4"
	var invalid_state := _session_snapshot(2, 4, &"unknown_state", "Untrusted status", true)
	var wrong_session := _session_snapshot(2, 4, &"disconnected", "Session closed: connection_timeout", true)
	wrong_session["session_id"] = "other-session"
	var rejected_receipts: Array[Dictionary] = [
		timeout, fresh, _session_snapshot(2, 2, &"connected", "Older status"),
		invalid_cursor, invalid_state, wrong_session,
	]
	for receipt in rejected_receipts:
		hud.update_network_session_status(receipt)
		_check(not validation.is_empty() and feedback.text == validation
			and action.text == "CANCEL CONNECTION" and not action.disabled
			and root.get_viewport().gui_get_focus_owner() == address
			and presenter.call("get_snapshot") == current,
			"rejected stale duplicate or malformed status preserves newer validation, current action and focus")
	var forbidden := _session_snapshot(2, 4, &"disconnected", "Session closed: connection_timeout", false)
	action.grab_focus()
	await process_frame
	hud.update_network_session_status(forbidden)
	await process_frame
	_check(feedback.text.begins_with("The session host did not admit the connection in time.")
		and feedback.text.contains("NEXT ACTION // RETURN TO SESSION MENU")
		and action.disabled and action.focus_mode == Control.FOCUS_NONE
		and manual.focus_neighbor_bottom == manual.get_path_to(back)
		and manual.focus_neighbor_right == manual.get_path_to(back)
		and back.focus_neighbor_top == back.get_path_to(manual)
		and back.focus_neighbor_left == back.get_path_to(manual)
		and root.get_viewport().gui_get_focus_owner() == back
		and hud.get("_server_browser_focus_target") == back,
		"caller-forbidden retry removes the inline action and restores Back focus and navigation")
	var network_count := _network_intents.size()
	action.pressed.emit()
	_check(_network_intents.size() == network_count, "an unavailable inline action cannot emit a stale retry intent")
	hud.update_network_session_status(timeout)
	_check(action.disabled and _network_intents.size() == network_count
		and root.get_viewport().gui_get_focus_owner() == back,
		"retired retryable timeout cannot resurrect retry permission or steal focus")
	_check(address.text == "[fe80::1" and port.text == "27101" and _intents.size() == browser_intent_count,
		"session receipts and action forwarding do not mutate endpoint fields or emit another join")
	# A rejected fenced receipt can retain a legacy presentation without cursor
	# fields. Incoming cursor presence, including the alias, still fences copy.
	var legacy := {"state": &"connecting", "role": &"client", "detail": "Legacy connection progress."}
	hud.update_network_session_status(legacy)
	hud.request_server_browser_manual_join()
	validation = feedback.text
	current = presenter.call("get_snapshot")
	var malformed_legacy_receipts: Array[Dictionary] = [
		{"session_id": "game-flow-inline-recovery"},
		{"generation": "3"},
		{"generation": 3, "sequence": "5"},
		{"generation": 3, "event_sequence": "5"},
	]
	for receipt in malformed_legacy_receipts:
		receipt.merge({"state": &"disconnected", "detail": "Session closed: connection_timeout", "retryable": true})
		hud.update_network_session_status(receipt)
		_check(not validation.is_empty() and feedback.text == validation
			and presenter.call("get_snapshot") == current
			and action.text == "CANCEL CONNECTION" and not action.disabled
			and root.get_viewport().gui_get_focus_owner() == address,
			"malformed incoming cursor or event_sequence alias cannot replay retained legacy copy over validation")
	hud.update_network_session_status(legacy)
	_check(feedback.text.begins_with("Legacy connection progress.")
		and root.get_viewport().gui_get_focus_owner() == address,
		"a genuine unchanged unfenced legacy receipt remains a caller-owned browser update")


func _session_snapshot(generation: int, sequence: int, state: StringName, detail: String, retryable := false) -> Dictionary:
	# Shape published by GameFlow._publish_network_session_snapshot.
	return {
		"session_id": "game-flow-inline-recovery", "generation": generation, "sequence": sequence,
		"state": state, "role": &"client", "detail": detail, "retryable": retryable,
		"local_role": &"observer", "local_peer_id": 1, "controlled_craft": "", "controlled_craft_id": &"",
		"authoritative_snapshot": {}, "authoritative_landing": {},
	}


func _on_intent(kind: StringName, payload: Dictionary) -> void:
	if kind == &"server_browser":
		_intents.append(payload.duplicate(true))
	elif kind == &"network":
		_network_intents.append(payload.duplicate(true))


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
