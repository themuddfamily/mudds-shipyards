class_name NetworkSessionStatusPresenter
extends RefCounted

## Presentation-only network session state. The caller owns transport,
## admission, host/join authority, and all lifecycle transitions.

const COMPONENT_ID: StringName = &"network-session-status-presenter"
const STATES := [&"connecting", &"reconnecting", &"connected", &"failed", &"rejected", &"disconnected", &"migrating"]
const LOCAL_ROLES := [&"pilot", &"passenger", &"observer"]
const REPAIR_STATES := [&"started", &"progress", &"completed", &"aborted"]
const MAX_REPAIR_PRESENTATIONS := 8
const SESSION_END_MESSAGES := {
	&"timeout": "Session timed out.",
	&"rejected": "Session request was rejected.",
	&"protocol_mismatch": "Session protocol is incompatible.",
	&"host_migration": "Session host changed.",
	&"manual_leave": "You left the session.",
	&"unknown": "Session ended.",
}

var _snapshot: Dictionary = {}
var _source_session_id: StringName = &""
var _source_generation := -1
var _source_sequence := -1
var _retired_session_id: StringName = &""
var _retired_generation := -1
var _retired_sequence := -1
var _authority_peer_id := 0
var _authority_revision := -1
var _authority_records: Dictionary = {&"ownership": [], &"boarding": [], &"respawn": []}
var _ownership_view: Dictionary = {}
var _repair_presentations: Dictionary = {}
var _landing_authority_peer_id := 0
var _landing_revision := -1
var _landing_record: Dictionary = {}
var _landing_view: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var cursor := _session_cursor(source)
	if bool(cursor.get("fenced", false)):
		if not bool(cursor.get("valid", false)):
			return _retained_or_invalid(&"invalid_session_cursor")
	var state := StringName(str(source.get("state", &"disconnected")))
	if not STATES.has(state):
		return _retained_or_invalid(&"invalid_state") \
			if bool(cursor.get("fenced", false)) else _invalid_snapshot(&"invalid_state")
	if bool(cursor.get("fenced", false)) and not _accept_session_cursor(cursor):
		return _snapshot.duplicate(true)
	var role := StringName(str(source.get("role", &"client")))
	var detail := str(source.get("detail", "" )).strip_edges()
	var retryable := bool(source.get("retryable", state == &"failed"))
	var attempt := clampi(int(source.get("attempt", 0)), 0, 99)
	var seconds_remaining := clampf(float(source.get("seconds_remaining", 0.0)), 0.0, 300.0)
	var end_reason := _normalize_end_reason(source.get("end_reason", &""), state)
	var local_role := _normalize_local_role(source.get("local_role", source.get("player_role", &"observer")))
	var craft_name := str(source.get("controlled_craft", source.get("craft_name", ""))).strip_edges()
	var craft_id := StringName(str(source.get("controlled_craft_id", craft_name)).strip_edges())
	var local_peer_id := maxi(int(source.get("local_peer_id", source.get("peer_id", 0))), 0)
	var peer_generation := maxi(int(source.get("peer_generation", source.get("peer_gen", 0))), 0)
	var session_generation := maxi(int(source.get("session_generation", source.get("session_gen", source.get("generation", 0)))), 0)
	var history: Array[String] = []
	for item in source.get("history", source.get("lifecycle_history", [])) as Array:
		var receipt := str(item).strip_edges()
		if not receipt.is_empty():
			history.append(receipt.to_upper())
	if history.size() > 4:
		history = history.slice(history.size() - 4)
	if craft_name.length() > 48:
		craft_name = craft_name.left(48)
	var ownership_view := _present_authoritative_ownership(
		source.get("authoritative_snapshot", {}),
		local_peer_id,
		craft_id,
		local_role,
		state
	)
	var repair_view := _present_authoritative_repairs(local_peer_id, state)
	var landing_view := _present_authoritative_landing(
		source.get("authoritative_landing", {}),
		craft_id,
		state
	)
	var actions: Array = []
	match state:
		&"connecting": actions.append({"id": &"cancel", "label": "Cancel Connection", "focusable": true})
		&"reconnecting": actions.append({"id": &"cancel", "label": "Cancel Reconnect", "focusable": true})
		&"migrating": actions.append({"id": &"cancel", "label": "Cancel Migration", "focusable": true})
		&"connected": actions.append({"id": &"disconnect", "label": "Disconnect", "focusable": true})
		&"failed":
			if retryable:
				actions.append({"id": &"retry", "label": "Retry Connection", "focusable": true})
			actions.append({"id": &"cancel", "label": "Cancel", "focusable": true})
		&"rejected":
			if retryable:
				actions.append({"id": &"retry", "label": "Retry Connection", "focusable": true})
			actions.append({"id": &"cancel", "label": "Cancel", "focusable": true})
		&"disconnected":
			if retryable:
				actions.append({"id": &"retry", "label": "Retry Connection", "focusable": true})
	var title: String = {
		&"connecting": "Connecting",
		&"reconnecting": "Reconnecting",
		&"connected": "Connected",
		&"failed": "Connection Failed",
		&"rejected": "Connection Rejected",
		&"disconnected": "Disconnected",
		&"migrating": "Host Migration",
	}[state]
	var next_action := _next_action(
		state, retryable, attempt, seconds_remaining, local_role, ownership_view, landing_view
	)
	var message: String = detail if not detail.is_empty() else (
		SESSION_END_MESSAGES[end_reason] if not end_reason.is_empty() else _default_message(state)
	)
	# Preserve concise terminal-reason copy consumed by the existing end-reason
	# API; active/recoverable states add the next action directly to HUD text.
	if end_reason.is_empty():
		message += "\nNEXT ACTION // %s" % next_action
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": state,
		"role": role,
		"local_role": local_role,
		"ownership_text": String(local_role).to_upper(),
		"controlled_craft": craft_name,
		"authoritative_ownership": ownership_view,
		"ownership_rows": ownership_view.get("rows", []),
		"ownership_notices": ownership_view.get("notices", []),
		"craft_lifecycle_state": ownership_view.get("craft_lifecycle_state", &""),
		"craft_lifecycle_text": ownership_view.get("craft_lifecycle_text", ""),
		"craft_lifecycle_notice": ownership_view.get("craft_lifecycle_notice", ""),
		"repair_lifecycles": repair_view.get("lifecycles", []),
		"repair_rows": repair_view.get("rows", []),
		"landing_state": landing_view.get("state", &""),
		"landing_text": landing_view.get("text", ""),
		"landing_notice": landing_view.get("notice", ""),
		"landing_target_id": landing_view.get("target_id", &""),
		"landing_control_available": landing_view.get("control_available", true),
		"craft_control_available": (
			bool(ownership_view.get("craft_control_available", true))
			and bool(landing_view.get("control_available", true))
		),
		"title": title,
		"message": message,
		"next_action": next_action,
		"next_action_text": "NEXT ACTION // %s" % next_action,
		"peer_generation": peer_generation,
		"session_generation": session_generation,
		"generation_summary": "PEER %d  //  SESSION %d" % [peer_generation, session_generation],
		"history": history,
		"end_reason": end_reason,
		"retryable": retryable,
		"attempt": attempt if state == &"reconnecting" else 0,
		"seconds_remaining": seconds_remaining if state == &"reconnecting" else 0.0,
		"backoff_active": state == &"reconnecting",
		"actions": actions,
		"color_independent": true,
		"presentation_only": true,
	}
	if bool(cursor.get("fenced", false)):
		_snapshot["session_id"] = cursor.get("session_id", &"")
		_snapshot["source_generation"] = int(cursor.get("generation", -1))
		_snapshot["source_sequence"] = int(cursor.get("sequence", -1))
	if state == &"disconnected":
		_retire_session_cursor()
		_clear_active_session_cursor()
		_clear_authoritative_state()
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_snapshot.clear()
	_clear_active_session_cursor()
	_retired_session_id = &""
	_retired_generation = -1
	_retired_sequence = -1
	_clear_authoritative_state()
	return {
		"attached": false,
		"presentation_only": true,
		"network_authority": false,
	}.duplicate(true)


func request_cancel() -> Dictionary:
	return _intent(&"cancel", &"cancel_requested")


func request_retry() -> Dictionary:
	return _intent(&"retry", &"retry_requested")


func request_disconnect() -> Dictionary:
	return _intent(&"disconnect", &"disconnect_requested")


func _session_cursor(source: Dictionary) -> Dictionary:
	var fenced := source.has("session_id") or source.has("generation") \
		or source.has("sequence") or source.has("event_sequence")
	if not fenced:
		return {"fenced": false, "valid": true}
	var session_variant: Variant = source.get("session_id", &"legacy")
	var generation_variant: Variant = source.get("generation", null)
	var sequence_variant: Variant = source.get("sequence", source.get("event_sequence", null))
	if sequence_variant == null:
		var authoritative_variant: Variant = source.get("authoritative_snapshot", {})
		if authoritative_variant is Dictionary:
			var authoritative_sequence: Variant = (
				(authoritative_variant as Dictionary).get("event_sequence", null)
			)
			if authoritative_sequence is int and int(authoritative_sequence) >= 0:
				sequence_variant = authoritative_sequence
	if sequence_variant == null:
		sequence_variant = generation_variant
	var session_id := StringName(str(session_variant).strip_edges()) \
		if session_variant is String or session_variant is StringName else &""
	return {
		"fenced": true,
		"valid": not session_id.is_empty() \
			and generation_variant is int and int(generation_variant) >= 0 \
			and sequence_variant is int and int(sequence_variant) >= 0,
		"session_id": session_id,
		"generation": int(generation_variant) if generation_variant is int else -1,
		"sequence": int(sequence_variant) if sequence_variant is int else -1,
	}


func _accept_session_cursor(cursor: Dictionary) -> bool:
	var session_id := StringName(cursor.get("session_id", &""))
	var generation := int(cursor.get("generation", -1))
	var sequence := int(cursor.get("sequence", -1))
	if session_id == _retired_session_id and generation <= _retired_generation:
		return false
	if not _source_session_id.is_empty():
		if session_id != _source_session_id:
			return false
		if generation < _source_generation \
				or (generation == _source_generation and sequence <= _source_sequence):
			return false
		if generation > _source_generation:
			_clear_authoritative_state()
	elif session_id != _retired_session_id or generation > _retired_generation:
		# A fresh identity or generation reuses the presenter without carrying
		# ownership, repair, or landing rows from the prior session.
		_clear_authoritative_state()
	_source_session_id = session_id
	_source_generation = generation
	_source_sequence = sequence
	return true


func _retire_session_cursor() -> void:
	if _source_session_id.is_empty():
		return
	_retired_session_id = _source_session_id
	_retired_generation = _source_generation
	_retired_sequence = _source_sequence


func _clear_active_session_cursor() -> void:
	_source_session_id = &""
	_source_generation = -1
	_source_sequence = -1


func _clear_authoritative_state() -> void:
	_authority_peer_id = 0
	_authority_revision = -1
	_authority_records = {&"ownership": [], &"boarding": [], &"respawn": []}
	_ownership_view.clear()
	_repair_presentations.clear()
	_landing_authority_peer_id = 0
	_landing_revision = -1
	_landing_record.clear()
	_landing_view.clear()


func _retained_or_invalid(reason: StringName) -> Dictionary:
	return _snapshot.duplicate(true) if not _snapshot.is_empty() else _invalid_snapshot(reason)


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {"accepted": true, "reason": reason, "action": action, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "action": action, "presentation_only": true}


func _invalid_snapshot(reason: StringName) -> Dictionary:
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": &"failed",
		"role": &"unknown",
		"title": "Connection Status Unavailable",
		"message": "Connection status is unavailable.",
		"retryable": false,
		"actions": [{"id": &"cancel", "label": "Cancel", "focusable": true}],
		"error": reason,
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func _default_message(state: StringName) -> String:
	return {
		&"connecting": "Contacting the session host.",
		&"reconnecting": "Retrying the session connection.",
		&"connected": "Session is ready.",
		&"failed": "The session could not be established.",
		&"rejected": "The session request was rejected.",
		&"disconnected": "No active session.",
		&"migrating": "The session host is changing.",
	}[state]


func _next_action(
	state: StringName,
	retryable: bool,
	attempt: int,
	seconds_remaining: float,
	local_role: StringName,
	ownership_view: Dictionary,
	landing_view: Dictionary
) -> String:
	match state:
		&"connecting":
			return "WAIT FOR HOST ADMISSION OR CANCEL CONNECTION"
		&"reconnecting":
			if seconds_remaining > 0.0:
				return "WAIT %.1f S FOR RECONNECT ATTEMPT %d OR CANCEL RECONNECT" % [
					seconds_remaining, maxi(attempt, 1),
				]
			return "WAIT FOR RECONNECT ATTEMPT %d OR CANCEL RECONNECT" % maxi(attempt, 1)
		&"migrating":
			return "WAIT FOR NEW HOST OR CANCEL MIGRATION"
		&"connected":
			if not bool(landing_view.get("control_available", true)):
				return "WAIT FOR AUTHORITATIVE LANDING UPDATE OR DISCONNECT"
			if not bool(ownership_view.get("craft_control_available", true)):
				return "WAIT FOR AUTHORITATIVE CRAFT RECOVERY OR DISCONNECT"
			for notice_variant in ownership_view.get("notices", []) as Array:
				var notice := str(notice_variant)
				if notice.begins_with("CONTROL DENIED") or notice.begins_with("SEAT DENIED"):
					return "WAIT FOR HOST CRAFT ASSIGNMENT OR DISCONNECT"
			return {
				&"pilot": "CONTINUE AS PILOT OR DISCONNECT",
				&"passenger": "CONTINUE AS PASSENGER OR DISCONNECT",
				&"observer": "WAIT FOR HOST ASSIGNMENT OR DISCONNECT",
			}[local_role]
		&"failed", &"rejected":
			return "RETRY CONNECTION OR CANCEL" if retryable else "CANCEL AND REVIEW SESSION SETTINGS"
		&"disconnected":
			return "RETRY CONNECTION" if retryable else "RETURN TO SESSION MENU"
	return "REVIEW SESSION STATUS"


func _normalize_local_role(raw_role: Variant) -> StringName:
	var role := StringName(str(raw_role).strip_edges().to_lower())
	return role if LOCAL_ROLES.has(role) else &"observer"


func _normalize_end_reason(raw_reason: Variant, state: StringName) -> StringName:
	if state in [&"connecting", &"reconnecting", &"connected"]:
		return &""
	var reason := StringName(str(raw_reason).strip_edges().to_lower())
	return reason if SESSION_END_MESSAGES.has(reason) else (&"unknown" if not reason.is_empty() else &"")


func _present_authoritative_ownership(
	raw_snapshot: Variant,
	local_peer_id: int,
	craft_id: StringName,
	local_role: StringName,
	state: StringName
) -> Dictionary:
	if state == &"disconnected":
		_authority_peer_id = 0
		_authority_revision = -1
		_authority_records = {&"ownership": [], &"boarding": [], &"respawn": []}
		_ownership_view.clear()
		return {}
	if not raw_snapshot is Dictionary or (raw_snapshot as Dictionary).is_empty():
		if _authority_revision <= 0:
			return {}
		_ownership_view = _build_ownership_view(
			_authority_records.get(&"ownership", []) as Array,
			_authority_records.get(&"boarding", []) as Array,
			_authority_records.get(&"respawn", []) as Array,
			_authority_records,
			local_peer_id,
			craft_id,
			local_role,
			false
		)
		_ownership_view["revision"] = _authority_revision
		_ownership_view["authority_peer_id"] = _authority_peer_id
		_ownership_view["presentation_only"] = true
		return _ownership_view.duplicate(true)
	var authoritative := raw_snapshot as Dictionary
	var revision := int(authoritative.get("revision", 0))
	var authority_peer_id := int(authoritative.get("authority_peer_id", 0))
	var sections_variant: Variant = authoritative.get("sections", {})
	if revision <= 0 or authority_peer_id <= 0 or not sections_variant is Dictionary \
			or (_authority_peer_id > 0 and authority_peer_id != _authority_peer_id):
		return _ownership_view.duplicate(true)
	if revision < _authority_revision:
		return _ownership_view.duplicate(true)
	var sections := sections_variant as Dictionary
	var ownership_variant: Variant = sections.get(&"ownership", [])
	var boarding_variant: Variant = sections.get(&"boarding", [])
	var respawn_variant: Variant = sections.get(&"respawn", [])
	if not ownership_variant is Array or not boarding_variant is Array \
			or not respawn_variant is Array:
		return _ownership_view.duplicate(true)
	var ownership := _valid_ownership_records(ownership_variant as Array)
	var boarding := _valid_boarding_records(boarding_variant as Array)
	var respawn := _valid_respawn_records(respawn_variant as Array)
	if ownership.size() != (ownership_variant as Array).size() \
			or boarding.size() != (boarding_variant as Array).size() \
			or respawn.size() != (respawn_variant as Array).size():
		return _ownership_view.duplicate(true)
	var previous_records := _authority_records
	if revision > _authority_revision:
		_authority_peer_id = authority_peer_id
		_authority_revision = revision
		_authority_records = {
			&"ownership": ownership,
			&"boarding": boarding,
			&"respawn": respawn,
		}
	else:
		ownership = (_authority_records.get(&"ownership", []) as Array).duplicate(true)
		boarding = (_authority_records.get(&"boarding", []) as Array).duplicate(true)
		respawn = (_authority_records.get(&"respawn", []) as Array).duplicate(true)
	_ownership_view = _build_ownership_view(
		ownership,
		boarding,
		respawn,
		previous_records,
		local_peer_id,
		craft_id,
		local_role,
		revision > int(_ownership_view.get("revision", -1))
	)
	_ownership_view["revision"] = _authority_revision
	_ownership_view["authority_peer_id"] = authority_peer_id
	_ownership_view["presentation_only"] = true
	return _ownership_view.duplicate(true)


func _present_authoritative_landing(
	raw_snapshot: Variant,
	craft_id: StringName,
	state: StringName
) -> Dictionary:
	if state == &"disconnected":
		_landing_authority_peer_id = 0
		_landing_revision = -1
		_landing_record.clear()
		_landing_view.clear()
		return {}
	if not raw_snapshot is Dictionary or (raw_snapshot as Dictionary).is_empty():
		return _landing_view_for_craft(_landing_record, craft_id)
	var authoritative := raw_snapshot as Dictionary
	var authority_peer_id := int(authoritative.get("authority_peer_id", 0))
	var revision := int(authoritative.get("revision", 0))
	var landing_variant: Variant = authoritative.get("landing", {})
	if authority_peer_id <= 0 or revision <= 0 or not landing_variant is Dictionary \
			or (_landing_authority_peer_id > 0 and authority_peer_id != _landing_authority_peer_id) \
			or (_authority_peer_id > 0 and authority_peer_id != _authority_peer_id) \
			or revision <= _landing_revision:
		return _landing_view_for_craft(_landing_record, craft_id)
	var landing := landing_variant as Dictionary
	if str(landing.get("entity_id", "")).is_empty() \
			or int(landing.get("entity_generation", 0)) <= 0 \
			or not landing.get("state", &"") in [
				&"flying", &"landing_pending", &"landed",
				&"abort_pending_publication", &"retry_publication_pending",
			]:
		return _landing_view_for_craft(_landing_record, craft_id)
	_landing_authority_peer_id = authority_peer_id
	_landing_revision = revision
	_landing_record = landing.duplicate(true)
	_landing_view = _landing_view_for_craft(_landing_record, craft_id)
	_landing_view["revision"] = revision
	_landing_view["authority_peer_id"] = authority_peer_id
	_landing_view["presentation_only"] = true
	return _landing_view.duplicate(true)


## Reads only the repair projection already carried by canonical respawn rows.
## Each craft retains an independent nested generation/sequence cursor because
## a newer outer authority revision may still contain reordered craft data.
func _present_authoritative_repairs(local_peer_id: int, state: StringName) -> Dictionary:
	if state == &"disconnected":
		_repair_presentations.clear()
		return {}
	var current_entity_ids: Dictionary = {}
	for record_variant in _authority_records.get(&"respawn", []) as Array:
		var record := record_variant as Dictionary
		var entity_id := StringName(record.get("entity_id", &""))
		if entity_id.is_empty():
			continue
		current_entity_ids[entity_id] = true
		var retained := _repair_presentations.get(entity_id, {}) as Dictionary
		var repair_variant: Variant = record.get("repair", null)
		if repair_variant is Dictionary \
				and _valid_repair_record(record, repair_variant as Dictionary):
			var repair := repair_variant as Dictionary
			if retained.is_empty() or _repair_cursor_is_newer(record, repair, retained):
				_repair_presentations[entity_id] = _repair_presentation(record, repair)
		elif not retained.is_empty() and _repair_parent_is_newer(record, retained):
			# A respawn/component reset canonically retires the prior repair.
			_repair_presentations.erase(entity_id)
	for entity_variant in _repair_presentations.keys():
		if not current_entity_ids.has(StringName(entity_variant)):
			_repair_presentations.erase(entity_variant)
	var lifecycles: Array = []
	var entity_ids := _repair_presentations.keys()
	entity_ids.sort_custom(func(left: Variant, right: Variant) -> bool:
		return str(left) < str(right)
	)
	var rows: Array[String] = []
	for entity_variant in entity_ids.slice(0, mini(entity_ids.size(), MAX_REPAIR_PRESENTATIONS)):
		var lifecycle := (
			_repair_presentations[entity_variant] as Dictionary
		).duplicate(true)
		var owner_peer_id := int(lifecycle.get("owner_peer_id", 0))
		lifecycle["owner_text"] = _peer_scope(owner_peer_id, local_peer_id)
		lifecycle["presentation_only"] = true
		lifecycles.append(lifecycle)
		rows.append("%s // %s // %s // ENGINEER %s" % [
			str(lifecycle.get("craft_id", &"")).to_upper(),
			str(lifecycle.get("component_id", &"")).to_upper(),
			str(lifecycle.get("status_text", "")),
			str(lifecycle.get("owner_text", "UNASSIGNED")),
		])
	return {
		"lifecycles": lifecycles,
		"rows": rows,
		"presentation_only": true,
	}


func _valid_repair_record(parent: Dictionary, repair: Dictionary) -> bool:
	var state := StringName(repair.get("state", &""))
	var progress_variant: Variant = repair.get("progress", null)
	if state not in REPAIR_STATES \
			or int(repair.get("repair_generation", 0)) <= 0 \
			or int(repair.get("repair_sequence", 0)) <= 0 \
			or str(repair.get("component_id", "")).is_empty() \
			or int(repair.get("component_generation", 0)) \
				!= int(parent.get("component_generation", 0)) \
			or int(repair.get("owner_peer_id", 0)) <= 0 \
			or int(repair.get("owner_peer_generation", 0)) <= 0 \
			or not (progress_variant is int or progress_variant is float) \
			or not is_finite(float(progress_variant)):
		return false
	var progress := float(progress_variant)
	var terminal := state in [&"completed", &"aborted"]
	if progress < 0.0 or progress > 1.0 \
			or bool(repair.get("terminal", false)) != terminal:
		return false
	return not (state == &"started" and progress != 0.0) \
		and not (state == &"progress" and progress <= 0.0) \
		and not (state == &"completed" and progress != 1.0)


func _repair_cursor_is_newer(
	parent: Dictionary,
	repair: Dictionary,
	retained: Dictionary
) -> bool:
	var entity_generation := int(parent.get("entity_generation", 0))
	var retained_entity_generation := int(retained.get("entity_generation", 0))
	if entity_generation != retained_entity_generation:
		return entity_generation > retained_entity_generation
	var component_generation := int(parent.get("component_generation", 0))
	var retained_component_generation := int(retained.get("component_generation", 0))
	if component_generation != retained_component_generation:
		return component_generation > retained_component_generation
	var repair_generation := int(repair.get("repair_generation", 0))
	var retained_repair_generation := int(retained.get("repair_generation", 0))
	if repair_generation != retained_repair_generation:
		return repair_generation > retained_repair_generation
	return int(repair.get("repair_sequence", 0)) \
		> int(retained.get("repair_sequence", 0))


func _repair_parent_is_newer(parent: Dictionary, retained: Dictionary) -> bool:
	var entity_generation := int(parent.get("entity_generation", 0))
	var retained_entity_generation := int(retained.get("entity_generation", 0))
	if entity_generation != retained_entity_generation:
		return entity_generation > retained_entity_generation
	return int(parent.get("component_generation", 0)) \
		> int(retained.get("component_generation", 0))


func _repair_presentation(parent: Dictionary, repair: Dictionary) -> Dictionary:
	var state := StringName(repair.get("state", &""))
	var progress := float(repair.get("progress", 0.0))
	var state_text := {
		&"started": "STARTED",
		&"progress": "IN PROGRESS",
		&"completed": "COMPLETED",
		&"aborted": "ABORTED",
	}[state] as String
	return {
		"craft_id": StringName(parent.get("entity_id", &"")),
		"entity_generation": int(parent.get("entity_generation", 0)),
		"component_id": StringName(repair.get("component_id", &"")),
		"component_generation": int(repair.get("component_generation", 0)),
		"repair_generation": int(repair.get("repair_generation", 0)),
		"repair_sequence": int(repair.get("repair_sequence", 0)),
		"state": state,
		"progress": progress,
		"progress_percent": roundi(progress * 100.0),
		"status_text": "%s // %d%%" % [state_text, roundi(progress * 100.0)],
		"terminal": bool(repair.get("terminal", false)),
		"owner_peer_id": int(repair.get("owner_peer_id", 0)),
		"owner_peer_generation": int(repair.get("owner_peer_generation", 0)),
		"presentation_only": true,
	}


func _landing_view_for_craft(record: Dictionary, craft_id: StringName) -> Dictionary:
	if record.is_empty() or craft_id.is_empty() \
			or str(record.get("entity_id", "")).nocasecmp_to(str(craft_id)) != 0:
		return {}
	var state := StringName(record.get("state", &""))
	var target_id := StringName(record.get("target_id", &""))
	var target_text := str(target_id).to_upper()
	var text := ""
	var pending := false
	match state:
		&"flying": text = "FLYING"
		&"landing_pending":
			text = "APPROACH PENDING"
			pending = true
		&"landed":
			text = "LANDED"
			if bool(record.get("occupied", false)):
				text += " // %s OCCUPIED" % (
					"BERTH %s" % target_text if not target_text.is_empty() else "BERTH"
				)
		&"abort_pending_publication":
			text = "ABORT PUBLICATION PENDING"
			pending = true
		&"retry_publication_pending":
			text = "RETRY PUBLICATION PENDING"
			pending = true
		_:
			return {}
	if state == &"landing_pending" and not target_text.is_empty():
		text += " // BERTH %s" % target_text
	return {
		"state": state,
		"text": text,
		"notice": (
			"CONTROL UNAVAILABLE // LANDING TRANSITION PENDING" if pending else ""
		),
		"target_id": target_id,
		"control_available": not pending,
		"entity_generation": int(record.get("entity_generation", 0)),
		"presentation_only": true,
	}


func _build_ownership_view(
	ownership: Array,
	boarding: Array,
	respawn: Array,
	previous_records: Dictionary,
	local_peer_id: int,
	craft_id: StringName,
	local_role: StringName,
	show_transfers: bool
) -> Dictionary:
	var rows: Array[String] = []
	var notices: Array[String] = []
	var selected_ship := _select_ship(ownership, craft_id, local_peer_id)
	var selected_ship_id := StringName(selected_ship.get("ship_id", craft_id))
	if not selected_ship.is_empty():
		var owner_peer_id := int(selected_ship.get("owner_peer_id", 0))
		rows.append("CRAFT %s // %s" % [
			str(selected_ship_id).to_upper(),
			_peer_scope(owner_peer_id, local_peer_id),
		])
		if show_transfers:
			var prior_ship := _record_by_id(
				previous_records.get(&"ownership", []) as Array,
				&"ship_id",
				selected_ship_id
			)
			var prior_owner := int(prior_ship.get("owner_peer_id", owner_peer_id))
			if not prior_ship.is_empty() and prior_owner != owner_peer_id:
				notices.append("TRANSFER // %s // %s TO %s" % [
					str(selected_ship_id).to_upper(),
					_peer_scope(prior_owner, local_peer_id),
					_peer_scope(owner_peer_id, local_peer_id),
				])
		if local_role == &"pilot" and local_peer_id > 0 and owner_peer_id != local_peer_id:
			notices.append("CONTROL DENIED // %s %s" % [
				str(selected_ship_id).to_upper(),
				"IS UNASSIGNED" if owner_peer_id == 0 else "OWNED BY %s" % _peer_scope(owner_peer_id, local_peer_id),
			])
	var relevant_seats: Array = []
	for record_variant in boarding:
		var record := record_variant as Dictionary
		if not selected_ship_id.is_empty() \
				and str(record.get("vessel_id", "")).nocasecmp_to(str(selected_ship_id)) != 0:
			continue
		relevant_seats.append(record)
	relevant_seats.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	for record_variant in relevant_seats.slice(0, mini(relevant_seats.size(), 6)):
		var record := record_variant as Dictionary
		var seat_id := StringName(record.get("seat_id", &""))
		var occupant_peer_id := int(record.get("occupant_peer_id", 0))
		rows.append("%s %s // %s" % [
			str(record.get("role", &"seat")).to_upper(),
			str(seat_id).to_upper(),
			_peer_scope(occupant_peer_id, local_peer_id),
		])
		if local_role == &"pilot" and StringName(record.get("role", &"")) == &"pilot" \
				and local_peer_id > 0 and occupant_peer_id != local_peer_id:
			notices.append("SEAT DENIED // %s OCCUPIED BY %s" % [
				str(seat_id).to_upper(),
				_peer_scope(occupant_peer_id, local_peer_id),
			])
		if show_transfers:
			var prior_seat := _record_by_id(
				previous_records.get(&"boarding", []) as Array,
				&"seat_id",
				seat_id
			)
			var prior_occupant := int(prior_seat.get("occupant_peer_id", occupant_peer_id))
			if not prior_seat.is_empty() and prior_occupant != occupant_peer_id:
				notices.append("SEAT TRANSFER // %s // %s TO %s" % [
					str(seat_id).to_upper(),
					_peer_scope(prior_occupant, local_peer_id),
					_peer_scope(occupant_peer_id, local_peer_id),
				])
	var lifecycle := _craft_lifecycle_view(respawn, selected_ship_id)
	return {
		"rows": rows,
		"notices": notices,
		"craft_lifecycle_state": lifecycle.get("state", &""),
		"craft_lifecycle_text": lifecycle.get("text", ""),
		"craft_lifecycle_notice": lifecycle.get("notice", ""),
		"craft_control_available": lifecycle.get("control_available", true),
	}


func _valid_ownership_records(records: Array) -> Array:
	var valid: Array = []
	for record_variant in records:
		if not record_variant is Dictionary:
			continue
		var record := record_variant as Dictionary
		if str(record.get("ship_id", "")).is_empty() \
				or int(record.get("ship_generation", 0)) <= 0 \
				or int(record.get("owner_peer_id", -1)) < 0 \
				or int(record.get("ownership_generation", -1)) < 0:
			continue
		valid.append(record.duplicate(true))
	return valid


func _valid_boarding_records(records: Array) -> Array:
	var valid: Array = []
	for record_variant in records:
		if not record_variant is Dictionary:
			continue
		var record := record_variant as Dictionary
		if str(record.get("seat_id", "")).is_empty() \
				or str(record.get("vessel_id", "")).is_empty() \
				or str(record.get("role", "")).is_empty() \
				or int(record.get("seat_generation", 0)) <= 0 \
				or int(record.get("occupant_peer_id", 0)) <= 0:
			continue
		valid.append(record.duplicate(true))
	return valid


func _valid_respawn_records(records: Array) -> Array:
	var valid: Array = []
	for record_variant in records:
		if not record_variant is Dictionary:
			continue
		var record := record_variant as Dictionary
		if str(record.get("entity_id", "")).is_empty() \
				or str(record.get("state", "")).is_empty() \
				or int(record.get("entity_generation", 0)) <= 0 \
				or int(record.get("component_generation", 0)) <= 0:
			continue
		valid.append(record.duplicate(true))
	return valid


func _craft_lifecycle_view(records: Array, craft_id: StringName) -> Dictionary:
	if craft_id.is_empty():
		return {}
	var selected: Dictionary = {}
	for record_variant in records:
		var record := record_variant as Dictionary
		if str(record.get("entity_id", "")).nocasecmp_to(str(craft_id)) == 0:
			selected = record
			break
	if selected.is_empty():
		return {}
	var raw_state := StringName(str(selected.get("state", &"")).to_lower())
	var lifecycle_state: StringName
	match raw_state:
		&"healthy": lifecycle_state = &"healthy"
		&"damaged": lifecycle_state = &"damaged"
		&"destroyed", &"recovering": lifecycle_state = &"destroyed"
		&"respawning", &"respawn_pending": lifecycle_state = &"respawning"
		&"ready", &"recovery_ready": lifecycle_state = &"ready"
		&"active":
			var health := float(selected.get("health", 1.0))
			var maximum_health := float(selected.get("maximum_health", selected.get("max_health", health)))
			if bool(selected.get("destroyed", false)) or health <= 0.0:
				lifecycle_state = &"destroyed"
			elif maximum_health > 0.0 and health < maximum_health:
				lifecycle_state = &"damaged"
			else:
				lifecycle_state = &"healthy"
		_:
			return {}
	var destroyed := lifecycle_state == &"destroyed"
	return {
		"state": lifecycle_state,
		"text": String(lifecycle_state).to_upper(),
		"notice": (
			"CONTROL UNAVAILABLE // %s DESTROYED" % str(craft_id).to_upper()
			if destroyed else ""
		),
		"control_available": not destroyed,
		"entity_generation": int(selected.get("entity_generation", 0)),
		"component_generation": int(selected.get("component_generation", 0)),
		"presentation_only": true,
	}


func _select_ship(records: Array, craft_id: StringName, local_peer_id: int) -> Dictionary:
	if not craft_id.is_empty():
		for record_variant in records:
			var record := record_variant as Dictionary
			if str(record.get("ship_id", "")).nocasecmp_to(str(craft_id)) == 0:
				return record
		return {}
	if local_peer_id > 0:
		for record_variant in records:
			var record := record_variant as Dictionary
			if int(record.get("owner_peer_id", 0)) == local_peer_id:
				return record
	return {} if records.is_empty() else records[0] as Dictionary


func _record_by_id(records: Array, id_field: StringName, record_id: StringName) -> Dictionary:
	for record_variant in records:
		var record := record_variant as Dictionary
		if StringName(record.get(id_field, &"")) == record_id:
			return record
	return {}


func _peer_scope(peer_id: int, local_peer_id: int) -> String:
	if peer_id <= 0:
		return "UNASSIGNED"
	return "%s PEER %d" % ["LOCAL" if peer_id == local_peer_id else "REMOTE", peer_id]
