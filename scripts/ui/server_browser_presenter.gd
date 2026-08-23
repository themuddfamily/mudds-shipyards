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
	var source_rows: Array = browser.query(_region_filter, _max_ping_ms, _include_full)
	return present_result({"accepted": true, "rows": source_rows})


## Consumes a caller-owned directory result without assuming how it was fetched.
## Error actions are intents for the owning screen; this presenter never retries,
## cancels a request, or touches a network transport.
func present_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("accepted", false)):
		var reason := StringName(str(result.get("reason", &"directory_unavailable")))
		var message := _status_reason_message(reason, str(result.get("message", "")))
		var retryable := bool(result.get("retryable", true))
		_focus_target = &"retry" if retryable else &"cancel"
		return _store_snapshot(_status_snapshot(&"error", [], reason, message, retryable))
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
	var filtered_rows := _filter_rows(_last_unfiltered_rows)
	if not rows.is_empty():
		_focus_target = &"row:%s" % str(rows[0].get("session_id", ""))
	else:
		_focus_target = &"refresh"
	return _store_snapshot(_status_snapshot(
		&"ready" if not filtered_rows.is_empty() else &"empty",
		filtered_rows,
		&"" if not filtered_rows.is_empty() else &"no_matches",
		"" if not filtered_rows.is_empty() else ("No sessions match active filters." if _has_active_filters() else "No matching servers."),
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
	if _last_snapshot.get("status", &"") != &"error" or not bool(_last_snapshot.get("retryable", false)):
		return {"accepted": false, "reason": &"retry_not_available", "presentation_only": true}
	return {"accepted": true, "reason": &"retry_requested", "presentation_only": true}


func request_cancel() -> Dictionary:
	return {"accepted": true, "reason": &"cancel_requested", "presentation_only": true}


func _status_snapshot(status: StringName, rows: Array, reason: StringName, message: String, retryable: bool) -> Dictionary:
	var actions: Array = []
	if status == &"error":
		if retryable:
			actions.append({"id": &"retry", "label": "Retry server list", "focusable": true})
		actions.append({"id": &"cancel", "label": "Cancel", "focusable": true})
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"generation": _generation,
		"filters": get_filters(),
		"rows": rows,
		"row_count": rows.size(),
		"status": status,
		"error_code": reason,
		"error_message": message,
		"retryable": retryable,
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
		"controls": _browser_controls(),
		"accessibility_prompts": get_accessibility_prompts(),
		"presentation_only": true,
		"join_authority": false,
	}


func _store_snapshot(snapshot: Dictionary) -> Dictionary:
	_last_snapshot = snapshot.duplicate(true)
	return snapshot


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
		"focus_label": "[ ] %s  //  %s  //  %s  //  %s  //  %s" % [
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
	var filtered := _filter_rows(_last_unfiltered_rows)
	_last_snapshot["rows"] = filtered
	_last_snapshot["row_count"] = filtered.size()
	_last_snapshot["status"] = &"ready" if not filtered.is_empty() else &"empty"
	_last_snapshot["error_message"] = "" if not filtered.is_empty() else ("No sessions match active filters." if _has_active_filters() else "No matching servers.")
	_last_snapshot["generation"] = _generation
	_last_snapshot["accessibility_filters"] = get_accessibility_filters()
	_last_snapshot["active_filter_summary"] = _active_filter_summary()
	var refreshed := _last_snapshot.duplicate(true)
	refreshed["accepted"] = true
	refreshed["reason"] = &"filters_applied"
	return refreshed


func _status_reason_message(reason: StringName, fallback: String) -> String:
	var known := {
		&"directory_timeout": "Server directory timed out. Retry is available.",
		&"directory_unavailable": "Server directory is unavailable. Retry is available.",
		&"directory_closed": "Server directory is closed. Cancel to return.",
		&"session_full": "That session is full. Choose another server.",
		&"join_failed": "Joining the selected session failed. Retry is available.",
	}
	return str(known.get(reason, fallback if not fallback.is_empty() else "Server directory unavailable."))
