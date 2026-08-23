class_name NetworkSessionStatusPresenter
extends RefCounted

## Presentation-only network session state. The caller owns transport,
## admission, host/join authority, and all lifecycle transitions.

const COMPONENT_ID: StringName = &"network-session-status-presenter"
const STATES := [&"connecting", &"reconnecting", &"connected", &"failed", &"disconnected"]

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var state := StringName(str(source.get("state", &"disconnected")))
	if not STATES.has(state):
		return _invalid_snapshot(&"invalid_state")
	var role := StringName(str(source.get("role", &"client")))
	var detail := str(source.get("detail", "" )).strip_edges()
	var retryable := bool(source.get("retryable", state == &"failed"))
	var attempt := clampi(int(source.get("attempt", 0)), 0, 99)
	var seconds_remaining := clampf(float(source.get("seconds_remaining", 0.0)), 0.0, 300.0)
	var actions: Array = []
	match state:
		&"connecting": actions.append({"id": &"cancel", "label": "Cancel Connection", "focusable": true})
		&"reconnecting": actions.append({"id": &"cancel", "label": "Cancel Reconnect", "focusable": true})
		&"connected": actions.append({"id": &"disconnect", "label": "Disconnect", "focusable": true})
		&"failed":
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
		&"disconnected": "Disconnected",
	}[state]
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": state,
		"role": role,
		"title": title,
		"message": detail if not detail.is_empty() else _default_message(state),
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
		&"disconnected": "No active session.",
	}[state]
