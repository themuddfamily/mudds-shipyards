class_name AtmosphericEntryGuidancePresenter
extends RefCounted

## Presentation-only atmospheric entry and airless descent guidance. Flight,
## landing, support, recovery, and accessibility authority remain external.

const COMPONENT_ID: StringName = &"atmospheric-entry-guidance-presenter"

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var altitude := maxf(0.0, float(source.get("altitude_m", 0.0)))
	var branch_id := StringName(source.get("branch_id", &"atmospheric"))
	var has_atmosphere := branch_id == &"atmospheric"
	var intensity := clampf(float(source.get("entry_intensity", 0.0)), 0.0, 1.0) \
		if has_atmosphere else 0.0
	var landing_supported := bool(source.get("landing_supported", false))
	var reduced_flash := bool(source.get("reduced_flash", false))
	var reduced_motion := bool(source.get("reduced_motion", false))
	var recovery := source.get("recovery_receipt", {}) as Dictionary
	var state: StringName
	if not has_atmosphere:
		state = &"airless_descent"
	elif intensity >= 0.85:
		state = &"critical_entry"
	elif intensity >= 0.45:
		state = &"entry_watch"
	elif landing_supported:
		state = &"landing_supported"
	else:
		state = &"support_required"
	var actions: Array = [{"id": &"abort_landing", "label": "Abort Landing", "focusable": true}]
	if not landing_supported or (has_atmosphere and intensity >= 0.45):
		actions.push_front({"id": &"request_support", "label": "Request Landing Support", "focusable": true})
	var marker := _intensity_marker(state, reduced_flash)
	_snapshot = {
		"component_id": COMPONENT_ID,
		"state": state,
		"title": _title(state),
		"guidance": "%s\n%s" % [marker, _guidance(state)],
		"altitude_m": altitude,
		"branch_id": branch_id,
		"has_atmosphere": has_atmosphere,
		"entry_intensity": intensity,
		"intensity_marker": marker,
		"reduced_flash": reduced_flash,
		"reduced_motion": reduced_motion,
		"attention_cue_policy": &"steady_text_no_flash" \
			if reduced_flash else &"text_severity",
		"transition_policy": &"static" if reduced_motion else &"standard",
		"landing_supported": landing_supported,
		"recovery_receipt_id": StringName(str(recovery.get("receipt_id", &""))),
		"recovery_available": not recovery.is_empty(),
		"actions": actions,
		"presentation_only": true,
		"physics_authority": false,
		"damage_authority": false,
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


func _intensity_marker(state: StringName, reduced_flash: bool) -> StringName:
	if state == &"airless_descent":
		return &"[ AIRLESS // ENTRY HEAT ZERO ]"
	if state == &"critical_entry":
		if reduced_flash:
			return &"[ STEADY ENTRY LOAD CRITICAL ]"
		return &"!! ENTRY LOAD CRITICAL !!"
	if state == &"entry_watch":
		if reduced_flash:
			return &"[ STEADY ENTRY LOAD RISING ]"
		return &"! ENTRY LOAD RISING !"
	return &"[ ENTRY NOMINAL ]"


func _title(state: StringName) -> String:
	return {
		&"airless_descent": "Ember Airless Descent",
		&"critical_entry": "Critical Atmospheric Entry",
		&"entry_watch": "Atmospheric Entry Watch",
		&"landing_supported": "Landing Support Ready",
		&"support_required": "Landing Support Required",
	}[state]


func _guidance(state: StringName) -> String:
	return {
		&"airless_descent": "No atmosphere or aerodynamic braking is available; follow powered-descent guidance.",
		&"critical_entry": "Reduce entry load or abort the landing approach.",
		&"entry_watch": "Entry load is rising. Request support if the approach is unstable.",
		&"landing_supported": "Landing corridor and recovery support are available.",
		&"support_required": "No landing support is confirmed for this approach.",
	}[state]
