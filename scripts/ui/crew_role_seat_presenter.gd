class_name CrewRoleSeatPresenter
extends RefCounted

## Detached, controller-readable crew-role/seat presentation. Occupancy and
## transfer authority remain with the caller; this object only formats state and
## returns typed intent descriptors.

const COMPONENT_ID: StringName = &"crew-role-seat-presenter"
const ROLE_ORDER := [&"pilot", &"gunner", &"engineer", &"passenger"]
const POWER_ROUTES := [&"offline", &"auxiliary", &"primary"]
const MOBILITY_STATES := [&"immobile", &"limited", &"mobile"]
const FIRE_STATES := [&"blocked", &"restricted", &"available"]
const TARGETING_STATES := [&"unavailable", &"degraded", &"available"]
const GUNNER_REASONS := [&"", &"role_transfer", &"disconnected", &"weapon_unavailable", &"cooldown", &"ammunition_depleted", &"target_unavailable"]

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var raw_roles := source.get("roles", {}) as Dictionary
	var compact_status := bool(source.get("compact_crew_status", false))
	var status_headline := _bounded_text(
		str(source.get("crew_status_headline", "")).strip_edges(), 64
	)
	var status_value := _bounded_text(
		str(source.get("crew_status_value", "")).strip_edges(), 96
	)
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
	var detached := bool(source.get("detached", false)) or bool(source.get("handoff", false))
	var engineer_route: Dictionary = {}
	if not detached:
		var engineer := raw_roles.get(&"engineer", {}) as Dictionary
		engineer_route = {
			"power_route": _bounded_state(engineer.get("power_route", &"offline"), POWER_ROUTES, &"offline"),
			"mobility": _bounded_state(engineer.get("mobility", &"immobile"), MOBILITY_STATES, &"immobile"),
			"fire": _bounded_state(engineer.get("fire", &"blocked"), FIRE_STATES, &"blocked"),
			"targeting": _bounded_state(engineer.get("targeting", &"unavailable"), TARGETING_STATES, &"unavailable"),
			"power_marker": "●" if StringName(engineer.get("power_route", &"offline")) == &"primary" else "○",
			"presentation_only": true,
		}
	var emergency_handoff_view: Dictionary = {}
	var raw_emergency_handoff := source.get("emergency_pilot_handoff", {}) as Dictionary
	var previous_role := _bounded_state(raw_emergency_handoff.get("previous_role", &""), ROLE_ORDER, &"")
	var new_role := _bounded_state(raw_emergency_handoff.get("new_role", &""), ROLE_ORDER, &"")
	if not raw_emergency_handoff.is_empty() and not previous_role.is_empty() and not new_role.is_empty():
		var previous_label := str(previous_role).capitalize()
		var new_label := str(new_role).capitalize()
		emergency_handoff_view = {
			"transition": "%s → %s" % [previous_label, new_label],
			"previous_role": previous_role,
			"new_role": new_role,
			"ready": bool(raw_emergency_handoff.get("ready", false)),
			"readiness": "Ready" if bool(raw_emergency_handoff.get("ready", false)) else "Not ready",
			"neutral_controls_confirmed": bool(raw_emergency_handoff.get("neutral_command_confirmed", false)),
			"controls": "Neutral" if bool(raw_emergency_handoff.get("neutral_command_confirmed", false)) else "Pending",
			"presentation_only": true,
		}
	var gunner_weapon: Dictionary = {}
	var gunner_record := raw_roles.get(&"gunner", {}) as Dictionary
	var raw_weapon := source.get("gunner_weapon", source.get("weapon", gunner_record.get("weapon", {}))) as Dictionary
	var gunner_disconnected := detached or bool(source.get("disconnected", false)) or bool(gunner_record.get("disconnected", false))
	if not compact_status and (not raw_weapon.is_empty() or not gunner_record.is_empty()):
		var reason := _bounded_state(
			raw_weapon.get("unavailable_reason", gunner_record.get("unavailable_reason", &"")),
			GUNNER_REASONS, &"weapon_unavailable"
		)
		var ammo := maxi(0, int(raw_weapon.get("ammunition", raw_weapon.get("ammo", raw_weapon.get("ammunition_remaining", 0)))))
		var cooldown := maxf(0.0, float(raw_weapon.get("cooldown_remaining", gunner_record.get("cooldown_remaining", 0.0))))
		var charge := clampf(float(raw_weapon.get("charge_progress", raw_weapon.get("charge", 0.0))), 0.0, 1.0)
		var ready := bool(raw_weapon.get("ready", raw_weapon.get("weapon_ready", cooldown <= 0.0 and not gunner_disconnected)))
		var status := "GUNNER DISCONNECTED" if gunner_disconnected else ("ROLE TRANSFER IN PROGRESS" if bool(source.get("handoff", false)) else "GUNNER READY" if ready else "GUNNER UNAVAILABLE")
		gunner_weapon = {
			"role": &"gunner",
			"status": status,
			"weapon_id": StringName(str(raw_weapon.get("weapon_id", &"siege_lance"))),
			"charge_progress": charge,
			"ammunition": ammo,
			"cooldown_remaining": cooldown,
			"ready": ready,
			"unavailable_reason": reason,
			"fire_action": StringName(str(raw_weapon.get("fire_action", &"fire"))),
			"aim_action": StringName(str(raw_weapon.get("aim_action", &"aim"))),
			"presentation_only": true,
		}
	var actions: Array = []
	if not compact_status:
		actions = [
			{"id": &"claim", "label": "Claim available seat", "focusable": true},
			{"id": &"release", "label": "Release your seat", "focusable": true},
			{"id": &"transfer", "label": "Transfer role", "focusable": true},
		]
	_snapshot = {
		"component_id": COMPONENT_ID,
		"actor_id": str(source.get("actor_id", "")),
		"rows": rows,
		"title": status_headline if not status_headline.is_empty() else "Crew Roles and Seats",
		"message": status_value,
		"actions": actions,
		"engineer_route": engineer_route,
		"engineer_route_attached": not detached,
		"emergency_handoff": emergency_handoff_view,
		"presentation_only": true,
	}
	if not compact_status:
		_snapshot["gunner_weapon"] = gunner_weapon
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


func _bounded_state(raw: Variant, allowed: Array, fallback: StringName) -> StringName:
	var value := StringName(str(raw).strip_edges().to_lower())
	return value if allowed.has(value) else fallback


func _bounded_text(value: String, max_length: int) -> String:
	return value.left(max_length) if value.length() > max_length else value
