class_name HalyardCrewStatusDisplay
extends Node3D

## Presentation-only in-ship crew/status display.
##
## A Halyard caller places this component beneath the authored cabin status
## panel and feeds it the detached `get_crew_role_gameplay_snapshot()` result.
## It never polls authority, ship state, or scene occupants, and it owns no
## gameplay decisions. Bracketed text tokens remain legible without colour.

const SCHEMA_VERSION := 1
const MAX_SAFE_GENERATION := 9_007_199_254_740_991
const MAX_SAFE_SEQUENCE := 9_007_199_254_740_991
const ROLE_ORDER: Array[StringName] = [&"pilot", &"gunner", &"engineer", &"passenger"]

var _readout: Label3D
var _display_snapshot: Dictionary = {}
var _repair_generation := 0
var _last_repair_sequence := -1
var _repair_view: Dictionary = {}


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
	_readout.text = "ROSTER [DETACHED]\nP [DETACHED] G [DETACHED]\nE [DETACHED] X [DETACHED]\nDEPART [WAIT PILOT]\nENG ROUTE [NONE] REPAIR [READY]"
	add_child(_readout)
	_clear_display_snapshot()


## Applies one already-detached gameplay snapshot. The return value is also
## detached so a caller cannot mutate the component's presentation state.
func present_crew_snapshot(source: Dictionary) -> Dictionary:
	var departure := source.get("departure_readiness", {}) as Dictionary
	var power_routing := source.get("power_routing", {}) as Dictionary
	var engineer_route := power_routing.get("engineer", {}) as Dictionary
	var handoff := source.get("emergency_pilot_handoff", {}) as Dictionary
	var role_states := {}
	var role_occupancy := source.get("role_occupancy", {}) as Dictionary
	# The display never inventories seats itself.  The detached roster link is
	# the only availability fact it formats, so a disconnected authority cannot
	# look like four vacant-but-claimable stations in the walking view.
	var roster_linked := bool(source.get("authority_attached", false))
	for role in ROLE_ORDER:
		var occupants := role_occupancy.get(role, []) as Array
		role_states[role] = {
			"occupied": not occupants.is_empty(),
			"token": _role_token(roster_linked, not occupants.is_empty()),
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
		"roster_linked": roster_linked,
		"role_states": role_states,
		"engineer_route": route_token,
		"engineer_repair": _repair_view.duplicate(true),
		"repair_generation": _repair_generation,
		"last_repair_sequence": _last_repair_sequence,
		"emergency_handoff": handoff_view,
		"presentation_only": true,
	}.duplicate(true)
	_readout.text = _format_readout(_display_snapshot)
	return _display_snapshot.duplicate(true)


## Presents the existing detached Halyard repair-network snapshot. The display
## only formats it; repair, component, seat, and network authority stay with
## the snapshot producers. Generation and sequence fences prevent a released
## engineer's retained snapshot from painting a later station lifecycle.
func present_engineer_repair_snapshot(envelope: Dictionary) -> Dictionary:
	var decoded := _decode_repair_envelope(envelope)
	if not bool(decoded.get("accepted", false)):
		return _repair_result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var sequence := int(decoded.get("sequence", -1))
	if sequence <= _last_repair_sequence:
		return _repair_result(
			false,
			&"duplicate_sequence" if sequence == _last_repair_sequence else &"stale_sequence"
		)
	_last_repair_sequence = sequence
	_repair_view = {
		"state": StringName(decoded.get("state", &"idle")),
		"component_id": StringName(decoded.get("component_id", &"")),
		"component_generation": int(decoded.get("component_generation", 0)),
		"progress": float(decoded.get("progress", 0.0)),
		"reason": StringName(decoded.get("reason", &"")),
		"cooldown_remaining": float(decoded.get("cooldown_remaining", 0.0)),
	}.duplicate(true)
	_repair_view["token"] = _repair_token(_repair_view)
	if not _display_snapshot.is_empty():
		_display_snapshot["engineer_repair"] = _repair_view.duplicate(true)
		_display_snapshot["repair_generation"] = _repair_generation
		_display_snapshot["last_repair_sequence"] = _last_repair_sequence
		if is_instance_valid(_readout):
			_readout.text = _format_readout(_display_snapshot)
	return _repair_result(true, &"snapshot_presented")


func begin_repair_generation(generation: int) -> Dictionary:
	if generation <= _repair_generation or generation > MAX_SAFE_GENERATION:
		return _repair_result(false, &"stale_generation")
	_repair_generation = generation
	_clear_repair_view()
	if not _display_snapshot.is_empty():
		_display_snapshot["engineer_repair"] = _repair_view.duplicate(true)
		_display_snapshot["repair_generation"] = _repair_generation
		_display_snapshot["last_repair_sequence"] = _last_repair_sequence
		if is_instance_valid(_readout):
			_readout.text = _format_readout(_display_snapshot)
	return _repair_result(true, &"generation_started")


func get_repair_presentation_snapshot() -> Dictionary:
	return {
		"generation": _repair_generation,
		"last_sequence": _last_repair_sequence,
		"repair": _repair_view.duplicate(true),
		"authority": {
			"repair": false,
			"components": false,
			"seats": false,
			"network": false,
			"presentation": true,
		},
	}.duplicate(true)


func get_display_snapshot() -> Dictionary:
	return _display_snapshot.duplicate(true)


func get_readout_text() -> String:
	return _readout.text if is_instance_valid(_readout) else ""


func clear_for_detach() -> void:
	_repair_generation = mini(_repair_generation + 1, MAX_SAFE_GENERATION)
	_clear_repair_view()
	_clear_display_snapshot()
	if is_instance_valid(_readout):
		_readout.text = "ROSTER [DETACHED]\nP [DETACHED] G [DETACHED]\nE [DETACHED] X [DETACHED]\nDEPART [WAIT PILOT]\nENG ROUTE [NONE] REPAIR [READY]"


func _clear_display_snapshot() -> void:
	_display_snapshot = {
		"schema_version": SCHEMA_VERSION,
		"pilot_ready": false,
		"optional_crew_count": 0,
		"roster_linked": false,
		"role_states": {},
		"engineer_route": "[NONE]",
		"engineer_repair": _repair_view.duplicate(true),
		"repair_generation": _repair_generation,
		"last_repair_sequence": _last_repair_sequence,
		"emergency_handoff": {},
		"presentation_only": true,
	}.duplicate(true)


func _format_readout(snapshot: Dictionary) -> String:
	var role_states := snapshot.get("role_states", {}) as Dictionary
	var roster_token := "[LINKED]" if bool(snapshot.get("roster_linked", false)) else "[DETACHED]"
	var pilot_token := str((role_states.get(&"pilot", {}) as Dictionary).get("token", "[DETACHED]"))
	var gunner_token := str((role_states.get(&"gunner", {}) as Dictionary).get("token", "[DETACHED]"))
	var engineer_token := str((role_states.get(&"engineer", {}) as Dictionary).get("token", "[DETACHED]"))
	var passenger_token := str((role_states.get(&"passenger", {}) as Dictionary).get("token", "[DETACHED]"))
	var departure_token := "READY" if bool(snapshot.get("pilot_ready", false)) else "WAIT PILOT"
	var route_token := str(snapshot.get("engineer_route", "[NONE]"))
	var text := "ROSTER %s\nP %s G %s\nE %s X %s\nDEPART [%s] CREW[%d]\nENG ROUTE %s REPAIR %s" % [
		roster_token,
		pilot_token,
		gunner_token,
		engineer_token,
		passenger_token,
		departure_token,
		int(snapshot.get("optional_crew_count", 0)),
		route_token,
		_repair_token(snapshot.get("engineer_repair", {}) as Dictionary),
	]
	var handoff := snapshot.get("emergency_handoff", {}) as Dictionary
	if not handoff.is_empty():
		var controls := "ACK" if bool(handoff.get("neutral_command_confirmed", false)) else "NO ACK"
		var readiness := "READY" if bool(handoff.get("ready", false)) else "WAIT"
		text += "\nHANDOFF [%s] [%s] [%s]" % [str(handoff.get("transition", "UNKNOWN")), readiness, controls]
	return text


func _role_token(roster_linked: bool, occupied: bool) -> String:
	if not roster_linked:
		return "[DETACHED]"
	return "[ACTIVE]" if occupied else "[OPEN]"


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
	var status := StringName(repair.get("state", repair.get("status", &"idle")))
	var component := _readable_id(StringName(repair.get("component_id", &"")))
	var percent := int(round(clampf(float(repair.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	if status == &"repairing":
		return "[WORK // REPAIRING // %s // %d%%]" % [component, percent]
	if status == &"aborted" or status == &"interrupted":
		return "[INTERRUPTED] [%s // %s // %d%%]" % [
			_readable_id(StringName(repair.get("reason", &"interrupted"))),
			component,
			percent,
		]
	if status == &"completed":
		var completed_cooldown := maxf(float(repair.get("cooldown_remaining", 0.0)), 0.0)
		return "[COOLDOWN %.1fs // COMPLETED // %s // 100%%]" % [completed_cooldown, component] \
			if completed_cooldown > 0.0 else "[COMPLETED // %s // 100%%]" % component
	var cooldown := maxf(float(repair.get("cooldown_remaining", 0.0)), 0.0)
	if cooldown > 0.0:
		return "[COOLDOWN %.1fs]" % cooldown
	return "[READY // IDLE // REPAIR READY]"


func _decode_repair_envelope(envelope: Dictionary) -> Dictionary:
	var raw_generation: Variant = envelope.get("generation", -1)
	var raw_sequence: Variant = envelope.get("sequence", -1)
	var raw_snapshot: Variant = envelope.get("repair_snapshot", null)
	if not raw_generation is int or int(raw_generation) != _repair_generation:
		return {"accepted": false, "reason": &"stale_generation"}
	if not raw_sequence is int or int(raw_sequence) < 0 \
			or int(raw_sequence) > MAX_SAFE_SEQUENCE:
		return {"accepted": false, "reason": &"invalid_sequence"}
	if not raw_snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_repair_snapshot"}
	var network_snapshot := raw_snapshot as Dictionary
	var repair_variant: Variant = network_snapshot.get("repair", null)
	var owner_variant: Variant = network_snapshot.get("owner", null)
	if not repair_variant is Dictionary or not owner_variant is Dictionary \
			or not bool(network_snapshot.get("presentation_only", false)):
		return {"accepted": false, "reason": &"invalid_repair_snapshot"}
	var repair := repair_variant as Dictionary
	var owner := owner_variant as Dictionary
	var authority_status := StringName(repair.get("status", &"idle"))
	var state: StringName
	match authority_status:
		&"repairing": state = &"repairing"
		&"completed": state = &"completed"
		&"interrupted": state = &"interrupted"
		&"idle": state = &"idle"
		_: return {"accepted": false, "reason": &"invalid_repair_state"}
	var raw_progress: Variant = repair.get("progress", 0.0)
	if not (raw_progress is int or raw_progress is float) \
			or not is_finite(float(raw_progress)) \
			or float(raw_progress) < 0.0 or float(raw_progress) > 1.0:
		return {"accepted": false, "reason": &"invalid_progress"}
	var component_id := StringName(repair.get("component_id", &""))
	var component_generation := int(repair.get("component_generation", 0))
	if state != &"idle" and (component_id.is_empty() or component_generation <= 0):
		return {"accepted": false, "reason": &"invalid_component_fence"}
	if not owner.is_empty() and (
		StringName(owner.get("seat_id", &"")) != &"crew_port_01"
		or component_id.is_empty()
	):
		return {"accepted": false, "reason": &"owner_mismatch"}
	return {
		"accepted": true,
		"sequence": int(raw_sequence),
		"state": state,
		"component_id": component_id,
		"component_generation": component_generation,
		"progress": float(raw_progress),
		"reason": StringName(repair.get("reason", &"")),
		"cooldown_remaining": maxf(float(repair.get("cooldown_remaining", 0.0)), 0.0),
	}


func _clear_repair_view() -> void:
	_last_repair_sequence = -1
	_repair_view = {
		"state": &"idle",
		"component_id": &"",
		"component_generation": 0,
		"progress": 0.0,
		"reason": &"",
		"cooldown_remaining": 0.0,
	}.duplicate(true)


func _readable_id(value: StringName) -> String:
	return "NO TARGET" if value.is_empty() else String(value).replace("_", " ").to_upper()


func _repair_result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _repair_generation,
	}.duplicate(true)
