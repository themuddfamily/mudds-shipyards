class_name CopilotNavigationSupportPresenter
extends RefCounted

## Presentation-only view of caller-published copilot navigation support.
## This surface never selects routes, controls a helm, moves cargo, or claims a berth.

const COMPONENT_ID: StringName = &"copilot-navigation-support"

var _snapshot: Dictionary = {}


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var role := str(snapshot.get("role", snapshot.get("occupant_role", "UNKNOWN"))).strip_edges().to_upper()
	var occupant := str(snapshot.get("occupant", snapshot.get("occupant_name", "UNASSIGNED"))).strip_edges()
	var target := str(snapshot.get("selected_target", snapshot.get("target", "NONE"))).strip_edges()
	var route := str(snapshot.get("selected_route", snapshot.get("route", "NONE"))).strip_edges()
	var request_state := str(snapshot.get("request_state", snapshot.get("navigation_request_state", "UNAVAILABLE"))).strip_edges().to_upper()
	var reason := str(snapshot.get("reason", snapshot.get("request_reason", ""))).strip_edges()
	var cargo := str(snapshot.get("cargo_summary", "NO CARGO DATA PUBLISHED")).strip_edges()
	var berth := str(snapshot.get("berth_summary", "NO BERTH DATA PUBLISHED")).strip_edges()
	var request_text := request_state
	if not reason.is_empty():
		request_text += " // " + reason.to_upper()
	return {
		"schema_version": 1,
		"component_id": COMPONENT_ID,
		"title": "COPILOT NAVIGATION SUPPORT",
		"message": "ROLE // %s  //  OCCUPANT // %s\nTARGET // %s\nROUTE // %s\nREQUEST // %s\nCARGO // %s\nBERTH // %s\nNO HELM AUTHORITY  //  NO CARGO AUTHORITY" % [role, occupant, target, route, request_text, cargo, berth],
		"role": role,
		"occupant": occupant,
		"selected_target": target,
		"selected_route": route,
		"request_state": request_text,
		"cargo_summary": cargo,
		"berth_summary": berth,
		"authority_text": "NO HELM AUTHORITY  //  NO CARGO AUTHORITY",
		"actions": [{"id": &"copilot_review", "label": "COPILOT SUPPORT  //  READ ONLY", "focusable": true}],
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_snapshot = {}
	return {"attached": false, "presentation_only": true, "authority": false}
