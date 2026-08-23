class_name SurfaceRouteHazardPresenter
extends RefCounted

## Presentation-only surface navigation state. World movement, hazard
## authority, weather simulation, and recovery execution remain external.

const COMPONENT_ID: StringName = &"surface-route-hazard-presenter"

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var waypoints: Array = source.get("waypoints", []) as Array
	var next := waypoints[0] as Dictionary if not waypoints.is_empty() and waypoints[0] is Dictionary else {}
	var hazard := source.get("hazard", {}) as Dictionary
	var exposure := clampf(float(hazard.get("exposure", 0.0)), 0.0, 1.0)
	var hazard_state := StringName(str(hazard.get("state", &"clear")))
	var recovery_ready := bool(hazard.get("recovery_available", false))
	var marker := _exposure_marker(exposure, hazard_state)
	var actions: Array = [{"id": &"resume", "label": "Resume Route", "focusable": true}, {"id": &"abort", "label": "Abort Route", "focusable": true}]
	if recovery_ready:
		actions.append({"id": &"request_recovery", "label": "Request Recovery", "focusable": true})
	_snapshot = {
		"component_id": COMPONENT_ID,
		"next_landmark": str(next.get("label", "No waypoint queued")),
		"waypoint_id": StringName(str(next.get("id", &""))),
		"distance_m": maxf(0.0, float(next.get("distance_m", 0.0))),
		"weather": str(source.get("weather", "Unknown conditions")),
		"hazard_state": hazard_state,
		"exposure": exposure,
		"exposure_marker": marker,
		"recovery_available": recovery_ready,
		"actions": actions,
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func request_resume() -> Dictionary:
	return _intent(&"resume", &"resume_requested")


func request_abort() -> Dictionary:
	return _intent(&"abort", &"abort_requested")


func request_recovery() -> Dictionary:
	return _intent(&"request_recovery", &"recovery_requested")


func _intent(action: StringName, reason: StringName) -> Dictionary:
	for candidate in _snapshot.get("actions", []) as Array:
		if StringName(candidate.get("id", &"")) == action:
			return {"accepted": true, "reason": reason, "action": action, "presentation_only": true}
	return {"accepted": false, "reason": &"action_unavailable", "action": action, "presentation_only": true}


func _exposure_marker(exposure: float, hazard_state: StringName) -> StringName:
	if hazard_state in [&"storm", &"blocked"] or exposure >= 0.8:
		return &"!! HIGH EXPOSURE !!"
	if hazard_state in [&"watch", &"warming"] or exposure >= 0.4:
		return &"! EXPOSURE RISING !"
	return &"[ SAFE WINDOW ]"
