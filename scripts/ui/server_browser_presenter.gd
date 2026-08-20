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

var _region_filter: StringName = &""
var _max_ping_ms := PING_ANY
var _include_full := true
var _generation := 0
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
	var rows: Array = []
	for source in source_rows:
		if rows.size() >= MAX_ROWS or not source is Dictionary:
			break
		rows.append(_present_row(source as Dictionary))
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"generation": _generation,
		"filters": get_filters(),
		"rows": rows,
		"row_count": rows.size(),
		"accessibility_prompts": get_accessibility_prompts(),
		"presentation_only": true,
		"join_authority": false,
	}
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
		"join_hint": "Select a server to request joining",
	}.duplicate(true)


## A browser row is selectable UI data, not a join command. A host/session
## authority must validate any eventual join request independently.
func request_join(_session_id: StringName) -> Dictionary:
	return {"accepted": false, "reason": &"join_authority_external", "presentation_only": true}


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
	var maximum := int(source.get("max_players", 0))
	var is_full := maximum > 0 and players >= maximum
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
