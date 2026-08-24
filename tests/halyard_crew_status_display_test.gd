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
	var repairing := _repair_envelope(0, 1, &"repairing", 0.42, &"engine_bay", &"")
	_check(
		bool(display.present_engineer_repair_snapshot(repairing).get("accepted", false))
			and display.get_readout_text().contains("REPAIRING // ENGINE BAY // 42%"),
		"the physical readout names the repairing component and numeric progress"
	)
	_check(
		display.present_engineer_repair_snapshot(repairing).get("reason", &"") == &"duplicate_sequence"
			and display.present_engineer_repair_snapshot(
				_repair_envelope(0, 0, &"completed", 1.0, &"engine_bay", &"")
			).get("reason", &"") == &"stale_sequence",
		"duplicate and out-of-order repair snapshots cannot repaint the station"
	)
	_check(
		bool(display.present_engineer_repair_snapshot(
			_repair_envelope(0, 2, &"completed", 1.0, &"engine_bay", &"")
		).get("accepted", false))
			and display.get_readout_text().contains("COMPLETED // ENGINE BAY // 100%"),
		"completion is an explicit non-colour-only state"
	)
	_check(
		bool(display.present_engineer_repair_snapshot(
			_repair_envelope(0, 3, &"interrupted", 0.58, &"engine_bay", &"role_released")
		).get("accepted", false))
			and display.get_readout_text().contains("ABORTED // ROLE RELEASED // ENGINE BAY // 58%"),
		"an interrupted authority snapshot is rendered as an explicit aborted state"
	)
	_check(bool(display.begin_repair_generation(1).get("accepted", false)), "a new role lifecycle advances the repair fence")
	_check(
		display.get_readout_text().contains("IDLE // REPAIR READY")
			and display.present_engineer_repair_snapshot(
				_repair_envelope(0, 4, &"completed", 1.0, &"engine_bay", &"")
			).get("reason", &"") == &"stale_generation",
		"role cleanup clears the station and fences snapshots from the prior generation"
	)
	var repair_authority := display.get_repair_presentation_snapshot().get("authority", {}) as Dictionary
	_check(
		not bool(repair_authority.get("repair", true))
			and not bool(repair_authority.get("network", true))
			and bool(repair_authority.get("presentation", false)),
		"the Halyard station declares presentation ownership only"
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


func _repair_envelope(
	generation: int,
	sequence: int,
	status: StringName,
	progress: float,
	component_id: StringName,
	reason: StringName
) -> Dictionary:
	return {
		"generation": generation,
		"sequence": sequence,
		"repair_snapshot": {
			"repair": {
				"status": status,
				"reason": reason,
				"component_id": component_id,
				"component_generation": 1,
				"progress": progress,
				"cooldown_remaining": 0.5 if status == &"completed" else 0.0,
			},
			"owner": {
				"seat_id": &"crew_port_01",
				"occupant_peer_id": 77,
			},
			"presentation_only": true,
		},
	}
