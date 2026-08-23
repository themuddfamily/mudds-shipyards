class_name CrewRoleGameplayProfile
extends RefCounted

## Runtime role-action vocabulary for larger vessels.
##
## This profile owns the shape and normalization of role intents, not their
## downstream gameplay effect. A server-side seat authority accepts one of
## these normalized receipts; ship command, combat, repair, and presentation
## systems remain the authorities that consume them.

const SCHEMA_VERSION := 1
const PROFILE_ID: StringName = &"crew_role_gameplay_v1"

const ROLE_PILOT: StringName = &"pilot"
const ROLE_GUNNER: StringName = &"gunner"
const ROLE_PASSENGER: StringName = &"passenger"
const ROLE_ENGINEER: StringName = &"engineer"
const ROLES := [ROLE_PILOT, ROLE_GUNNER, ROLE_PASSENGER, ROLE_ENGINEER]

const CAPABILITY_SHIP_COMMAND: StringName = &"ship_command"
const CAPABILITY_WEAPON_CONTROL: StringName = &"weapon_control"
const CAPABILITY_SYSTEMS_CONTROL: StringName = &"systems_control"
const CAPABILITY_PASSENGER_ACCESS: StringName = &"passenger_access"

const ACTION_FLIGHT_COMMAND: StringName = &"flight_command"
const ACTION_GUNNER_FIRE: StringName = &"gunner_fire"
const ACTION_ENGINEER_REPAIR: StringName = &"engineer_repair"
const ACTION_PASSENGER_PING: StringName = &"passenger_ping"

const ROLE_CAPABILITIES := {
	ROLE_PILOT: [CAPABILITY_SHIP_COMMAND],
	ROLE_GUNNER: [CAPABILITY_WEAPON_CONTROL],
	ROLE_PASSENGER: [CAPABILITY_PASSENGER_ACCESS],
	ROLE_ENGINEER: [CAPABILITY_SYSTEMS_CONTROL],
}

const ROLE_ACTIONS := {
	ROLE_PILOT: {
		"action": ACTION_FLIGHT_COMMAND,
		"capability": CAPABILITY_SHIP_COMMAND,
		"channel": &"ship_command_intent",
	},
	ROLE_GUNNER: {
		"action": ACTION_GUNNER_FIRE,
		"capability": CAPABILITY_WEAPON_CONTROL,
		"channel": &"weapon_intent",
	},
	ROLE_PASSENGER: {
		"action": ACTION_PASSENGER_PING,
		"capability": CAPABILITY_PASSENGER_ACCESS,
		"channel": &"passenger_intent",
	},
	ROLE_ENGINEER: {
		"action": ACTION_ENGINEER_REPAIR,
		"capability": CAPABILITY_SYSTEMS_CONTROL,
		"channel": &"repair_intent",
	},
}

const MAX_ID_LENGTH := 64


static func get_supported_roles() -> Array[StringName]:
	return ROLES.duplicate()


static func get_role_profile(role: StringName) -> Dictionary:
	if not ROLE_ACTIONS.has(role):
		return {}
	var profile: Dictionary = (ROLE_ACTIONS[role] as Dictionary).duplicate(true)
	profile["role"] = role
	profile["capabilities"] = (ROLE_CAPABILITIES[role] as Array).duplicate()
	return profile


## Validate and normalize one role action. The returned `payload` is detached
## and contains only fields that the downstream authority is allowed to read.
static func validate_intent(role: StringName, action: StringName, payload: Dictionary) -> Dictionary:
	if not ROLE_ACTIONS.has(role):
		return _rejected(&"invalid_role")
	var profile: Dictionary = ROLE_ACTIONS[role]
	if StringName(profile.get("action", &"")) != action:
		return _rejected(&"action_not_allowed")
	match action:
		ACTION_FLIGHT_COMMAND:
			return _flight_command(payload)
		ACTION_GUNNER_FIRE:
			return _gunner_fire(payload)
		ACTION_ENGINEER_REPAIR:
			return _engineer_repair(payload)
		ACTION_PASSENGER_PING:
			return _passenger_ping(payload)
		_:
			return _rejected(&"unknown_action")


static func _flight_command(payload: Dictionary) -> Dictionary:
	if not _exact_keys(payload, ["throttle", "pitch", "yaw", "roll", "boost", "brake"]):
		return _rejected(&"invalid_flight_command_schema")
	var throttle := _finite_number(payload.get("throttle", NAN))
	var pitch := _finite_number(payload.get("pitch", NAN))
	var yaw := _finite_number(payload.get("yaw", NAN))
	var roll := _finite_number(payload.get("roll", NAN))
	if is_nan(throttle) or is_nan(pitch) or is_nan(yaw) or is_nan(roll):
		return _rejected(&"invalid_flight_command_axis")
	if not payload.get("boost", false) is bool or not payload.get("brake", false) is bool:
		return _rejected(&"invalid_flight_command_edge")
	return _accepted({
		"throttle": clampf(throttle, 0.0, 1.0),
		"pitch": clampf(pitch, -1.0, 1.0),
		"yaw": clampf(yaw, -1.0, 1.0),
		"roll": clampf(roll, -1.0, 1.0),
		"boost": bool(payload.get("boost", false)),
		"brake": bool(payload.get("brake", false)),
	})


static func _gunner_fire(payload: Dictionary) -> Dictionary:
	var base_schema := _exact_keys(payload, ["weapon_id", "target_id", "trigger"])
	var generation_schema := _exact_keys(
		payload, ["weapon_id", "target_id", "trigger", "target_generation"]
	)
	if not base_schema and not generation_schema:
		return _rejected(&"invalid_gunner_fire_schema")
	var weapon_id := StringName(str(payload.get("weapon_id", "")))
	var target_id := StringName(str(payload.get("target_id", "")))
	var target_generation: Variant = payload.get("target_generation", 1)
	if not _valid_id(weapon_id) or not _valid_id(target_id) \
			or not payload.get("trigger", false) is bool \
			or not target_generation is int \
			or int(target_generation) <= 0 or int(target_generation) > 1_000_000:
		return _rejected(&"invalid_gunner_fire_payload")
	return _accepted({
		"weapon_id": weapon_id,
		"target_id": target_id,
		"trigger": bool(payload.get("trigger", false)),
		"target_generation": int(target_generation),
	})


static func _engineer_repair(payload: Dictionary) -> Dictionary:
	var base_schema := _exact_keys(payload, ["system_id", "repair"])
	var generation_schema := _exact_keys(payload, ["system_id", "repair", "system_generation"])
	if not base_schema and not generation_schema:
		return _rejected(&"invalid_engineer_repair_schema")
	var system_id := StringName(str(payload.get("system_id", "")))
	var repair := _finite_number(payload.get("repair", NAN))
	var system_generation: Variant = payload.get("system_generation", 1)
	if not _valid_id(system_id) or is_nan(repair) \
			or not system_generation is int \
			or int(system_generation) <= 0 or int(system_generation) > 1_000_000:
		return _rejected(&"invalid_engineer_repair_payload")
	return _accepted({
		"system_id": system_id,
		"repair": clampf(repair, 0.0, 1.0),
		"system_generation": int(system_generation),
	})


static func _passenger_ping(payload: Dictionary) -> Dictionary:
	if not _exact_keys(payload, ["channel", "marker_id"]):
		return _rejected(&"invalid_passenger_ping_schema")
	var channel := StringName(str(payload.get("channel", "")))
	var marker_id := StringName(str(payload.get("marker_id", "")))
	if not _valid_id(channel) or not _valid_id(marker_id):
		return _rejected(&"invalid_passenger_ping_payload")
	return _accepted({"channel": channel, "marker_id": marker_id})


static func _exact_keys(payload: Dictionary, expected: Array) -> bool:
	if payload.size() != expected.size():
		return false
	for key: String in expected:
		if not payload.has(key):
			return false
	return true


static func _finite_number(value: Variant) -> float:
	if not value is float and not value is int:
		return NAN
	var number := float(value)
	return number if is_finite(number) else NAN


static func _valid_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var codepoint := text.unicode_at(index)
		var ascii_alphanumeric := (codepoint >= 48 and codepoint <= 57) \
			or (codepoint >= 65 and codepoint <= 90) \
			or (codepoint >= 97 and codepoint <= 122)
		if not (ascii_alphanumeric or codepoint == 95 or codepoint == 45):
			return false
	return true


static func _accepted(payload: Dictionary) -> Dictionary:
	return {"accepted": true, "status": &"intent_valid", "payload": payload.duplicate(true)}


static func _rejected(status: StringName) -> Dictionary:
	return {"accepted": false, "status": status}
