class_name CrewRoleSeatPresenter
extends RefCounted

## Detached, controller-readable crew-role/seat presentation. Occupancy and
## transfer authority remain with the caller; this object only formats state and
## returns typed intent descriptors.

const COMPONENT_ID: StringName = &"crew-role-seat-presenter"
const ROLE_ORDER := [&"pilot", &"gunner", &"engineer", &"passenger"]

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var raw_roles := source.get("roles", {}) as Dictionary
	var rows: Array = []
	for role in ROLE_ORDER:
		var record := raw_roles.get(role, {}) as Dictionary
		var occupant := str(record.get("occupant", "")).strip_edges()
		rows.append({
			"role": role,
			"label": String(role).capitalize(),
			"seat_id": StringName(str(record.get("seat_id", role))),
			"occupant": occupant,
			"occupied": not occupant.is_empty(),
			"available": bool(record.get("available", occupant.is_empty())),
			"status": occupant if not occupant.is_empty() else ("Available" if bool(record.get("available", true)) else "Unavailable"),
			"focusable": true,
		})
	_snapshot = {
		"component_id": COMPONENT_ID,
		"actor_id": str(source.get("actor_id", "")),
		"rows": rows,
		"title": "Crew Roles and Seats",
		"actions": [
			{"id": &"claim", "label": "Claim available seat", "focusable": true},
			{"id": &"release", "label": "Release your seat", "focusable": true},
			{"id": &"transfer", "label": "Transfer role", "focusable": true},
		],
		"presentation_only": true,
	}
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func request_claim(role: StringName) -> Dictionary:
	return _role_intent(&"claim", role, &"claim_requested")


func request_release(role: StringName) -> Dictionary:
	return _role_intent(&"release", role, &"release_requested")


func request_transfer(from_role: StringName, to_role: StringName) -> Dictionary:
	if not _known_role(from_role) or not _known_role(to_role) or from_role == to_role:
		return {"accepted": false, "reason": &"invalid_transfer", "presentation_only": true}
	return {
		"accepted": true,
		"reason": &"transfer_requested",
		"from_role": from_role,
		"to_role": to_role,
		"presentation_only": true,
	}


func _role_intent(action: StringName, role: StringName, reason: StringName) -> Dictionary:
	if not _known_role(role):
		return {"accepted": false, "reason": &"unknown_role", "role": role, "presentation_only": true}
	return {"accepted": true, "reason": reason, "action": action, "role": role, "presentation_only": true}


func _known_role(role: StringName) -> bool:
	return ROLE_ORDER.has(role)
