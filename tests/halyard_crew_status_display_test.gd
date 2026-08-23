extends SceneTree

const Display := preload("res://scripts/ships/halyard_crew_status_display.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var display := Display.new()
	root.add_child(display)
	await process_frame
	var presented := display.present_crew_snapshot({
		"role_occupancy": {
			&"pilot": [{"seat_generation": 1}],
			&"engineer": [{"seat_generation": 1}],
			&"gunner": [],
			&"passenger": [],
		},
		"departure_readiness": {
			"pilot_present": true,
			"ready": true,
			"optional_crew_count": 1,
		},
		"power_routing": {"engineer": {"channel": &"mobility_multiplier"}},
		"emergency_pilot_handoff": {
			"previous_role": &"passenger",
			"new_role": &"pilot",
			"ready": true,
			"neutral_command_confirmed": true,
		},
	})
	_check(bool(presented.get("pilot_ready", false)), "display reflects detached pilot readiness")
	_check(
		int(presented.get("optional_crew_count", 0)) == 1
			and (presented.get("role_states", {}).get(&"engineer", {}) as Dictionary).get("token", "") == "[ON]",
		"display uses bounded text tokens for occupied optional crew"
	)
	_check(
		presented.get("engineer_route", "") == "[MOBILITY]"
			and display.get_readout_text().contains("ENG ROUTE [MOBILITY]"),
		"display exposes engineer route with a color-independent shape-safe label"
	)
	_check(
		(presented.get("emergency_handoff", {}) as Dictionary).get("transition", "") == "PASSENGER>PILOT"
			and display.get_readout_text().contains("HANDOFF [PASSENGER>PILOT] [READY] [NEUTRAL]"),
		"display exposes emergency handoff transition readiness and neutral controls"
	)
	var detached := display.present_crew_snapshot({"departure_readiness": {}, "role_occupancy": {}})
	_check(
		not bool(detached.get("pilot_ready", true))
			and (detached.get("emergency_handoff", {}) as Dictionary).is_empty()
			and display.get_readout_text().contains("DEPART [WAIT PILOT]"),
		"detached snapshot clears visible handoff and readiness state"
	)
	display.clear_for_detach()
	_check(
		(display.get_display_snapshot().get("engineer_route", "") == "[NONE]"
			and display.get_readout_text().contains("CREW [P:EMPTY G:EMPTY E:EMPTY X:EMPTY]")),
		"explicit detach cleanup resets the in-ship display"
	)
	display.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_STATUS_DISPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
