class_name HalyardCrewStatusDisplay
extends Node3D

## Presentation-only in-ship crew/status display.
##
## A Halyard caller places this component beneath the authored cabin status
## panel and feeds it the detached `get_crew_role_gameplay_snapshot()` result.
## It never polls authority, ship state, or scene occupants, and it owns no
## gameplay decisions. Bracketed text tokens remain legible without colour.

const SCHEMA_VERSION := 1
const ROLE_ORDER: Array[StringName] = [&"pilot", &"gunner", &"engineer", &"passenger"]
const ROLE_SHORT_NAMES := {
	&"pilot": "P",
	&"gunner": "G",
	&"engineer": "E",
	&"passenger": "X",
}

var _readout: Label3D
var _display_snapshot: Dictionary = {}


func _ready() -> void:
	_readout = Label3D.new()
	_readout.name = "CrewStatusReadout"
	_readout.font_size = 32
	_readout.pixel_size = 0.0011
	_readout.modulate = Color("b9f1d0")
	_readout.outline_modulate = Color("07111d")
	_readout.outline_size = 8
	_readout.no_depth_test = true
	_readout.set_meta("presentation_only", true)
	_readout.text = "CREW [P:EMPTY G:EMPTY E:EMPTY X:EMPTY]\nDEPART [WAIT PILOT]\nENG ROUTE [NONE] REPAIR [READY]"
	add_child(_readout)
	_clear_display_snapshot()


## Applies one already-detached gameplay snapshot. The return value is also
## detached so a caller cannot mutate the component's presentation state.
func present_crew_snapshot(source: Dictionary) -> Dictionary:
	var departure := source.get("departure_readiness", {}) as Dictionary
	var power_routing := source.get("power_routing", {}) as Dictionary
	var engineer_route := power_routing.get("engineer", {}) as Dictionary
	var engineer_repair := source.get("engineer_repair", {}) as Dictionary
	var handoff := source.get("emergency_pilot_handoff", {}) as Dictionary
	var role_states := {}
	var role_occupancy := source.get("role_occupancy", {}) as Dictionary
	for role in ROLE_ORDER:
		var occupants := role_occupancy.get(role, []) as Array
		role_states[role] = {
			"occupied": not occupants.is_empty(),
			"token": _role_token(role, not occupants.is_empty()),
		}
	var pilot_ready := bool(departure.get("ready", false)) and bool(departure.get("pilot_present", false))
	var optional_count := int(departure.get("optional_crew_count", 0))
	var channel := StringName(engineer_route.get("channel", &"none"))
	var route_token := _route_token(channel)
	var handoff_view := {}
	if not handoff.is_empty():
		handoff_view = {
			"transition": "%s>%s" % [
				str(handoff.get("previous_role", &"unknown")).to_upper(),
				str(handoff.get("new_role", &"unknown")).to_upper(),
			],
			"ready": bool(handoff.get("ready", false)),
			"neutral_command_confirmed": bool(handoff.get("neutral_command_confirmed", false)),
		}
	_display_snapshot = {
		"schema_version": SCHEMA_VERSION,
		"pilot_ready": pilot_ready,
		"optional_crew_count": optional_count,
		"role_states": role_states,
		"engineer_route": route_token,
		"engineer_repair": _repair_token(engineer_repair),
		"emergency_handoff": handoff_view,
		"presentation_only": true,
	}.duplicate(true)
	_readout.text = _format_readout(_display_snapshot)
	return _display_snapshot.duplicate(true)


func get_display_snapshot() -> Dictionary:
	return _display_snapshot.duplicate(true)


func get_readout_text() -> String:
	return _readout.text if is_instance_valid(_readout) else ""


func clear_for_detach() -> void:
	_clear_display_snapshot()
	if is_instance_valid(_readout):
		_readout.text = "CREW [P:EMPTY G:EMPTY E:EMPTY X:EMPTY]\nDEPART [WAIT PILOT]\nENG ROUTE [NONE] REPAIR [READY]"


func _clear_display_snapshot() -> void:
	_display_snapshot = {
		"schema_version": SCHEMA_VERSION,
		"pilot_ready": false,
		"optional_crew_count": 0,
		"role_states": {},
		"engineer_route": "[NONE]",
		"engineer_repair": "[READY]",
		"emergency_handoff": {},
		"presentation_only": true,
	}.duplicate(true)


func _format_readout(snapshot: Dictionary) -> String:
	var role_states := snapshot.get("role_states", {}) as Dictionary
	var role_line := "CREW ["
	for index in ROLE_ORDER.size():
		if index > 0:
			role_line += " "
		var role := ROLE_ORDER[index]
		role_line += "%s:%s" % [ROLE_SHORT_NAMES[role], (role_states.get(role, {}) as Dictionary).get("token", "[EMPTY]")]
	role_line += "]"
	var departure_token := "READY" if bool(snapshot.get("pilot_ready", false)) else "WAIT PILOT"
	var route_token := str(snapshot.get("engineer_route", "[NONE]"))
	var text := role_line + "\nDEPART [%s] CREW[%d]\nENG ROUTE %s REPAIR %s" % [
		departure_token,
		int(snapshot.get("optional_crew_count", 0)),
		route_token,
		str(snapshot.get("engineer_repair", "[READY]")),
	]
	var handoff := snapshot.get("emergency_handoff", {}) as Dictionary
	if not handoff.is_empty():
		var controls := "NEUTRAL" if bool(handoff.get("neutral_command_confirmed", false)) else "PENDING"
		var readiness := "READY" if bool(handoff.get("ready", false)) else "WAIT"
		text += "\nHANDOFF [%s] [%s] [%s]" % [str(handoff.get("transition", "UNKNOWN")), readiness, controls]
	return text


func _role_token(role: StringName, occupied: bool) -> String:
	return "[ON]" if occupied else "[EMPTY]"


func _route_token(channel: StringName) -> String:
	match channel:
		&"mobility_multiplier":
			return "[MOBILITY]"
		&"fire_multiplier":
			return "[FIRE]"
		&"targeting_multiplier":
			return "[TARGET]"
		_:
			return "[NONE]"


func _repair_token(repair: Dictionary) -> String:
	var status := StringName(repair.get("status", &"idle"))
	if status == &"repairing":
		return "[WORK %d%%]" % int(round(clampf(float(repair.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	if status == &"interrupted":
		return "[INTERRUPTED]"
	var cooldown := maxf(float(repair.get("cooldown_remaining", 0.0)), 0.0)
	if cooldown > 0.0:
		return "[COOLDOWN %.1fs]" % cooldown
	return "[READY]"
