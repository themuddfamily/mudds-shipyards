class_name SafeStartRecoveryPresenter
extends RefCounted

## Presentation-only consumer for a caller-owned SafeStart recovery receipt.
## It does not inspect settings, perform restoration, or own crash diagnostics.

const COMPONENT_ID: StringName = &"safe-start-recovery-presenter"

var _snapshot: Dictionary = {}


func present_receipt(receipt: Dictionary) -> Dictionary:
	if not _valid_receipt(receipt):
		_snapshot = {
			"component_id": COMPONENT_ID,
			"status": &"invalid",
			"title": "Recovery information unavailable",
			"message": "Keep Safe Settings is the only available option.",
			"actions": [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}],
			"presentation_only": true,
		}
		return _snapshot.duplicate(true)
	var graphics := receipt.get("graphics_recovery_receipt", {}) as Dictionary
	var audio := receipt.get("audio_recovery_receipt", {}) as Dictionary
	var restore_available := not graphics.is_empty() or not audio.is_empty()
	var actions: Array = [{"id": &"keep_safe", "label": "Keep Safe Settings", "focusable": true}]
	if restore_available:
		actions.push_front({"id": &"restore", "label": "Restore Previous Settings", "focusable": true})
	_snapshot = {
		"component_id": COMPONENT_ID,
		"status": &"safe_mode_active" if restore_available else &"safe_mode_confirmed",
		"title": "Safe Settings Active",
		"message": "The previous session did not start cleanly. Safe display/audio settings are active.",
		"details": {
			"graphics_restore_available": not graphics.is_empty(),
			"audio_restore_available": not audio.is_empty(),
			"stability_confirmed": bool(receipt.get("stability_confirmed", false)),
		},
		"actions": actions,
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func present_recovery_choice(recommendation: Dictionary) -> Dictionary:
	if not bool(recommendation.get("available", false)) or not bool(recommendation.get("requires_caller_choice", false)):
		_snapshot = {"component_id": COMPONENT_ID, "status": &"hidden", "actions": [], "presentation_only": true}
		return _snapshot.duplicate(true)
	var severity := StringName(str(recommendation.get("severity", &"review_prior_session")))
	_snapshot = {
		"component_id": COMPONENT_ID,
		"status": &"choice_required",
		"title": "Previous session recovery",
		"message": "The last session did not close cleanly. Choose how to start this session.",
		"summary": "Recovery record available  //  %s" % str(severity).replace("_", " ").to_upper(),
		"actions": [
			{"id": &"normal_start", "label": "Normal Start", "focusable": true},
			{"id": &"safe_graphics_windowed", "label": "Safe Graphics (Session Only)", "focusable": true},
			{"id": &"discard", "label": "Discard Recovery Record", "focusable": true},
		],
		"presentation_only": true,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func request_choice(choice: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == choice:
			return {"accepted": true, "reason": &"recovery_choice_requested", "choice": choice, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "choice": choice, "presentation_only": true}


func request_restore() -> Dictionary:
	return _intent(&"restore", &"restore_requested")


func request_keep_safe() -> Dictionary:
	return _intent(&"keep_safe", &"keep_safe_requested")


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {"accepted": true, "reason": reason, "action": action, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "action": action, "presentation_only": true}


func _valid_receipt(receipt: Dictionary) -> bool:
	return receipt.has("graphics_recovery_receipt") and receipt.has("audio_recovery_receipt")
