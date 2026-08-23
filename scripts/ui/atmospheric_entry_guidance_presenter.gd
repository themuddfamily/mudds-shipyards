class_name AtmosphericEntryGuidancePresenter
extends RefCounted

## Presentation-only atmospheric entry guidance. Flight, landing, support, and
## recovery authorities remain with the caller.

const COMPONENT_ID: StringName = &"atmospheric-entry-guidance-presenter"

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var altitude := maxf(0.0, float(source.get("altitude_m", 0.0)))
	var intensity := clampf(float(source.get("entry_intensity", 0.0)), 0.0, 1.0)
	var landing_supported := bool(source.get("landing_supported", false))
	var recovery := source.get("recovery_receipt", {}) as Dictionary
	var state: StringName
	if intensity >= 0.85:
		state = &"critical_entry"
	elif intensity >= 0.45:
		state = &"entry_watch"
	elif landing_supported:
		state = &"landing_supported"
	else:
		state = &"support_required"
	var actions: Array = [{"id": &"abort_landing", "label": "Abort Landing", "focusable": true}]
	if not landing_supported or intensity >= 0.45:
		actions.push_front({"id": &"request_support", "label": "Request Landing Support", "focusable": true})
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": state,
		"title": _title(state),
		"guidance": _guidance(state),
		"altitude_m": altitude,
		"entry_intensity": intensity,
		"intensity_marker": _intensity_marker(intensity),
		"landing_supported": landing_supported,
		"recovery_receipt_id": StringName(str(recovery.get("receipt_id", &""))),
		"recovery_available": not recovery.is_empty(),
		"actions": actions,
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func request_support() -> Dictionary:
	return _intent(&"request_support", &"support_requested")


func abort_landing() -> Dictionary:
	return _intent(&"abort_landing", &"abort_requested")


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {"accepted": true, "reason": reason, "action": action, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "action": action, "presentation_only": true}


func _intensity_marker(intensity: float) -> StringName:
	if intensity >= 0.85:
		return &"!! ENTRY LOAD CRITICAL !!"
	if intensity >= 0.45:
		return &"! ENTRY LOAD RISING !"
	return &"[ ENTRY NOMINAL ]"


func _title(state: StringName) -> String:
	return {
		&"critical_entry": "Critical Atmospheric Entry",
		&"entry_watch": "Atmospheric Entry Watch",
		&"landing_supported": "Landing Support Ready",
		&"support_required": "Landing Support Required",
	}[state]


func _guidance(state: StringName) -> String:
	return {
		&"critical_entry": "Reduce entry load or abort the landing approach.",
		&"entry_watch": "Entry load is rising. Request support if the approach is unstable.",
		&"landing_supported": "Landing corridor and recovery support are available.",
		&"support_required": "No landing support is confirmed for this approach.",
	}[state]
