class_name NetworkSessionStatusPresenter
extends RefCounted

## Presentation-only network session state. The caller owns transport,
## admission, host/join authority, and all lifecycle transitions.

const COMPONENT_ID: StringName = &"network-session-status-presenter"
const STATES := [&"connecting", &"reconnecting", &"connected", &"failed", &"rejected", &"disconnected", &"migrating"]
const LOCAL_ROLES := [&"pilot", &"passenger", &"observer"]
const SESSION_END_MESSAGES := {
	&"timeout": "Session timed out.",
	&"rejected": "Session request was rejected.",
	&"protocol_mismatch": "Session protocol is incompatible.",
	&"host_migration": "Session host changed.",
	&"manual_leave": "You left the session.",
	&"unknown": "Session ended.",
}

var _snapshot: Dictionary = {}
var _source_generation := -1
var _authority_peer_id := 0
var _authority_revision := -1
var _authority_records: Dictionary = {&"ownership": [], &"boarding": []}
var _ownership_view: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	if source.has("generation"):
		if not source.generation is int or int(source.generation) < 0:
			return _invalid_snapshot(&"invalid_generation")
		if int(source.generation) < _source_generation:
			return _snapshot.duplicate(true)
		_source_generation = int(source.generation)
	var state := StringName(str(source.get("state", &"disconnected")))
	if not STATES.has(state):
		return _invalid_snapshot(&"invalid_state")
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
		"title": title,
		"message": detail if not detail.is_empty() else (SESSION_END_MESSAGES[end_reason] if not end_reason.is_empty() else _default_message(state)),
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
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func request_cancel() -> Dictionary:
	return _intent(&"cancel", &"cancel_requested")


func request_retry() -> Dictionary:
	return _intent(&"retry", &"retry_requested")


func request_disconnect() -> Dictionary:
	return _intent(&"disconnect", &"disconnect_requested")


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
		_authority_records = {&"ownership": [], &"boarding": []}
		_ownership_view.clear()
		return {}
	if not raw_snapshot is Dictionary or (raw_snapshot as Dictionary).is_empty():
		if _authority_revision <= 0:
			return {}
		_ownership_view = _build_ownership_view(
			_authority_records.get(&"ownership", []) as Array,
			_authority_records.get(&"boarding", []) as Array,
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
	if not ownership_variant is Array or not boarding_variant is Array:
		return _ownership_view.duplicate(true)
	var ownership := _valid_ownership_records(ownership_variant as Array)
	var boarding := _valid_boarding_records(boarding_variant as Array)
	if ownership.size() != (ownership_variant as Array).size() \
			or boarding.size() != (boarding_variant as Array).size():
		return _ownership_view.duplicate(true)
	var previous_records := _authority_records
	if revision > _authority_revision:
		_authority_peer_id = authority_peer_id
		_authority_revision = revision
		_authority_records = {&"ownership": ownership, &"boarding": boarding}
	else:
		ownership = (_authority_records.get(&"ownership", []) as Array).duplicate(true)
		boarding = (_authority_records.get(&"boarding", []) as Array).duplicate(true)
	_ownership_view = _build_ownership_view(
		ownership,
		boarding,
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


func _build_ownership_view(
	ownership: Array,
	boarding: Array,
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
	return {"rows": rows, "notices": notices}


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
