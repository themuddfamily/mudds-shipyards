class_name ServerBrowserPresenter
extends RefCounted

## Detached presentation contract for the server browser.
##
## The network directory owns freshness and records. This presenter only turns
## a browser query into immutable UI rows and textual accessibility prompts; it
## never reserves a slot, opens a socket, or grants join authority.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"server-browser-presenter"
const MAX_ROWS := 256
const MAX_REGION_FILTER_LENGTH := 32
const PING_ANY := -1
const DEFAULT_PORT := 27101
const MIN_PORT := 1
const MAX_PORT := 65535
const MAX_ADDRESS_LENGTH := 253
const MAX_PLAYER_NAME_LENGTH := 32

var _region_filter: StringName = &""
var _max_ping_ms := PING_ANY
var _include_full := true
var _generation := 0
var _latest_capacity_generation := 0
var _last_snapshot: Dictionary = {}
var _last_unfiltered_rows: Array = []
var _focus_target: StringName = &"refresh"
var _manual_connect: Dictionary = {"address": "", "port": DEFAULT_PORT, "player_name": "", "error": "", "focus_target": &"manual_address"}
var _accessibility_filters: Dictionary = {
	"compatible_only": false,
	"not_full": false,
	"no_password": false,
	"latency_band": &"",
}
var _sort_key: StringName = &"name"
var _sort_descending := false
var _request_generation := 0
var _pending_request_generation := 0
var _source_directory_generation := -1
var _source_sequence := -1
var _source_server_tick := -1
var _source_receipt_sequence := -1
var _source_fenced := false
var _attached := true


func configure_filters(region_filter: StringName = &"", max_ping_ms: int = PING_ANY, include_full: bool = true) -> Dictionary:
	var region := String(region_filter).strip_edges()
	if region.length() > MAX_REGION_FILTER_LENGTH:
		return _reject(&"invalid_region_filter")
	if max_ping_ms < PING_ANY or max_ping_ms > 60_000:
		return _reject(&"invalid_ping_filter")
	_region_filter = StringName(region)
	_max_ping_ms = max_ping_ms
	_include_full = include_full
	_generation += 1
	return {"accepted": true, "reason": &"filters_applied", "generation": _generation, "filters": get_filters()}


## Pull a fresh, presentation-only snapshot. The browser's query performs the
## stale-row check; this method never retains or edits directory records.
func present(browser: RefCounted) -> Dictionary:
	if browser == null or not browser.has_method("query"):
		return _reject(&"invalid_browser")
	_attached = true
	var source_rows: Array = browser.query(_region_filter, _max_ping_ms, _include_full)
	return present_result({"accepted": true, "rows": source_rows})


## Consumes a caller-owned directory result without assuming how it was fetched.
## Error actions are intents for the owning screen; this presenter never retries,
## cancels a request, or touches a network transport.
func present_result(result: Dictionary) -> Dictionary:
	if not _attached:
		return _ignored_result(result, &"view_detached")
	var cursor := _result_cursor(result)
	if bool(cursor.get("fenced", false)):
		if not bool(cursor.get("valid", false)):
			return _ignored_result(result, &"invalid_result_cursor")
		var has_request_fence := bool(cursor.get("has_request", false))
		if has_request_fence and int(cursor.get("request_generation", 0)) != _pending_request_generation:
			return _ignored_result(result, &"request_generation_mismatch")
		if bool(cursor.get("source_fenced", false)) and _pending_request_generation > 0 and not has_request_fence:
			return _ignored_result(result, &"request_generation_required")
		if bool(cursor.get("source_fenced", false)):
			var directory_generation := int(cursor.get("directory_generation", -1))
			var sequence := int(cursor.get("sequence", -1))
			var directory_advanced := directory_generation > _source_directory_generation
			if _source_fenced and directory_generation < _source_directory_generation:
				return _ignored_result(result, &"source_cursor_not_advanced")
			if _source_fenced and not directory_advanced:
				if bool(cursor.get("has_receipt_sequence", false)):
					if _source_receipt_sequence >= 0 and int(cursor.get("receipt_sequence", -1)) <= _source_receipt_sequence:
						return _ignored_result(result, &"source_cursor_not_advanced")
					if _source_receipt_sequence < 0:
						if bool(cursor.get("has_server_tick", false)) and _source_server_tick >= 0 \
								and int(cursor.get("server_tick", -1)) < _source_server_tick:
							return _ignored_result(result, &"source_cursor_not_advanced")
						if not bool(cursor.get("has_server_tick", false)) and _source_sequence >= 0 \
								and int(cursor.get("receipt_sequence", -1)) <= _source_sequence:
							return _ignored_result(result, &"source_cursor_not_advanced")
				else:
					var source_tick_floor := _source_server_tick if _source_server_tick >= 0 else _source_sequence
					if source_tick_floor >= 0 and int(cursor.get("server_tick", -1)) <= source_tick_floor:
						return _ignored_result(result, &"source_cursor_not_advanced")
			if directory_advanced:
				_source_server_tick = -1
				_source_receipt_sequence = -1
			_source_fenced = true
			_source_directory_generation = directory_generation
			_source_sequence = sequence
			if bool(cursor.get("has_receipt_sequence", false)):
				_source_receipt_sequence = int(cursor.get("receipt_sequence", -1))
			if bool(cursor.get("has_server_tick", false)):
				_source_server_tick = int(cursor.get("server_tick", -1))
	var requested_status := StringName(str(result.get("status", &"")))
	if requested_status == &"expired" or result.get("reason", &"") in [&"directory_expired", &"results_expired"]:
		_focus_target = &"retry"
		return _complete_result(_status_snapshot(
			&"expired", [], &"directory_expired",
			"Server list expired. Refresh to see current servers.", true
		))
	if not bool(result.get("accepted", false)):
		var reason := StringName(str(result.get("reason", &"directory_unavailable")))
		var message := _status_reason_message(reason, str(result.get("message", "")))
		var retryable := bool(result.get("retryable", true))
		var retry_after_milliseconds := maxi(int(result.get("retry_after_milliseconds", 0)), 0)
		if retryable and retry_after_milliseconds > 0:
			message = "%s. Retry in %d ms." % [message.trim_suffix("."), retry_after_milliseconds]
		_focus_target = &"retry" if retryable else &"cancel"
		var failed := _status_snapshot(&"error", [], reason, message, retryable)
		failed["retry_after_milliseconds"] = retry_after_milliseconds
		return _complete_result(failed)
	var source_rows: Array = result.get("rows", []) as Array
	var newest_capacity_generation := _latest_capacity_generation
	for source in source_rows:
		if source is Dictionary:
			newest_capacity_generation = maxi(
				newest_capacity_generation,
				int((source as Dictionary).get("capacity_generation", (source as Dictionary).get("generation", 0)))
			)
	_latest_capacity_generation = newest_capacity_generation
	var rows: Array = []
	for source in source_rows:
		if rows.size() >= MAX_ROWS or not source is Dictionary:
			break
		var source_generation := int((source as Dictionary).get("capacity_generation", (source as Dictionary).get("generation", 0)))
		if source_generation > 0 and source_generation < _latest_capacity_generation:
			continue
		var row := _present_row(source as Dictionary)
		rows.append(row)
	_last_unfiltered_rows = rows.duplicate(true)
	var filtered_rows := _sort_rows(_filter_rows(_last_unfiltered_rows))
	var all_full := not filtered_rows.is_empty() and filtered_rows.all(
		func(row: Variant) -> bool: return bool((row as Dictionary).get("full", false))
	)
	var prior_focus := _focus_target
	if all_full:
		_focus_target = &"refresh"
	elif prior_focus.begins_with("row:") and filtered_rows.any(func(row: Variant) -> bool: return "row:%s" % str((row as Dictionary).get("session_id", "")) == prior_focus):
		_focus_target = prior_focus
	elif not filtered_rows.is_empty():
		_focus_target = &"row:%s" % str(filtered_rows[0].get("session_id", ""))
	else:
		_focus_target = &"refresh"
	var status: StringName = &"full" if all_full else (&"ready" if not filtered_rows.is_empty() else &"empty")
	var message := (
		_full_status_message(filtered_rows.size())
		if all_full else (
			"%d session%s available." % [filtered_rows.size(), "" if filtered_rows.size() == 1 else "s"]
			if not filtered_rows.is_empty() else (
				"No sessions match active filters." if _has_active_filters() else "No matching servers."
			)
		)
	)
	return _complete_result(_status_snapshot(
		status,
		filtered_rows,
		&"" if not filtered_rows.is_empty() else &"no_matches",
		message,
		false
	))


func set_accessibility_filters(filters: Dictionary) -> Dictionary:
	var band := StringName(str(filters.get("latency_band", _accessibility_filters.latency_band)))
	if band not in [&"", &"excellent", &"good", &"poor", &"unknown"]:
		return {"accepted": false, "reason": &"invalid_latency_band", "presentation_only": true}
	_accessibility_filters = {
		"compatible_only": bool(filters.get("compatible_only", _accessibility_filters.compatible_only)),
		"not_full": bool(filters.get("not_full", _accessibility_filters.not_full)),
		"no_password": bool(filters.get("no_password", _accessibility_filters.no_password)),
		"latency_band": band,
	}
	_generation += 1
	return _refresh_filtered_snapshot()


func clear_accessibility_filters() -> Dictionary:
	return set_accessibility_filters({"compatible_only": false, "not_full": false, "no_password": false, "latency_band": &""})


func get_accessibility_filters() -> Dictionary:
	return _accessibility_filters.duplicate(true)


func set_sort(key: StringName, descending: bool = false) -> Dictionary:
	if key not in [&"name", &"latency", &"occupancy", &"compatible_first"]:
		return {"accepted": false, "reason": &"invalid_sort_key", "presentation_only": true}
	_sort_key = key
	_sort_descending = descending
	_generation += 1
	return _refresh_filtered_snapshot()


func clear_sort() -> Dictionary:
	return set_sort(&"name", false)


func get_sort() -> Dictionary:
	return {"key": _sort_key, "descending": _sort_descending, "summary": _sort_summary()}


func set_focus_target(control_id: StringName) -> Dictionary:
	var allowed := [&"refresh", &"retry", &"cancel", &"host_session", &"manual_join", &"compatible_only", &"not_full", &"no_password", &"latency_band", &"clear_filters"]
	if not allowed.has(control_id) and not control_id.begins_with("row:"):
		return {"accepted": false, "reason": &"unknown_focus_target", "presentation_only": true}
	_focus_target = control_id
	if _last_snapshot.is_empty():
		return {"accepted": true, "reason": &"focus_target_set", "focus_target": _focus_target, "presentation_only": true}
	_last_snapshot["focus_target"] = _focus_target
	var focused := _last_snapshot.duplicate(true)
	focused["accepted"] = true
	focused["reason"] = &"focus_target_set"
	return focused


func request_retry() -> Dictionary:
	if _last_snapshot.get("status", &"") not in [&"error", &"expired"] or not bool(_last_snapshot.get("retryable", false)):
		return {"accepted": false, "reason": &"retry_not_available", "presentation_only": true}
	return begin_refresh(&"retry")


## Starts one caller-owned directory request and returns its fence. The caller
## echoes request_generation in the eventual result; older completions are
## ignored after another refresh or after close_view(). No clock is owned here.
func begin_refresh(focus_target: StringName = &"refresh") -> Dictionary:
	_request_generation += 1
	_pending_request_generation = _request_generation
	_attached = true
	_focus_target = focus_target if focus_target in [&"refresh", &"retry"] else &"refresh"
	_last_unfiltered_rows.clear()
	var refreshing := _status_snapshot(
		&"refreshing", [], &"refresh_requested", "Refreshing server list…", false
	)
	refreshing["request_generation"] = _pending_request_generation
	_store_snapshot(refreshing)
	return {
		"accepted": true,
		"reason": &"retry_requested" if _focus_target == &"retry" else &"refresh_requested",
		"request_generation": _pending_request_generation,
		"presentation": refreshing.duplicate(true),
		"presentation_only": true,
	}


## Invalidates an in-flight result and drops transient rows/status while
## retaining filters, sort, and the validated manual-connect form for re-entry.
func close_view() -> Dictionary:
	_request_generation += 1
	_pending_request_generation = 0
	_attached = false
	_source_directory_generation = -1
	_source_sequence = -1
	_source_server_tick = -1
	_source_receipt_sequence = -1
	_source_fenced = false
	_latest_capacity_generation = 0
	if _focus_target in [&"retry", &"cancel"] or _focus_target.begins_with("row:"):
		_focus_target = &"refresh"
	_last_unfiltered_rows.clear()
	_last_snapshot = _status_snapshot(&"idle", [], &"", "Select refresh to find available sessions.", false)
	_last_snapshot["request_generation"] = _request_generation
	return _last_snapshot.duplicate(true)


func request_cancel() -> Dictionary:
	return {"accepted": true, "reason": &"cancel_requested", "presentation_only": true}


func _status_snapshot(status: StringName, rows: Array, reason: StringName, message: String, retryable: bool) -> Dictionary:
	var actions: Array = []
	if status in [&"error", &"expired"]:
		if retryable:
			actions.append({"id": &"retry", "label": "Retry server list", "focusable": true})
		actions.append({"id": &"cancel", "label": "Cancel", "focusable": true})
	var next_action := _next_action(status, retryable)
	var status_message := _message_with_next_action(message, next_action)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"generation": _generation,
		"filters": get_filters(),
		"rows": rows,
		"row_count": rows.size(),
		"status": status,
		"error_code": reason,
		"error_message": status_message,
		"retryable": retryable,
		"request_generation": _pending_request_generation,
		"directory_generation": _source_directory_generation,
		"source_sequence": _source_sequence,
		"source_fenced": _source_fenced,
		"attached": _attached,
		"next_action": next_action,
		"next_action_text": "NEXT ACTION // %s" % next_action,
		"actions": actions,
		"focus_target": _focus_target,
		"focus_order": [&"refresh", &"host_session", &"manual_join", &"compatible_only", &"not_full", &"no_password", &"latency_band", &"clear_filters", &"retry", &"cancel"],
		"accessibility_filters": get_accessibility_filters(),
		"active_filter_summary": _active_filter_summary(),
		"filter_controls": [
			{"id": &"compatible_only", "label": "Compatible only", "focusable": true},
			{"id": &"not_full", "label": "Not full", "focusable": true},
			{"id": &"no_password", "label": "No password", "focusable": true},
			{"id": &"latency_band", "label": "Latency band", "focusable": true},
			{"id": &"clear_filters", "label": "Clear filters", "focusable": true},
		],
		"sort": get_sort(),
		"sort_controls": [
			{"id": &"sort_key", "label": "Sort by", "focusable": true},
			{"id": &"sort_direction", "label": "Sort direction", "focusable": true},
			{"id": &"clear_sort", "label": "Clear sort", "focusable": true},
		],
		"controls": _browser_controls(),
		"accessibility_prompts": get_accessibility_prompts(),
		"presentation_only": true,
		"join_authority": false,
		"color_independent": true,
	}


func _store_snapshot(snapshot: Dictionary) -> Dictionary:
	_last_snapshot = snapshot.duplicate(true)
	return snapshot


func _complete_result(snapshot: Dictionary) -> Dictionary:
	var completed_request_generation := _pending_request_generation
	_pending_request_generation = 0
	snapshot["request_generation"] = completed_request_generation
	return _store_snapshot(snapshot)


func get_filters() -> Dictionary:
	return {
		"region": _region_filter,
		"max_ping_ms": _max_ping_ms,
		"include_full": _include_full,
	}.duplicate(true)


func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


func get_accessibility_prompts() -> Dictionary:
	return {
		"region_filter": "Filter region",
		"ping_filter": "Maximum ping",
		"full_sessions": "Show full sessions",
		"refresh": "Refresh server list",
		"empty_results": "No matching servers",
		"stale_results": "Refresh to see current servers",
		"error_results": "Server list unavailable",
		"retry": "Retry server list",
		"cancel": "Cancel",
		"join_hint": "Select a server to request joining",
		"focus_target": "Current keyboard/controller focus target",
		"focus_marker": "[FOCUS]",
		"status_reason": "Connection status reason",
	}.duplicate(true)


## A browser row is selectable UI data, not a join command. A host/session
## authority must validate any eventual join request independently.
func request_join(_session_id: StringName) -> Dictionary:
	return {"accepted": false, "reason": &"join_authority_external", "presentation_only": true}


func host_session_intent(port: int = DEFAULT_PORT, player_name: String = "") -> Dictionary:
	var validation := _validate_port(port)
	if not bool(validation.get("accepted", false)):
		return validation
	validation = _validate_player_name(player_name)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"reason": &"host_requested",
		"action": &"host_session",
		"port": port,
		"player_name": player_name.strip_edges(),
		"presentation_only": true,
		"authority": false,
	}


func manual_join_intent(address: String, port: int = DEFAULT_PORT, player_name: String = "") -> Dictionary:
	var clean_address := address.strip_edges()
	var address_validation := _validate_address(clean_address)
	if not bool(address_validation.get("accepted", false)):
		_focus_target = &"manual_address"
		_manual_connect.error = str(address_validation.get("validation_error", "Enter a valid host address or name."))
		return address_validation
	var validation := _validate_port(port)
	if not bool(validation.get("accepted", false)):
		_focus_target = &"manual_port"
		_manual_connect.error = str(validation.get("validation_error", "Enter a valid port."))
		return validation
	validation = _validate_player_name(player_name)
	if not bool(validation.get("accepted", false)):
		_focus_target = &"manual_player_name"
		_manual_connect.error = str(validation.get("validation_error", "Enter a player name."))
		return validation
	_manual_connect = {"address": clean_address, "port": port, "player_name": player_name.strip_edges(), "error": "", "focus_target": &"manual_join"}
	_focus_target = &"manual_join"
	return {
		"accepted": true,
		"reason": &"manual_join_requested",
		"action": &"manual_join",
		"address": clean_address,
		"port": port,
		"player_name": player_name.strip_edges(),
		"presentation_only": true,
		"authority": false,
	}


func configure_manual_connect(address: String, port: int = DEFAULT_PORT, player_name: String = "") -> Dictionary:
	_manual_connect["address"] = address.strip_edges()
	_manual_connect["port"] = port
	_manual_connect["player_name"] = player_name.strip_edges()
	var result := manual_join_intent(address, port, player_name)
	_manual_connect["error"] = str(result.get("validation_error", ""))
	_manual_connect["focus_target"] = _focus_target
	return {
		"accepted": bool(result.get("accepted", false)),
		"form": _manual_connect.duplicate(true),
		"intent": result.duplicate(true),
		"focus_target": _focus_target,
		"presentation_only": true,
	}


func get_manual_connect_view() -> Dictionary:
	return {"form": _manual_connect.duplicate(true), "focus_target": _focus_target, "actions": [{"id": &"manual_join", "label": "Connect", "focusable": true}, {"id": &"cancel", "label": "Cancel", "focusable": true}], "presentation_only": true}


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"presentation_only": true,
		"uses_directory_query": true,
		"filters_stale_rows": true,
		"browser_owns_join_authority": false,
		"opens_sockets": false,
		"accessibility_prompts_textual": true,
		"exact_source_cursor_fencing": true,
		"color_independent_next_action": true,
	}


func _present_row(source: Dictionary) -> Dictionary:
	var ping_ms := int(source.get("ping_ms", -1))
	var ping_label := _human_ping_label(source.get("ping_label", &"unavailable"), ping_ms)
	var password_label := _password_label(source)
	var compatibility_label := _compatibility_label(source)
	var players := int(source.get("player_count", 0))
	var maximum := clampi(int(source.get("max_players", 0)), 0, 256)
	players = clampi(players, 0, maximum if maximum > 0 else 256)
	var is_full := maximum > 0 and players >= maximum
	var capacity_generation := maxi(int(source.get("capacity_generation", source.get("generation", 0))), 0)
	return {
		"session_id": source.get("session_id", &""),
		"title": str(source.get("title", "")),
		"region": str(source.get("region_id", "")),
		"region_label": _region_label(source.get("region_id", "")),
		"ping_ms": ping_ms,
		"ping_label": ping_label,
		"latency_band": ping_label,
		"password_label": password_label,
		"compatibility_label": compatibility_label,
		"player_count": players,
		"max_players": maximum,
		"occupancy_label": "%d/%d players" % [players, maximum],
		"capacity_label": "FULL" if is_full else "AVAILABLE",
		"capacity_generation": capacity_generation,
		"full": is_full,
		"selectable": true,
		"focus_label": "[ ] %s  //  %s  //  %s  //  %s  //  %s  //  SELECT TO REQUEST JOINING" % [
			str(source.get("title", "Server")),
			ping_label,
			"%d/%d players" % [players, maximum],
			password_label,
			compatibility_label,
		],
		"focus_marker": "[ ]",
		"stale": false,
		"join_authority": false,
	}.duplicate(true)


func _result_cursor(result: Dictionary) -> Dictionary:
	var has_request := result.has("request_generation")
	var has_directory_generation := result.has("directory_generation")
	var has_receipt_sequence := result.has("sequence") or result.has("snapshot_sequence")
	var has_server_tick := result.has("server_tick")
	var has_sequence := has_receipt_sequence or has_server_tick
	var fenced := has_request or has_directory_generation or has_sequence
	var source_fenced := has_directory_generation or has_sequence
	var request_variant: Variant = result.get("request_generation", null)
	var directory_variant: Variant = result.get("directory_generation", null)
	var receipt_sequence_variant: Variant = result.get("sequence", result.get("snapshot_sequence", null))
	var server_tick_variant: Variant = result.get("server_tick", null)
	var sequence_variant: Variant = receipt_sequence_variant if has_receipt_sequence else server_tick_variant
	return {
		"fenced": fenced,
		"has_request": has_request,
		"source_fenced": source_fenced,
		"valid": not fenced or (
			(not has_request or (request_variant is int and int(request_variant) > 0))
			and (not source_fenced or (
				directory_variant is int and int(directory_variant) >= 0
				and has_sequence
				and (not has_receipt_sequence or (receipt_sequence_variant is int and int(receipt_sequence_variant) >= 0))
				and (not has_server_tick or (server_tick_variant is int and int(server_tick_variant) >= 0))
			))
		),
		"has_receipt_sequence": has_receipt_sequence,
		"has_server_tick": has_server_tick,
		"request_generation": int(request_variant) if request_variant is int else 0,
		"directory_generation": int(directory_variant) if directory_variant is int else -1,
		"receipt_sequence": int(receipt_sequence_variant) if receipt_sequence_variant is int else -1,
		"server_tick": int(server_tick_variant) if server_tick_variant is int else -1,
		"sequence": int(sequence_variant) if sequence_variant is int else -1,
	}


func _ignored_result(result: Dictionary, fence_reason: StringName) -> Dictionary:
	var retained := _last_snapshot.duplicate(true)
	if retained.is_empty():
		retained = _status_snapshot(&"idle", [], &"", "Select refresh to find available sessions.", false)
	retained["accepted"] = false
	retained["reason"] = &"stale_result_ignored"
	retained["fence_reason"] = fence_reason
	retained["ignored_request_generation"] = int(result.get("request_generation", 0))
	retained["ignored_directory_generation"] = int(result.get("directory_generation", -1))
	retained["ignored_source_sequence"] = int(result.get(
		"sequence", result.get("snapshot_sequence", result.get("server_tick", -1))
	))
	retained["request_generation"] = _pending_request_generation
	retained["presentation_only"] = true
	return retained


func _next_action(status: StringName, retryable: bool) -> String:
	match status:
		&"refreshing": return "WAIT FOR RESULTS OR RETURN"
		&"ready": return "SELECT A SESSION TO REQUEST JOINING OR REFRESH"
		&"full": return "REFRESH SERVER LIST OR RETURN"
		&"empty": return "REFRESH SERVER LIST"
		&"expired": return "RETRY SERVER LIST OR CANCEL"
		&"error": return "RETRY SERVER LIST OR CANCEL" if retryable else "CANCEL AND RETURN"
		&"idle": return "REFRESH SERVER LIST"
	return "REVIEW SERVER LIST STATUS"


func _message_with_next_action(message: String, next_action: String) -> String:
	return "%s\nNEXT ACTION // %s" % [message, next_action] if not next_action.is_empty() else message


func _full_status_message(row_count: int) -> String:
	return "The only session is full." if row_count == 1 else "All %d sessions are full." % row_count


func _region_label(value: Variant) -> String:
	var text := str(value).replace("_", "-")
	return text.to_upper()


func _human_ping_label(value: Variant, ping_ms: int) -> String:
	if ping_ms < 0:
		return "Latency Unknown"
	if ping_ms <= 80:
		return "Latency Excellent"
	if ping_ms <= 160:
		return "Latency Good"
	return "Latency Poor"


func _password_label(source: Dictionary) -> String:
	if bool(source.get("password_required", source.get("password_protected", false))):
		return "Password Required"
	return "No Password"


func _compatibility_label(source: Dictionary) -> String:
	if source.has("compatible"):
		return "Compatible" if bool(source.get("compatible")) else "Incompatible"
	var status := str(source.get("compatibility", "unknown")).to_lower()
	if status in ["compatible", "ok", "ready"]:
		return "Compatible"
	if status in ["incompatible", "unsupported", "mismatch"]:
		return "Incompatible"
	return "Compatibility Unknown"


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation}


func _browser_controls() -> Array[Dictionary]:
	return [
		{"id": &"host_session", "label": "Host Session", "focusable": true, "authority": false},
		{"id": &"manual_join", "label": "Manual Join", "focusable": true, "authority": false},
	]


func _validate_port(port: int) -> Dictionary:
	if port < MIN_PORT or port > MAX_PORT:
		return _validation_error(&"invalid_port", "Port must be between %d and %d." % [MIN_PORT, MAX_PORT])
	return {"accepted": true}


func _validate_address(address: String) -> Dictionary:
	if address.is_empty() or address.length() > MAX_ADDRESS_LENGTH or address.contains(" ") or address.contains("\n") or address.contains("\r"):
		return _validation_error(&"invalid_address", "Enter a valid IPv4, IPv6-local, or host name.")
	if address.begins_with("[") and not address.ends_with("]"):
		return _validation_error(&"invalid_address", "IPv6 addresses must close with ].")
	return {"accepted": true}


func _validate_player_name(player_name: String) -> Dictionary:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > MAX_PLAYER_NAME_LENGTH:
		return _validation_error(&"invalid_player_name", "Player name must be 1–%d characters." % MAX_PLAYER_NAME_LENGTH)
	return {"accepted": true}


func _validation_error(reason: StringName, message: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"validation_error": message,
		"message": message,
		"presentation_only": true,
		"authority": false,
}


func _filter_rows(rows: Array) -> Array:
	var filtered: Array = []
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		if _accessibility_filters.compatible_only and row.get("compatibility_label") != "Compatible":
			continue
		if _accessibility_filters.not_full and bool(row.get("full", false)):
			continue
		if _accessibility_filters.no_password and row.get("password_label") != "No Password":
			continue
		var band := String(_accessibility_filters.latency_band)
		if not band.is_empty() and str(row.get("latency_band", "")).to_lower() != "latency " + band:
			continue
		filtered.append(row)
	return filtered


func _has_active_filters() -> bool:
	return bool(_accessibility_filters.compatible_only) or bool(_accessibility_filters.not_full) or bool(_accessibility_filters.no_password) or not String(_accessibility_filters.latency_band).is_empty()


func _active_filter_summary() -> String:
	var active: Array[String] = []
	if _accessibility_filters.compatible_only: active.append("COMPATIBLE ONLY")
	if _accessibility_filters.not_full: active.append("NOT FULL")
	if _accessibility_filters.no_password: active.append("NO PASSWORD")
	if not String(_accessibility_filters.latency_band).is_empty(): active.append("LATENCY %s" % String(_accessibility_filters.latency_band).to_upper())
	return "FILTERS: " + ", ".join(active) if not active.is_empty() else "FILTERS: NONE"


func _refresh_filtered_snapshot() -> Dictionary:
	if _last_snapshot.is_empty():
		return {"accepted": true, "reason": &"filters_applied", "filters": get_accessibility_filters(), "active_filter_summary": _active_filter_summary(), "presentation_only": true}
	var filtered := _sort_rows(_filter_rows(_last_unfiltered_rows))
	var all_full := not filtered.is_empty() and filtered.all(
		func(row: Variant) -> bool: return bool((row as Dictionary).get("full", false))
	)
	var status: StringName = &"full" if all_full else (&"ready" if not filtered.is_empty() else &"empty")
	var message := (
		_full_status_message(filtered.size())
		if all_full else (
			"%d session%s available." % [filtered.size(), "" if filtered.size() == 1 else "s"]
			if not filtered.is_empty() else (
				"No sessions match active filters." if _has_active_filters() else "No matching servers."
			)
		)
	)
	var next_action := _next_action(status, false)
	if all_full:
		_focus_target = &"refresh"
	_last_snapshot["rows"] = filtered
	_last_snapshot["row_count"] = filtered.size()
	_last_snapshot["status"] = status
	_last_snapshot["error_code"] = &"" if not filtered.is_empty() else &"no_matches"
	_last_snapshot["error_message"] = _message_with_next_action(message, next_action)
	_last_snapshot["next_action"] = next_action
	_last_snapshot["next_action_text"] = "NEXT ACTION // %s" % next_action
	_last_snapshot["focus_target"] = _focus_target
	_last_snapshot["generation"] = _generation
	_last_snapshot["accessibility_filters"] = get_accessibility_filters()
	_last_snapshot["active_filter_summary"] = _active_filter_summary()
	_last_snapshot["sort"] = get_sort()
	var refreshed := _last_snapshot.duplicate(true)
	refreshed["accepted"] = true
	refreshed["reason"] = &"filters_applied"
	return refreshed


func _sort_rows(rows: Array) -> Array:
	var sorted := rows.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_value: Variant = _sort_value(a)
		var b_value: Variant = _sort_value(b)
		if a_value == b_value:
			return str(a.get("session_id", "")) < str(b.get("session_id", ""))
		return b_value < a_value if _sort_descending else a_value < b_value
	)
	return sorted


func _sort_value(row: Dictionary) -> Variant:
	match _sort_key:
		&"latency": return int(row.get("ping_ms", -1)) if int(row.get("ping_ms", -1)) >= 0 else 2147483647
		&"occupancy":
			var maximum := maxf(float(row.get("max_players", 0)), 1.0)
			return float(row.get("player_count", 0)) / maximum
		&"compatible_first":
			return {"Compatible": 0, "Compatibility Unknown": 1, "Incompatible": 2}.get(str(row.get("compatibility_label", "Compatibility Unknown")), 1)
		_:
			return str(row.get("title", "")).to_lower()


func _sort_summary() -> String:
	var names := {&"name": "NAME", &"latency": "LATENCY", &"occupancy": "OCCUPANCY", &"compatible_first": "COMPATIBLE FIRST"}
	return "SORT: %s %s" % [names.get(_sort_key, "NAME"), "↓" if _sort_descending else "↑"]


func _status_reason_message(reason: StringName, fallback: String) -> String:
	var known := {
		&"directory_timeout": "Server directory timed out. Retry is available.",
		&"directory_unavailable": "Server directory is unavailable. Retry is available.",
		&"directory_closed": "Server directory is closed. Cancel to return.",
		&"session_full": "That session is full. Choose another server.",
		&"join_failed": "Joining the selected session failed. Retry is available.",
	}
	return str(known.get(reason, fallback if not fallback.is_empty() else "Server directory unavailable."))
