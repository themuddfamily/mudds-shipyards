class_name LoadmasterTelemetryPresenter
extends RefCounted

## Read-only loadmaster receipt presentation; it never transfers inventory,
## grants rewards, or claims a helm.

const MAX_HISTORY := 4
var _snapshot: Dictionary = {}


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var role := str(snapshot.get("role", snapshot.get("crew_role", "UNKNOWN"))).strip_edges().to_upper()
	var craft_id := str(snapshot.get("craft_id", "")).strip_edges().to_upper()
	var occupant := str(snapshot.get("occupant", snapshot.get("occupant_name", "UNASSIGNED"))).strip_edges()
	var manifest := str(snapshot.get("manifest_state", snapshot.get("manifest_status", snapshot.get("manifest_id", "UNKNOWN")))).strip_edges().to_upper()
	var route := str(snapshot.get("route", snapshot.get("selected_route", snapshot.get("route_id", "NONE")))).strip_edges()
	var readiness := str(snapshot.get("readiness_receipt", snapshot.get("readiness", "NOT PUBLISHED"))).strip_edges()
	var seat_state := str(snapshot.get("state", "")).strip_edges().to_upper()
	var generation := int(snapshot.get("generation", snapshot.get("manifest_generation", 0)))
	var manifest_receipt := snapshot.get("manifest_receipt", {}) as Dictionary
	if not manifest_receipt.is_empty():
		manifest = "READY" if bool(manifest_receipt.get("ready", false)) else "BLOCKED"
		readiness = str(manifest_receipt.get("route_id", readiness)).strip_edges()
	if not seat_state.is_empty():
		manifest = "%s  //  SEAT %s" % [manifest, seat_state]
	var history: Array[String] = []
	for item in snapshot.get("history", snapshot.get("receipt_history", [])) as Array:
		if history.size() >= MAX_HISTORY:
			break
		var text := str(item).strip_edges()
		if not text.is_empty():
			history.append(text.to_upper())
	var message := "ROLE // %s  //  OCCUPANT // %s\nMANIFEST // %s\nROUTE // %s\nREADINESS // %s" % [role, occupant, manifest, route, readiness]
	if not craft_id.is_empty():
		message = "CRAFT // %s\n%s" % [craft_id, message]
	if generation > 0:
		message += "\nGENERATION // %d" % generation
	if not history.is_empty():
		message += "\nRECEIPT HISTORY // " + " | ".join(history)
	message += "\nNO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY"
	return {
		"schema_version": 1,
		"title": "LOADMASTER STATUS",
		"message": message,
		"role": role,
		"craft_id": craft_id,
		"occupant": occupant,
		"manifest_state": manifest,
		"route": route,
		"readiness_receipt": readiness,
		"seat_state": seat_state,
		"generation": generation,
		"history": history,
		"authority_text": "NO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY",
		"actions": [{"id": &"loadmaster_review", "label": "LOADMASTER REVIEW  //  READ ONLY", "focusable": true}],
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)


func present_cinder_snapshot(
		craft_id: StringName,
		role: StringName,
		status_snapshot: Dictionary,
		manifest_snapshot: Dictionary = {}
) -> Dictionary:
	var snapshot := status_snapshot.duplicate(true)
	snapshot["craft_id"] = craft_id
	snapshot["role"] = role
	snapshot["manifest_generation"] = int(manifest_snapshot.get("manifest_generation", snapshot.get("generation", 0)))
	snapshot["manifest_receipt"] = (manifest_snapshot.get("receipt", {}) as Dictionary).duplicate(true)
	return present_snapshot(snapshot)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_snapshot = {}
	return {"attached": false, "presentation_only": true, "authority": false}
