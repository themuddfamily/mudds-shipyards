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
		var message := str(result.get("message", "Server list unavailable. Try again."))
		var retryable := bool(result.get("retryable", true))
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
		rows.append(_present_row(source as Dictionary))
	return _store_snapshot(_status_snapshot(
		&"ready" if not rows.is_empty() else &"empty",
		rows,
		&"" if not rows.is_empty() else &"no_matches",
		"" if not rows.is_empty() else "No matching servers.",
		false
	))


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
	if clean_address.is_empty() or clean_address.length() > MAX_ADDRESS_LENGTH or clean_address.contains(" "):
		return _validation_error(&"invalid_address", "Enter a valid host address or name.")
	var validation := _validate_port(port)
	if not bool(validation.get("accepted", false)):
		return validation
	validation = _validate_player_name(player_name)
	if not bool(validation.get("accepted", false)):
		return validation
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
		"player_count": players,
		"max_players": maximum,
		"occupancy_label": "%d/%d players" % [players, maximum],
		"capacity_label": "FULL" if is_full else "AVAILABLE",
		"capacity_generation": capacity_generation,
		"full": is_full,
		"selectable": true,
		"stale": false,
		"join_authority": false,
	}.duplicate(true)


func _region_label(value: Variant) -> String:
	var text := str(value).replace("_", "-")
	return text.to_upper()


func _human_ping_label(value: Variant, ping_ms: int) -> String:
	if ping_ms < 0 or str(value) == "unavailable":
		return "Unavailable"
	match str(value):
		"fast": return "Fast"
		"medium": return "Medium"
		"slow": return "Slow"
	return "%d ms" % ping_ms


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
