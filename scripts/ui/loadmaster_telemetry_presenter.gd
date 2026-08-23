class_name LoadmasterTelemetryPresenter
extends RefCounted

## Read-only loadmaster receipt presentation; it never transfers inventory,
## grants rewards, or claims a helm.

const MAX_HISTORY := 4
var _snapshot: Dictionary = {}


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var role := str(snapshot.get("role", snapshot.get("crew_role", "UNKNOWN"))).strip_edges().to_upper()
	var occupant := str(snapshot.get("occupant", snapshot.get("occupant_name", "UNASSIGNED"))).strip_edges()
	var manifest := str(snapshot.get("manifest_state", snapshot.get("manifest_status", "UNKNOWN"))).strip_edges().to_upper()
	var route := str(snapshot.get("route", snapshot.get("selected_route", "NONE"))).strip_edges()
	var readiness := str(snapshot.get("readiness_receipt", snapshot.get("readiness", "NOT PUBLISHED"))).strip_edges()
	var history: Array[String] = []
	for item in snapshot.get("history", snapshot.get("receipt_history", [])) as Array:
		if history.size() >= MAX_HISTORY:
			break
		var text := str(item).strip_edges()
		if not text.is_empty():
			history.append(text.to_upper())
	var message := "ROLE // %s  //  OCCUPANT // %s\nMANIFEST // %s\nROUTE // %s\nREADINESS // %s" % [role, occupant, manifest, route, readiness]
	if not history.is_empty():
		message += "\nRECEIPT HISTORY // " + " | ".join(history)
	message += "\nNO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY"
	return {
		"schema_version": 1,
		"title": "LOADMASTER STATUS",
		"message": message,
		"role": role,
		"occupant": occupant,
		"manifest_state": manifest,
		"route": route,
		"readiness_receipt": readiness,
		"history": history,
		"authority_text": "NO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY",
		"actions": [{"id": &"loadmaster_review", "label": "LOADMASTER REVIEW  //  READ ONLY", "focusable": true}],
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_snapshot = {}
	return {"attached": false, "presentation_only": true, "authority": false}
