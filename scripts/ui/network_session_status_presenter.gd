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
