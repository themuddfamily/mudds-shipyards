class_name LoadmasterTelemetryPresenter
extends RefCounted

## Read-only loadmaster receipt presentation; it never transfers inventory,
## grants rewards, or claims a helm.

const MAX_HISTORY := 4
var _snapshot: Dictionary = {}
var _presentation: Dictionary = {}
var _accepted_craft_id: StringName = &""
var _accepted_generation := -1
var _accepted_revision := -1


func present_snapshot(snapshot: Dictionary) -> Dictionary:
	var craft_id := StringName(str(snapshot.get("craft_id", "")).strip_edges().to_lower())
	if not _accepted_craft_id.is_empty() and not craft_id.is_empty() \
			and craft_id != _accepted_craft_id:
		_clear_state()
	var cursor := _receipt_cursor(snapshot)
	if bool(cursor.get("fenced", false)) and not _accept_cursor(cursor, craft_id):
		return _presentation.duplicate(true)
	return _present_accepted_snapshot(snapshot, cursor)


func _present_accepted_snapshot(snapshot: Dictionary, cursor: Dictionary = {}) -> Dictionary:
	_snapshot = snapshot.duplicate(true)
	var role := str(snapshot.get("role", snapshot.get("crew_role", "UNKNOWN"))).strip_edges().to_upper()
	var craft_id := str(snapshot.get("craft_id", "")).strip_edges().to_upper()
	var occupant := str(snapshot.get("occupant", snapshot.get("occupant_name", "UNASSIGNED"))).strip_edges()
	var manifest := str(snapshot.get("manifest_state", snapshot.get("manifest_status", snapshot.get("manifest_id", "UNKNOWN")))).strip_edges().to_upper()
	var route := str(snapshot.get("route", snapshot.get("selected_route", snapshot.get("route_id", "NONE")))).strip_edges()
	var readiness := str(snapshot.get("readiness_receipt", snapshot.get("readiness", "NOT PUBLISHED"))).strip_edges()
	var seat_state := str(snapshot.get("state", "")).strip_edges().to_upper()
	var roster_shape := str(snapshot.get("roster_shape", "")).strip_edges()
	var roster_status := str(snapshot.get("roster_status", "")).strip_edges().to_upper()
	var cinder_roster := snapshot.has("roster_shape") \
		or str(snapshot.get("craft_id", "")).strip_edges().to_lower() == "cinder_cargo_hauler"
	var generation := int(snapshot.get("generation", snapshot.get("manifest_generation", 0)))
	# Halyard publishes its manifest API directly as `{manifest_generation,
	# receipt}`; Cinder's two-snapshot HUD seam normalizes to the same view.
	var manifest_receipt := snapshot.get("manifest_receipt", snapshot.get("receipt", {})) as Dictionary
	var revision := int(cursor.get("revision", snapshot.get("revision", 0)))
	var readiness_state := "[STATUS PUBLISHED]"
	var next_action := "REVIEW PUBLISHED MANIFEST STATUS"
	if not manifest_receipt.is_empty():
		var receipt_ready := bool(manifest_receipt.get("ready", false))
		manifest = "READY" if receipt_ready else "BLOCKED"
		var receipt_route := str(manifest_receipt.get("route_id", route)).strip_edges()
		route = receipt_route if not receipt_route.is_empty() else "NONE"
		readiness_state = "[READY]" if receipt_ready else "[ACTION REQUIRED]"
		readiness = "%s // ROUTE %s" % [readiness_state, receipt_route if not receipt_route.is_empty() else "NOT PUBLISHED"]
		next_action = (
			"CREW REVIEW // CONFIRM ROUTE %s" % (receipt_route if not receipt_route.is_empty() else "NOT PUBLISHED")
			if receipt_ready
			else "RESOLVE MANIFEST BLOCKERS // ROUTE %s" % (receipt_route if not receipt_route.is_empty() else "NOT PUBLISHED")
		)
	elif seat_state == "RELEASED":
		readiness_state = "[STATION RELEASED]"
		next_action = "CLAIM LOADMASTER STATION TO REVIEW"
	elif seat_state == "AVAILABLE":
		readiness_state = "[STATION AVAILABLE]"
		next_action = "CLAIM LOADMASTER STATION"
	elif seat_state == "OCCUPIED":
		readiness_state = "[MANIFEST PENDING]"
		next_action = "PUBLISH MANIFEST READINESS"
	elif manifest.begins_with("BLOCKED"):
		readiness_state = "[ACTION REQUIRED]"
		next_action = "REVIEW PUBLISHED READINESS BLOCKER"
	elif manifest.begins_with("READY"):
		readiness_state = "[READY]"
		next_action = "CREW REVIEW // CONFIRM PUBLISHED ROUTE"
	if cinder_roster and (roster_shape.is_empty() or roster_status.is_empty()):
		var roster_reading := _roster_reading(seat_state, manifest_receipt)
		roster_shape = str(roster_reading["shape"])
		roster_status = str(roster_reading["status"])
	if not seat_state.is_empty():
		manifest = "%s  //  SEAT %s" % [manifest, seat_state]
	var history: Array[String] = []
	for item in snapshot.get("history", snapshot.get("receipt_history", [])) as Array:
		if history.size() >= MAX_HISTORY:
			break
		var text := str(item).strip_edges()
		if not text.is_empty():
			history.append(text.to_upper())
	var message := "ROLE // %s  //  OCCUPANT // %s\n" % [role, occupant]
	if cinder_roster:
		message += "ROSTER STATE // %s %s\n" % [roster_shape, roster_status]
	message += "MANIFEST // %s\nROUTE // %s\nREADINESS // %s\nREADINESS STATE // %s\nNEXT ACTION // %s" % [manifest, route, readiness, readiness_state, next_action]
	if not craft_id.is_empty():
		message = "CRAFT // %s\n%s" % [craft_id, message]
	if generation > 0:
		message += "\nGENERATION // %d" % generation
	if revision > 0:
		message += "  //  REVISION // %d" % revision
	if not history.is_empty():
		message += "\nRECEIPT HISTORY // " + " | ".join(history)
	message += "\nNO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY"
	_presentation = {
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
		"roster_shape": roster_shape,
		"roster_status": roster_status,
		"generation": generation,
		"revision": revision,
		"readiness_state": readiness_state,
		"next_action": next_action,
		"history": history,
		"authority_text": "NO INVENTORY TRANSFER  //  NO REWARD AUTHORITY  //  NO HELM AUTHORITY",
		"actions": [{"id": &"loadmaster_review", "label": "LOADMASTER REVIEW  //  READ ONLY", "focusable": true}],
		"presentation_only": true,
		"authority": false,
	}.duplicate(true)
	return _presentation.duplicate(true)


func present_cinder_snapshot(
		craft_id: StringName,
		role: StringName,
		status_snapshot: Dictionary,
		manifest_snapshot: Dictionary = {}
) -> Dictionary:
	var normalized_craft_id := StringName(str(craft_id).strip_edges().to_lower())
	if not _accepted_craft_id.is_empty() and normalized_craft_id != _accepted_craft_id:
		_clear_state()
	var snapshot := status_snapshot.duplicate(true)
	snapshot["craft_id"] = craft_id
	snapshot["role"] = role
	var status_generation := int(status_snapshot.get("generation", -1))
	var manifest_generation := int(manifest_snapshot.get("manifest_generation", status_generation))
	snapshot["manifest_generation"] = manifest_generation
	snapshot["manifest_receipt"] = (manifest_snapshot.get("receipt", {}) as Dictionary).duplicate(true)
	var cursor := _receipt_cursor(snapshot)
	if status_generation <= 0 or manifest_generation != status_generation:
		return _presentation.duplicate(true)
	if not _accept_cursor(cursor, normalized_craft_id):
		return _presentation.duplicate(true)
	return _present_accepted_snapshot(snapshot, cursor)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func detach() -> Dictionary:
	_clear_state()
	return {"attached": false, "presentation_only": true, "authority": false}


func _receipt_cursor(snapshot: Dictionary) -> Dictionary:
	var status_generation := int(snapshot.get("generation", snapshot.get("manifest_generation", -1)))
	var manifest_generation := int(snapshot.get("manifest_generation", status_generation))
	var receipt := snapshot.get("manifest_receipt", snapshot.get("receipt", {})) as Dictionary
	var revision := int(snapshot.get("revision", snapshot.get("request_sequence", 0)))
	if not receipt.is_empty():
		var receipt_generation := int(receipt.get("manifest_generation", -1))
		revision = int(receipt.get("request_sequence", -1))
		return {
			"fenced": true,
			"valid": status_generation > 0 \
					and manifest_generation == status_generation \
					and receipt_generation == status_generation \
					and revision > 0,
			"generation": status_generation,
			"revision": revision,
		}
	return {
		"fenced": status_generation > 0 or manifest_generation > 0,
		"valid": status_generation > 0 \
				and manifest_generation == status_generation \
				and revision >= 0,
		"generation": status_generation,
		"revision": revision,
	}


func _accept_cursor(cursor: Dictionary, craft_id: StringName = &"") -> bool:
	if not bool(cursor.get("valid", false)):
		return false
	var generation := int(cursor.get("generation", -1))
	var revision := int(cursor.get("revision", -1))
	if generation < _accepted_generation \
			or (generation == _accepted_generation and revision <= _accepted_revision):
		return false
	_accepted_generation = generation
	_accepted_revision = revision
	if not craft_id.is_empty():
		_accepted_craft_id = craft_id
	return true


func _clear_state() -> void:
	_snapshot = {}
	_presentation = {}
	_accepted_craft_id = &""
	_accepted_generation = -1
	_accepted_revision = -1


func _roster_reading(seat_state: String, receipt: Dictionary) -> Dictionary:
	if not receipt.is_empty():
		return {"shape": "[=]", "status": "SECURED // MANIFEST READY"} \
			if bool(receipt.get("ready", false)) \
			else {"shape": "[!]", "status": "BLOCKED // MANIFEST REVIEW"}
	match seat_state:
		"OCCUPIED":
			return {"shape": "[>]", "status": "LOADING // MANIFEST PENDING"}
		"AVAILABLE", "RELEASED", "":
			return {"shape": "[/]", "status": "DETACHED // STATION OPEN"}
		_:
			return {"shape": "[X]", "status": "FAULT // STATUS UNAVAILABLE"}
